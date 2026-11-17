extends Node
## Single source of truth for the player's progress.
## Everything that is saved lives here. Scenes read from it and listen to its
## signals; game rules that span scenes live in Story (scripts/systems/story.gd).

signal stats_changed
signal fatigue_changed(value: int)
signal inventory_changed
signal task_changed
signal forced_leave
signal day_started(day: int)
## Floating text above the player (rewards, costs). HUD listens.
signal popup(text: String, color: Color)

enum Condition { GOOD, NORMAL, BAD }

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2

# --- balancing (initial values; tune during the 11/21 playtest) ---
const FATIGUE_MAX := 100
const FATIGUE_BAD_AT := 70
const COFFEE_LIMIT := 3
const DAILY_PAY := 30000
const PAY_PER_RANK := 10000
const WAKE_MINUTES := 450  # 07:30 at home
const WORK_START := 540  # 09:00 at the office
const WORK_END := 1080  # 18:00
const START_MONEY := 20000
const START_BUDGET := 1000  # 팀 예산, 만원 단위
const RANKS: Array[String] = ["신입", "주무관", "사무관", "서기관"]
const RANK_EXP: Array[int] = [0, 100, 300, 700]

const HAIR_COLORS: Array[Color] = [Color("3a2f2f"), Color("8a5a3a"), Color("e0b060"), Color("6b7bd0")]
const OUTFIT_COLORS: Array[Color] = [Color("3c4d8c"), Color("4a4a52"), Color("c98a6a"), Color("f0f0f0")]
const HAIR_STYLE_COUNT := 2

# --- saved state ---
var player_name := "신입"
var hair_style := 0
var hair_color := 0
var outfit_color := 0

var day := 1
var tasks_done_today := 0
var tasks_completed := 0
var money := START_MONEY
var budget := START_BUDGET
var reputation := 0
var experience := 0
var rank := 0
var fatigue := 0
var coffee_today := 0
var meal_bonus_today := false
var inventory: Dictionary = {}  # item_id -> count
var flags: Dictionary = {}  # story flags, e.g. "intro_done"
var task: Dictionary = {}  # current task; shape documented in Story
var map_id := "home"  # map the player is on (where "이어서 출근하기" resumes)
var minutes := WAKE_MINUTES  # clock, minutes since midnight
var day_over := false  # left work; next step is sleeping at home
var upgrades: Dictionary = {}  # upgrade id -> level (TaskData.UPGRADES)
var day_log: Dictionary = {}  # today's totals for the evening summary
var last_task_index := -1
var fridge_day := 0
var cooler_day := 0

# --- session-only state ---
var force_touch_ui := false
var editing_look := false  # character screen opened from the wardrobe
var rng := RandomNumberGenerator.new()
var _input_locks := 0
var _web_touch := -1  # cached browser answer: -1 unknown, 0 no, 1 yes


func _ready() -> void:
	rng.randomize()


# ---------------------------------------------------------------- new game
func new_game(p_name: String, p_hair_style: int, p_hair_color: int, p_outfit_color: int) -> void:
	player_name = p_name
	hair_style = p_hair_style
	hair_color = p_hair_color
	outfit_color = p_outfit_color
	day = 1
	tasks_done_today = 0
	tasks_completed = 0
	money = START_MONEY
	budget = START_BUDGET
	reputation = 0
	experience = 0
	rank = 0
	fatigue = 0
	coffee_today = 0
	meal_bonus_today = false
	inventory = {"coffee": 1}
	flags = {}
	task = {}
	map_id = "home"
	minutes = WAKE_MINUTES
	day_over = false
	upgrades = {}
	day_log = {}
	last_task_index = -1
	fridge_day = 0
	cooler_day = 0
	stats_changed.emit()
	inventory_changed.emit()
	task_changed.emit()
	fatigue_changed.emit(fatigue)


# ---------------------------------------------------------------- input lock
## Dialogue, menus and scene fades lock player input. Locks are counted so
## nested lockers (a fade during a cutscene) don't unlock each other.
func lock_input() -> void:
	_input_locks += 1


func unlock_input() -> void:
	_input_locks = maxi(0, _input_locks - 1)


func is_input_locked() -> bool:
	return _input_locks > 0


func reset_input_locks() -> void:
	_input_locks = 0


# ---------------------------------------------------------------- fatigue / condition
func add_fatigue(amount: int) -> void:
	fatigue = clampi(fatigue + amount, 0, FATIGUE_MAX)
	fatigue_changed.emit(fatigue)
	stats_changed.emit()
	if fatigue >= FATIGUE_MAX:
		forced_leave.emit()


func recover_fatigue(amount: int) -> void:
	add_fatigue(-amount)


func condition() -> Condition:
	var c := Condition.NORMAL
	if fatigue >= FATIGUE_BAD_AT or coffee_today > COFFEE_LIMIT:
		c = Condition.BAD
	elif fatigue < 30:
		c = Condition.GOOD
	if meal_bonus_today and c != Condition.GOOD:
		c = (c - 1) as Condition
	return c


func condition_label() -> String:
	match condition():
		Condition.GOOD:
			return "좋음"
		Condition.BAD:
			return "나쁨"
	return "보통"


## Applied to experience and reputation rewards.
func reward_multiplier() -> float:
	match condition():
		Condition.GOOD:
			return 1.2
		Condition.BAD:
			return 0.8
	return 1.0


# ---------------------------------------------------------------- inventory / money
func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, count: int = 1) -> void:
	inventory[id] = item_count(id) + count
	inventory_changed.emit()


func remove_item(id: String, count: int = 1) -> bool:
	if item_count(id) < count:
		return false
	inventory[id] = item_count(id) - count
	if item_count(id) == 0:
		inventory.erase(id)
	inventory_changed.emit()
	return true


func add_money(amount: int) -> void:
	money += amount
	stats_changed.emit()


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	stats_changed.emit()
	return true


# ---------------------------------------------------------------- progression
## Returns true when the reward caused a promotion.
func add_rewards(budget_delta: int, reputation_delta: int, exp_delta: int) -> bool:
	budget += budget_delta
	reputation += reputation_delta
	experience += exp_delta
	var promoted := false
	while rank + 1 < RANKS.size() and experience >= RANK_EXP[rank + 1]:
		rank += 1
		promoted = true
	stats_changed.emit()
	return promoted


func spend_budget(amount: int) -> bool:
	if budget < amount:
		return false
	budget -= amount
	stats_changed.emit()
	return true


func rank_name() -> String:
	return RANKS[rank]


## Experience needed for the next rank, or -1 at the top rank.
func next_rank_exp() -> int:
	return RANK_EXP[rank + 1] if rank + 1 < RANKS.size() else -1


func daily_pay() -> int:
	return DAILY_PAY + PAY_PER_RANK * rank


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func log_add(key: String, amount: int) -> void:
	day_log[key] = int(day_log.get(key, 0)) + amount


func advance_clock(mins: int) -> void:
	minutes += mins
	stats_changed.emit()


func clock_text() -> String:
	var m := mini(minutes, 23 * 60 + 59)
	return "%02d:%02d" % [m / 60, m % 60]


## Sleeping: the next morning starts at home.
func end_day() -> void:
	day += 1
	tasks_done_today = 0
	fatigue = 0
	coffee_today = 0
	meal_bonus_today = false
	money += daily_pay()
	minutes = WAKE_MINUTES
	day_over = false
	day_log = {}
	stats_changed.emit()
	fatigue_changed.emit(fatigue)
	day_started.emit(day)
	save_game()


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value


func set_task(new_task: Dictionary) -> void:
	task = new_task
	task_changed.emit()


# ---------------------------------------------------------------- platform
## True on phones/tablets (native or mobile browser) or when forced with F2.
func is_touch_device() -> bool:
	if force_touch_ui:
		return true
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		# Not DisplayServer.is_touchscreen_available(): with emulate_touch_from_mouse
		# (project.godot) it is true in every browser, PCs included. Ask the browser
		# whether the primary pointer is a finger (phones, tablets, iPadOS Safari).
		if _web_touch < 0:
			# Return a string: JavaScriptBridge.eval turns JS booleans into int and
			# numbers into float, and comparing those with == true is a script error.
			var coarse: Variant = JavaScriptBridge.eval(
					"window.matchMedia('(pointer: coarse)').matches ? 'yes' : 'no'", true)
			_web_touch = 1 if str(coarse) == "yes" else 0
		return _web_touch == 1
	return DisplayServer.is_touchscreen_available() and not OS.has_feature("pc")


# ---------------------------------------------------------------- save / load
## On the web, user:// is stored in the browser (IndexedDB) and survives reloads.
func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"player_name": player_name,
		"hair_style": hair_style,
		"hair_color": hair_color,
		"outfit_color": outfit_color,
		"day": day,
		"tasks_done_today": tasks_done_today,
		"tasks_completed": tasks_completed,
		"money": money,
		"budget": budget,
		"reputation": reputation,
		"experience": experience,
		"rank": rank,
		"fatigue": fatigue,
		"coffee_today": coffee_today,
		"meal_bonus_today": meal_bonus_today,
		"inventory": inventory,
		"flags": flags,
		"task": task,
		"map_id": map_id,
		"minutes": minutes,
		"day_over": day_over,
		"upgrades": upgrades,
		"day_log": day_log,
		"last_task_index": last_task_index,
		"fridge_day": fridge_day,
		"cooler_day": cooler_day,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	player_name = str(d.get("player_name", "신입"))
	hair_style = int(d.get("hair_style", 0))
	hair_color = int(d.get("hair_color", 0))
	outfit_color = int(d.get("outfit_color", 0))
	day = int(d.get("day", 1))
	tasks_done_today = int(d.get("tasks_done_today", 0))
	tasks_completed = int(d.get("tasks_completed", 0))
	money = int(d.get("money", START_MONEY))
	budget = int(d.get("budget", START_BUDGET))
	reputation = int(d.get("reputation", 0))
	experience = int(d.get("experience", 0))
	rank = int(d.get("rank", 0))
	fatigue = int(d.get("fatigue", 0))
	coffee_today = int(d.get("coffee_today", 0))
	meal_bonus_today = bool(d.get("meal_bonus_today", false))
	inventory = _int_values(d.get("inventory", {}))
	flags = d.get("flags", {})
	task = _normalize_task(d.get("task", {}))
	map_id = str(d.get("map_id", "office"))
	minutes = int(d.get("minutes", WORK_START))
	day_over = bool(d.get("day_over", false))
	upgrades = _int_values(d.get("upgrades", {}))
	day_log = _int_values(d.get("day_log", {}))
	last_task_index = int(d.get("last_task_index", -1))
	fridge_day = int(d.get("fridge_day", 0))
	cooler_day = int(d.get("cooler_day", 0))
	stats_changed.emit()
	inventory_changed.emit()
	task_changed.emit()
	fatigue_changed.emit(fatigue)
	return true


## JSON turns every number into a float; convert counts back to int.
func _int_values(src: Variant) -> Dictionary:
	var out := {}
	if typeof(src) == TYPE_DICTIONARY:
		var dict: Dictionary = src
		for k: Variant in dict:
			out[str(k)] = int(dict[k])
	return out


func _normalize_task(src: Variant) -> Dictionary:
	if typeof(src) != TYPE_DICTIONARY:
		return {}
	var t: Dictionary = (src as Dictionary).duplicate()
	for key: String in ["index", "step", "vendor", "cargo", "discount", "stars"]:
		if t.has(key):
			t[key] = int(t[key])
	return t
