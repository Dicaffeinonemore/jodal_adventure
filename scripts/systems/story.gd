extends Node
## Game rules and dialogue that span scenes: the day cycle (집 -> 청사 -> 집),
## the core loop (요청 접수 -> 업체 선정 -> 운송 -> 납품·검수 -> 보고 -> 보상),
## NPC conversations, shops, upgrades, the menu, intros and forced leave.
##
## GameState.task is {} when idle, otherwise:
##   {"index": int (TaskData index), "step": Step, "vendor": int (-1 = none),
##    "cargo": int (0-100, after driving), "grade": String (after inspection),
##    "urgent": bool, "discount": int (vendor index on sale, -1 = none),
##    "discount_rolled": bool, "stars": int (picked up while driving)}
##
## All player-facing text lives in this file and in scripts/data/task_data.gd.
## Review policy facts (POLICY_TIPS, GENERAL_TIPS) against official 조달청 sources
## before submitting.

enum Step { NONE, ACCEPTED, VENDOR_CHOSEN, ARRIVED, DELIVERED }

# Balancing (initial values). One task costs about 35 fatigue, so the third task
# of the day hits the limit unless the player eats, drinks or upgrades the lounge.
const DAILY_TASKS := 3
const DRIVE_FATIGUE := 20
const SELECT_FATIGUE := 8
const RETURN_FATIGUE := 7
const HELP_FATIGUE := 8
const URGENT_CHANCE := 0.25
const DISCOUNT_CHANCE := 0.3
const REQUEST_CHANCE := 0.35
const URGENT_MULT := 1.5
const STAR_BONUS := 500  # 원 per star picked up while driving

const NPCS := {
	"narumi": {"name": "나르미", "sprite": "npc_narumi.png", "color": Color("9fd3ff")},
	"dari": {"name": "달이", "sprite": "npc_dari.png", "color": Color("ffc27a")},
	"team_leader": {"name": "김 팀장", "sprite": "npc_team_leader.png", "color": Color("c9d1ff")},
	"officer_school": {"name": "박 실장", "sprite": "npc_officer_school.png", "color": Color("b8e6b8")},
	"senior": {"name": "이 주무관", "sprite": "npc_senior.png", "color": Color("f2b8d8")},
	"vendor": {"name": "최 사장", "sprite": "npc_vendor.png", "color": Color("f2d38a")},
	"cafeteria": {"name": "식당 이모", "sprite": "npc_cafeteria.png", "color": Color("ffb3a0")},
}
const SPRITE_DIR := "res://assets/sprites/placeholder/"

const PLACE_NAMES := {"school": "한빛초등학교", "office": "정부청사", "home": "우리 집"}

## Shown once each, by Narumi, at the matching step of the first task.
const POLICY_TIPS := {
	"accepted": "조달청은 학교·소방서·병원 같은 공공기관이 필요한 물품과 서비스를 대신 구매하고 계약해요.",
	"vendor": "공공 입찰은 국가종합전자조달시스템 '나라장터'에서 공개적으로 진행돼요. 누구나 같은 조건으로 참여할 수 있어서 공정하죠.",
	"inspection": "납품된 물품은 계약한 규격과 품질에 맞는지 검사·검수를 거쳐요. 품질 관리가 공공조달의 신뢰를 지켜요.",
	"report": "업체를 고를 때는 가격만 보지 않아요. 품질과 납품 능력까지 함께 따져야 예산을 제대로 아낄 수 있어요.",
}
const GENERAL_TIPS := [
	"조달청은 공공기관이 필요한 물품과 서비스를 대신 구매하고 계약하는 기관이에요.",
	"공공 입찰은 '나라장터'에서 공개적으로 진행돼서 누구나 같은 조건으로 참여할 수 있어요.",
	"조달청은 중소기업과 혁신 기업의 제품이 공공시장에 진출하도록 돕는 일도 해요.",
	"조달청은 비상시를 대비해 원자재를 비축하는 일도 맡고 있어요.",
	"친환경 제품 구매도 공공조달에서 중요하게 다루는 가치예요.",
]

const VENDING_ITEMS := ["coffee", "energybar"]
const TICKET_ITEMS := ["gukbap", "meal"]
const QUICK_ORDER := ["coffee", "energybar", "gukbap", "meal"]

var _busy := false
var _forced_pending := false


func _ready() -> void:
	for id: String in NPCS:
		var npc: Dictionary = NPCS[id]
		Dialogue.name_colors[str(npc["name"])] = npc["color"]
	GameState.forced_leave.connect(_on_forced_leave)


# ================================================================ queries
func npc_name(id: String) -> String:
	return str((NPCS.get(id, {}) as Dictionary).get("name", id))


func npc_sprite(id: String) -> String:
	return SPRITE_DIR + str((NPCS.get(id, {}) as Dictionary).get("sprite", "npc_senior.png"))


func is_busy() -> bool:
	return _busy


func step() -> int:
	return int(GameState.task.get("step", Step.NONE))


func current_task() -> Dictionary:
	if GameState.task.is_empty():
		return {}
	return TaskData.get_task(int(GameState.task.get("index", 0)))


func destination_id() -> String:
	return str(current_task().get("destination", "school"))


func destination_name() -> String:
	return str(PLACE_NAMES.get(destination_id(), destination_id()))


func vendor_price(i: int) -> int:
	var vendors: Array = current_task().get("vendors", [])
	if i < 0 or i >= vendors.size():
		return 0
	var price: int = int((vendors[i] as Dictionary)["price"])
	if int(GameState.task.get("discount", -1)) == i:
		price = int(round(price * 0.85 / 10.0)) * 10
	return price


func objective_text() -> String:
	var map := GameState.map_id
	if map == "home":
		if not GameState.has_flag("home_intro"):
			return ""
		if GameState.day_over:
			return "목표: 침대에서 잠자기"
		return "목표: 현관문으로 나가 출근하기"
	if map == "school":
		match step():
			Step.ARRIVED:
				return "목표: 행정실 박 실장님께 납품하기"
			Step.DELIVERED:
				return "목표: 아래쪽 현관으로 나가 청사로 돌아가기"
		return "목표: 현관으로 나가 청사로 돌아가기"
	if not GameState.has_flag("intro_done"):
		return ""
	if GameState.task.is_empty():
		if not GameState.has_flag("met_leader"):
			return "목표: 위층 사무실의 김 팀장님께 인사하기"
		if GameState.tasks_done_today >= DAILY_TASKS:
			return "목표: 1층 현관으로 나가 퇴근하기"
		return "목표: 팀장님께 새 업무 받기 (%d/%d)" % [GameState.tasks_done_today + 1, DAILY_TASKS]
	match step():
		Step.ACCEPTED:
			return "목표: 내 자리 나라장터 PC에서 업체 고르기"
		Step.VENDOR_CHOSEN:
			return "목표: 주차장 납품 차량으로 출발하기"
		Step.ARRIVED:
			return "목표: 다시 차를 타고 %s에 납품하기" % destination_name()
		Step.DELIVERED:
			return "목표: 팀장님께 보고하기"
	return ""


## What the bouncing arrow points at: an NPC id, an object id or "exit:<map>".
func objective_target() -> String:
	var map := GameState.map_id
	if map == "home":
		if not GameState.has_flag("home_intro"):
			return ""
		return "bed" if GameState.day_over else "exit:office"
	if map == "school":
		return "officer_school" if step() == Step.ARRIVED else "exit:office"
	if not GameState.has_flag("intro_done"):
		return ""
	if GameState.task.is_empty():
		if GameState.has_flag("met_leader") and GameState.tasks_done_today >= DAILY_TASKS:
			return "exit:home"
		return "team_leader"
	match step():
		Step.ACCEPTED:
			return "narajangteo_pc"
		Step.VENDOR_CHOSEN, Step.ARRIVED:
			return "delivery_car"
		Step.DELIVERED:
			return "team_leader"
	return ""


## Drives the "!" marker above NPC heads.
func npc_has_news(id: String) -> bool:
	if not GameState.has_flag("intro_done"):
		return false
	match id:
		"team_leader":
			return step() == Step.DELIVERED or (step() == Step.NONE and GameState.tasks_done_today < DAILY_TASKS)
		"officer_school":
			return step() == Step.ARRIVED
	return false


func quick_item_id(in_drive: bool) -> String:
	for id: String in QUICK_ORDER:
		if GameState.item_count(id) > 0 and (not in_drive or ItemDB.usable_in_drive(id)):
			return id
	return ""


## Cargo damage multiplier for the drive minigame.
func cargo_damage_mult() -> float:
	var m := 1.0 - 0.2 * GameState.upgrade_level("truck")
	if bool(current_task().get("fragile", false)):
		m *= 1.5
	return m


func is_urgent() -> bool:
	return bool(GameState.task.get("urgent", false))


# ================================================================ entry points
func talk(id: String) -> void:
	if _busy:
		return
	_busy = true
	match id:
		"team_leader":
			await _talk_team_leader()
		"officer_school":
			await _talk_officer()
		"narumi":
			await _talk_narumi()
		"dari":
			await _talk_dari()
		"senior":
			await Dialogue.say(npc_name(id), [
				"업무는 할 만해요? 팁 하나 줄게요.",
				"검수 기준만 넘으면 비싼 업체를 고를 필요는 없어요. 대신 운전은 조심!",
			])
		"vendor":
			await Dialogue.say(npc_name(id), ["저희 회사도 나라장터에 입찰 참가 등록을 했어요.", "좋은 제품으로 공정하게 경쟁하겠습니다!"])
		"cafeteria":
			await Dialogue.say(npc_name(id), ["오늘 국밥 맛있어요~ 옆의 식권 발매기에서 뽑아 와요."])
		_:
			await Dialogue.say(npc_name(id), ["..."])
	_busy = false


func interact_object(id: String) -> void:
	if _busy:
		return
	_busy = true
	match id:
		"narajangteo_pc":
			await _use_pc()
		"delivery_car":
			await _use_car()
		"vending":
			await _shop("자판기", VENDING_ITEMS)
		"ticket_machine":
			await _shop("식권 발매기", TICKET_ITEMS)
		"mirror":
			await Dialogue.say("", ["거울 속 %s 씨, 오늘도 단정해요." % GameState.player_name])
		"notice_board":
			var tip: String = GENERAL_TIPS.pick_random()
			await Dialogue.say("게시판", ["[조달 상식] " + tip])
		"bed":
			await _use_bed()
		"wardrobe":
			await _use_wardrobe()
		"fridge":
			await _use_fridge()
		"water_cooler":
			await _use_cooler()
		_:
			await Dialogue.say("", ["특별한 것은 없어요."])
	_busy = false


func open_menu() -> void:
	if _busy:
		return
	_busy = true
	var c: int = await Dialogue.choose("메뉴", "무엇을 할까요?", ["업무 정보", "가방", "성장·시설", "저장하기", "타이틀로", "닫기"])
	match c:
		0:
			await _task_info()
		1:
			await _item_menu()
		2:
			await _growth_menu()
		3:
			GameState.save_game()
			Dialogue.toast("저장했어요.")
		4:
			var yes: int = await Dialogue.choose("메뉴", "타이틀로 돌아갈까요? (저장하지 않은 진행은 사라져요)", ["돌아가기", "취소"])
			if yes == 0:
				_busy = false
				SceneRouter.goto(SceneRouter.TITLE)
				return
	_busy = false


## Bottom menu bar (HUD). Each opens one panel of the menu directly.
func open_panel(panel: String) -> void:
	if _busy:
		return
	_busy = true
	match panel:
		"task":
			await _task_info()
		"bag":
			await _item_menu()
		"growth":
			await _growth_menu()
		"save":
			GameState.save_game()
			Dialogue.toast("저장했어요.")
	_busy = false


## Quick slot (Q / touch item button). Returns the id used, or "".
func use_quick_item(in_drive: bool) -> String:
	var id := quick_item_id(in_drive)
	if id == "":
		Dialogue.toast("사용할 아이템이 없어요.", UiTheme.COLOR_DIM)
		return ""
	Dialogue.toast(ItemDB.use(id), UiTheme.COLOR_GOOD)
	return id


func on_exit(from_map: String, to_map: String, spawn: String) -> void:
	if from_map == "home" and to_map == "office":
		if GameState.day_over:
			Dialogue.toast("오늘은 푹 쉬어요. 침대에서 자면 내일이 와요.", UiTheme.COLOR_WARN)
			return
		GameState.minutes = maxi(GameState.minutes, GameState.WORK_START)
		await SceneRouter.goto_map(to_map, spawn)
		if GameState.has_flag("intro_done"):
			Dialogue.toast("%d일차 출근! (%s)" % [GameState.day, GameState.clock_text()])
		return
	if from_map == "office" and to_map == "home":
		if not GameState.task.is_empty():
			Dialogue.toast("업무 중이에요! 맡은 일부터 끝내요.", UiTheme.COLOR_WARN)
			return
		if GameState.tasks_done_today < DAILY_TASKS:
			Dialogue.toast("아직 근무 시간이에요. (오늘 업무 %d/%d)" % [GameState.tasks_done_today, DAILY_TASKS], UiTheme.COLOR_WARN)
			return
		_busy = true
		await _go_home_evening(false)
		_busy = false
		return
	if from_map == "school" and to_map == "office":
		if step() == Step.ARRIVED:
			Dialogue.toast("아직 납품을 안 했어요! 다시 차를 타고 와야 해요.", UiTheme.COLOR_WARN)
		await SceneRouter.goto_map(to_map, spawn)
		if step() == Step.DELIVERED:
			GameState.advance_clock(30)
			Dialogue.toast("청사로 복귀! 팀장님께 보고하러 가요.")
			_work_fatigue(RETURN_FATIGUE, false)  # after arrival, so a forced leave starts in the office
		return
	SceneRouter.goto_map(to_map, spawn)


## Called by MapBase after a map is built.
func on_map_ready(map: String) -> void:
	GameState.map_id = map
	GameState.task_changed.emit()
	match map:
		"home":
			if not GameState.has_flag("home_intro"):
				await get_tree().create_timer(0.5).timeout
				await play_home_intro()
		"office":
			if not GameState.has_flag("intro_done"):
				await get_tree().create_timer(0.6).timeout
				await play_intro()
		"school":
			if step() == Step.ARRIVED:
				Dialogue.toast("%s에 도착! 행정실로 가요." % destination_name())


## Called by the drive minigame when the trip ends.
func on_drive_finished(cargo: int, stars: int) -> void:
	GameState.task["cargo"] = clampi(cargo, 0, 100)
	GameState.task["stars"] = int(GameState.task.get("stars", 0)) + stars
	GameState.task["step"] = Step.ARRIVED
	GameState.set_task(GameState.task)
	GameState.advance_clock(40)
	_work_fatigue(DRIVE_FATIGUE, true)
	SceneRouter.goto_map(destination_id(), "arrival")


func play_home_intro() -> void:
	while _busy or Dialogue.is_open:
		await get_tree().process_frame
	_busy = true
	await Dialogue.say("", [
		"띠리리리! 알람이 울려요.",
		"오늘은 조달청 첫 출근 날! %s 씨, 일어날 시간이에요." % GameState.player_name,
	])
	if GameState.is_touch_device():
		await Dialogue.say("", ["[조작] 이동: 화면 왼쪽을 누르고 끌기", "말 걸기·조사: A 버튼 / 메뉴: B 버튼 / 노란 버튼: 아이템", "아래쪽 메뉴 바에서 업무·가방·성장을 볼 수 있어요."])
	else:
		await Dialogue.say("", ["[조작] 이동: 방향키 또는 WASD", "말 걸기·조사: Space·Enter / 메뉴: Esc / 아이템: Q", "아래쪽 메뉴 바를 눌러 업무·가방·성장을 볼 수도 있어요."])
	await Dialogue.say("", ["냉장고와 옷장도 조사할 수 있어요. 준비가 되면 현관문으로 나가 출근해요!"])
	GameState.set_flag("home_intro")
	GameState.task_changed.emit()
	_busy = false


func play_intro() -> void:
	# The player may already be talking to someone (the intro starts after a delay).
	while _busy or Dialogue.is_open:
		await get_tree().process_frame
	_busy = true
	var me := GameState.player_name
	await Dialogue.say(npc_name("dari"), [
		"어서 와요! %s 씨 맞죠? 오늘 첫 출근이죠?" % me,
		"저는 달이예요! 현장 일을 도와주는 조달 파트너랍니다.",
		"사무실에는 나르미 선배도 있어요. 공정하고 믿음직한 멘토예요.",
		"먼저 위층 사무실의 김 팀장님께 인사하러 가 봐요! 노란 화살표를 따라가면 돼요.",
	])
	GameState.set_flag("intro_done")
	GameState.task_changed.emit()
	_busy = false


# ================================================================ conversations
func _talk_team_leader() -> void:
	var n := npc_name("team_leader")
	if not GameState.has_flag("met_leader"):
		await Dialogue.say(n, [
			"%s 씨, 반가워요. 오늘부터 우리 팀이에요." % GameState.player_name,
			"우리 조달청은 공공기관에 필요한 물건을 대신 사서 전달하는 일을 해요.",
			"말로 듣는 것보다 해 보는 게 빠르죠. 첫 업무 바로 갑니다!",
		])
		GameState.set_flag("met_leader")
	match step():
		Step.NONE:
			if GameState.tasks_done_today >= DAILY_TASKS:
				await Dialogue.say(n, ["오늘 정말 수고 많았어요! 1층 현관으로 나가면 퇴근이에요.", "집에 가서 푹 쉬어요."])
				return
			await _assign_task()
		Step.ACCEPTED:
			await Dialogue.say(n, ["자리에 있는 나라장터 PC에서 업체를 골라 주세요."])
		Step.VENDOR_CHOSEN, Step.ARRIVED:
			await Dialogue.say(n, ["주차장에 납품 차량이 있어요. %s까지 조심히 다녀와요." % destination_name()])
		Step.DELIVERED:
			await _report()


func _assign_task() -> void:
	var index := 0
	if GameState.tasks_completed > 0:
		index = GameState.rng.randi_range(0, TaskData.TASKS.size() - 2)
		if index >= GameState.last_task_index:
			index += 1  # skip the previous task so two in a row never match
	GameState.last_task_index = index
	var t := TaskData.get_task(index)
	var urgent := GameState.tasks_completed > 0 and GameState.rng.randf() < URGENT_CHANCE
	var lines: Array = (t["brief"] as Array).duplicate()
	if urgent:
		lines.append("[긴급] 그리고 이건 급한 요청이에요! 보상이 1.5배예요.")
	await Dialogue.say(npc_name("team_leader"), lines)
	GameState.set_task({
		"index": index, "step": Step.ACCEPTED, "vendor": -1, "cargo": 0, "grade": "",
		"urgent": urgent, "discount": -1, "discount_rolled": false, "stars": 0,
	})
	GameState.advance_clock(10)
	await _tip("accepted")


func _use_pc() -> void:
	if step() != Step.ACCEPTED:
		await Dialogue.say("나라장터", ["국가종합전자조달시스템 '나라장터' 화면이 켜져 있어요.", "지금은 진행 중인 입찰이 없어요."])
		return
	var t := current_task()
	var vendors: Array = t["vendors"]
	if not bool(GameState.task.get("discount_rolled", false)):
		GameState.task["discount_rolled"] = true
		if GameState.tasks_completed > 0 and GameState.rng.randf() < DISCOUNT_CHANCE:
			var d := GameState.rng.randi_range(0, vendors.size() - 1)
			GameState.task["discount"] = d
			await Dialogue.say("나라장터", ["[특가] %s 가격을 낮춰 다시 제안했어요!" % Korean.i_ga(str((vendors[d] as Dictionary)["name"]))])
	var required := int(t["required"])
	var head := "[%s] 배정 예산 %d만원 / 검수 기준: 품질 %d점 이상" % [t["item"], int(t["budget"]), required]
	if bool(t.get("fragile", false)):
		head += " / 파손 주의"
	var lines: Array = [head, "검수 점수 = 업체 품질 x 화물 상태. 기준을 넘는 가장 싼 업체를 찾아봐요!"]
	var analysis := GameState.upgrade_level("analysis") > 0
	for i in vendors.size():
		var v: Dictionary = vendors[i]
		var sale := " (특가!)" if int(GameState.task.get("discount", -1)) == i else ""
		var line := "%s - %d만원%s / 품질 %d점\n%s" % [v["name"], vendor_price(i), sale, int(v["quality"]), v["desc"]]
		if analysis:
			var q := float(v["quality"])
			line += "\n[분석] 화물 100%%면 %s, 85%%면 %s" % [TaskData.grade(q, required), TaskData.grade(q * 0.85, required)]
		lines.append(line)
	await Dialogue.say("나라장터", lines)
	var options: Array = []
	for i in vendors.size():
		options.append("%s (%d만원, 품질 %d)" % [(vendors[i] as Dictionary)["name"], vendor_price(i), int((vendors[i] as Dictionary)["quality"])])
	options.append("나중에 고르기")
	var c: int = await Dialogue.choose("나라장터", "어느 업체와 계약할까요?", options)
	if c >= vendors.size():
		return
	var chosen: Dictionary = vendors[c]
	GameState.task["vendor"] = c
	GameState.task["step"] = Step.VENDOR_CHOSEN
	GameState.set_task(GameState.task)
	GameState.advance_clock(20)
	_work_fatigue(SELECT_FATIGUE, false)  # a forced leave waits until this conversation ends
	await Dialogue.say("", ["%s 계약했어요! 주차장의 납품 차량으로 가요." % Korean.wa(str(chosen["name"]))])
	await _tip("vendor")


func _use_car() -> void:
	if step() != Step.VENDOR_CHOSEN and step() != Step.ARRIVED:
		await Dialogue.say("", ["조달청 납품 차량이에요. 지금은 실을 물건이 없어요."])
		return
	var warn := ""
	if bool(current_task().get("fragile", false)):
		warn = " (파손 주의!)"
	var c: int = await Dialogue.choose("", "%s 납품하러 출발할까요?%s" % [Korean.ro(destination_name()), warn], ["출발!", "아직"])
	if c == 0:
		SceneRouter.goto(SceneRouter.DRIVE)


func _talk_officer() -> void:
	var n := npc_name("officer_school")
	if step() == Step.ARRIVED and destination_id() == "school":
		var t := current_task()
		var vendors: Array = t["vendors"]
		var v: Dictionary = vendors[int(GameState.task["vendor"])]
		var cargo := int(GameState.task.get("cargo", 100))
		var required := int(t["required"])
		var score := float(v["quality"]) * cargo / 100.0
		var g := TaskData.grade(score, required)
		var reaction := "꼼꼼하게 챙겨 주셨네요. 아이들이 정말 좋아하겠어요!"
		if g == "보통":
			reaction = "기준은 통과예요. 쓰는 데 문제없겠어요."
		elif g == "미흡":
			reaction = "음... 기준에 못 미쳐요. 보완이 필요하겠어요."
		await Dialogue.say(n, [
			"조달청에서 오셨군요! %s 맞죠?" % t["item"],
			"바로 검수해 볼게요...",
			"검수 결과: [%s] %d점 (품질 %d x 화물 %d%%, 기준 %d점)" % [g, roundi(score), int(v["quality"]), cargo, required],
			reaction,
		])
		GameState.task["grade"] = g
		GameState.task["step"] = Step.DELIVERED
		GameState.set_task(GameState.task)
		GameState.advance_clock(20)
		GameState.popup.emit("검수 " + g, _grade_color(g))
		if GameState.tasks_completed > 0 and GameState.rng.randf() < REQUEST_CHANCE:
			await _officer_request(n)
		await _tip("inspection")
	elif step() == Step.DELIVERED:
		await Dialogue.say(n, ["수고하셨어요. 청사에 돌아가서 보고 잘 하세요!"])
	else:
		await Dialogue.say(n, ["한빛초 행정실이에요. 필요한 물품이 생기면 조달청에 요청한답니다."])


func _officer_request(n: String) -> void:
	var c: int = await Dialogue.choose(n, "혹시 시간 괜찮으면 교실까지 옮기는 것 좀 도와주실래요?", ["도와드릴게요 (피로 +%d, 평판 +4)" % HELP_FATIGUE, "다음 일정이 있어서요"])
	if c == 0:
		_work_fatigue(HELP_FATIGUE, true)
		GameState.add_rewards(0, 4, 0)
		GameState.log_add("rep", 4)
		GameState.advance_clock(20)
		GameState.popup.emit("평판 +4", UiTheme.COLOR_GOOD)
		await Dialogue.say(n, ["정말 고마워요! 조달청 분들은 역시 다르네요."])
	else:
		await Dialogue.say(n, ["아유, 바쁘시죠. 괜찮아요!"])


func _report() -> void:
	var n := npc_name("team_leader")
	var t := current_task()
	var vi := int(GameState.task["vendor"])
	var g := str(GameState.task.get("grade", "보통"))
	var saved := int(t["budget"]) - vendor_price(vi)
	var mult := GameState.reward_multiplier() * (URGENT_MULT if is_urgent() else 1.0)
	var rep := roundi(TaskData.reputation_for(g) * mult)
	var xp := roundi(int(t["exp"]) * mult)
	var bonus := roundi(TaskData.bonus_for(g) * mult)
	var lines: Array = ["보고 잘 받았어요. 검수 결과는 [%s]이군요." % g]
	if saved > 0:
		lines.append("예산도 %d만원 아꼈네요. 팀 예산으로 시설을 바꿀 수 있어요." % saved)
	if g == "미흡":
		lines.append("싼 게 항상 좋은 건 아니에요. 검수 기준을 꼭 같이 봐요.")
	elif g == "우수":
		lines.append("아주 잘했어요! 수요기관에서도 칭찬이 자자하네요.")
	if is_urgent():
		lines.append("급한 건까지 처리해 줘서 고마워요. 보상 1.5배!")
	lines.append("보상: 팀 예산 %+d만원, 평판 %+d, 경험치 +%d, 성과급 %s원 (컨디션 %s)" % [saved, rep, xp, Korean.comma(bonus), GameState.condition_label()])
	await Dialogue.say(n, lines)
	var promoted := GameState.add_rewards(saved, rep, xp)
	GameState.add_money(bonus)
	GameState.log_add("tasks", 1)
	GameState.log_add("budget", saved)
	GameState.log_add("rep", rep)
	GameState.log_add("exp", xp)
	GameState.log_add("money", bonus)
	GameState.popup.emit("예산 %+d만원" % saved, UiTheme.COLOR_GOOD if saved >= 0 else UiTheme.COLOR_BAD)
	GameState.popup.emit("평판 %+d" % rep, UiTheme.COLOR_GOOD if rep >= 0 else UiTheme.COLOR_BAD)
	GameState.tasks_done_today += 1
	GameState.tasks_completed += 1
	GameState.set_task({})
	GameState.advance_clock(10)
	if promoted:
		GameState.popup.emit("승진! " + GameState.rank_name(), UiTheme.COLOR_WARN)
		await Dialogue.say(n, ["그리고... 축하해요! 오늘부로 %s 승진이에요! 일당도 올라요." % Korean.ro(GameState.rank_name())])
	await _tip("report")
	GameState.save_game()
	Dialogue.toast("자동 저장했어요.", UiTheme.COLOR_DIM)


func _talk_narumi() -> void:
	var n := npc_name("narumi")
	var hint := objective_text().replace("목표: ", "")
	var lines: Array = []
	if hint != "":
		lines.append("지금 할 일은 '%s'예요." % hint)
	var tip: String = GENERAL_TIPS.pick_random()
	lines.append("[조달 상식] " + tip)
	await Dialogue.say(n, lines)


func _talk_dari() -> void:
	var n := npc_name("dari")
	if GameState.fatigue >= GameState.FATIGUE_BAD_AT:
		await Dialogue.say(n, ["얼굴이 피곤해 보여요! 구내식당 국밥 한 그릇 어때요?", "아래 메뉴 바의 [가방]에서 아이템을 쓸 수 있어요."])
	elif GameState.coffee_today > GameState.COFFEE_LIMIT:
		await Dialogue.say(n, ["커피를 너무 많이 마셨어요! 컨디션이 떨어졌을 거예요."])
	elif GameState.budget >= 100 and GameState.upgrades.is_empty():
		await Dialogue.say(n, ["팀 예산이 꽤 모였네요! 메뉴 바의 [성장]에서 시설을 업그레이드해 봐요."])
	else:
		await Dialogue.say(n, ["오늘도 힘내요! 피로도가 70을 넘으면 컨디션이 나빠지니까 조심해요."])


# ================================================================ home
func _use_bed() -> void:
	if not GameState.day_over:
		await Dialogue.say("", ["아직 잘 시간이 아니에요. 출근해야죠!"])
		return
	var c: int = await Dialogue.choose("", "푹 자고 내일을 맞을까요?", ["잔다", "조금 더 깨어 있기"])
	if c != 0:
		return
	GameState.end_day()
	await SceneRouter.goto(SceneRouter.HOME, "bed")
	Dialogue.toast("%d일차 아침! 일당 %s원이 들어왔어요." % [GameState.day, Korean.comma(GameState.daily_pay())], UiTheme.COLOR_GOOD)


func _use_wardrobe() -> void:
	var c: int = await Dialogue.choose("옷장", "옷을 갈아입을까요?", ["갈아입기", "그만두기"])
	if c == 0:
		GameState.editing_look = true
		SceneRouter.goto(SceneRouter.CHARACTER_CREATE)


func _use_fridge() -> void:
	if GameState.fridge_day == GameState.day:
		await Dialogue.say("", ["냉장고가 텅 비었어요. 내일 또 채워 둘게요."])
		return
	GameState.fridge_day = GameState.day
	GameState.add_item("energybar")
	GameState.popup.emit("에너지바 +1", UiTheme.COLOR_GOOD)
	await Dialogue.say("", ["냉장고에서 에너지바를 챙겼어요!", "운전 중에 Q(노란 버튼)로 먹으면 졸음이 사라져요."])


func _use_cooler() -> void:
	if GameState.cooler_day == GameState.day:
		await Dialogue.say("", ["방금 마셨어요. 물배가 불러요."])
		return
	GameState.cooler_day = GameState.day
	GameState.recover_fatigue(5)
	GameState.popup.emit("피로 -5", UiTheme.COLOR_GOOD)
	await Dialogue.say("", ["시원한 물 한 잔! 정신이 맑아져요."])


## Leaving work (normal or forced): go home, show the day summary, then sleep at the bed.
func _go_home_evening(forced: bool) -> void:
	GameState.day_over = true
	GameState.minutes = maxi(GameState.minutes, GameState.WORK_END if not forced else GameState.minutes)
	await SceneRouter.goto(SceneRouter.HOME, "door")
	var dl := GameState.day_log
	var lines: Array = ["[%d일차 정산] %s 퇴근" % [GameState.day, GameState.clock_text()]]
	if forced:
		lines.append("피로가 한계라 일찍 퇴근했어요. 남은 업무는 내일 이어서 해요.")
	lines.append("완료한 업무 %d건 / 팀 예산 %+d만원 / 평판 %+d / 경험치 +%d" % [
		int(dl.get("tasks", 0)), int(dl.get("budget", 0)), int(dl.get("rep", 0)), int(dl.get("exp", 0))])
	lines.append("성과급·운전 보너스 +%s원 / 내일 아침 일당 %s원" % [Korean.comma(int(dl.get("money", 0))), Korean.comma(GameState.daily_pay())])
	lines.append("침대에서 자면 다음 날이 시작돼요.")
	await Dialogue.say("오늘의 정산", lines)
	GameState.task_changed.emit()
	GameState.save_game()


# ================================================================ menus
func _task_info() -> void:
	if GameState.task.is_empty():
		await Dialogue.say("업무 정보", ["진행 중인 업무가 없어요. (오늘 %d/%d건)" % [GameState.tasks_done_today, DAILY_TASKS], objective_text()])
		return
	var t := current_task()
	var lines: Array = []
	var tags := ""
	if is_urgent():
		tags += " [긴급]"
	if bool(t.get("fragile", false)):
		tags += " [파손 주의]"
	lines.append("%s%s / 예산 %d만원 / 검수 기준 품질 %d점" % [t["item"], tags, int(t["budget"]), int(t["required"])])
	var vi := int(GameState.task.get("vendor", -1))
	if vi >= 0:
		var v: Dictionary = (t["vendors"] as Array)[vi]
		lines.append("계약 업체: %s (%d만원, 품질 %d점)" % [v["name"], vendor_price(vi), int(v["quality"])])
	if step() >= Step.ARRIVED:
		lines.append("화물 상태: %d%%" % int(GameState.task.get("cargo", 0)))
	lines.append(objective_text())
	await Dialogue.say("업무 정보", lines)


func _growth_menu() -> void:
	while true:
		var next := GameState.next_rank_exp()
		var rank_line := "%s / 경험치 %d" % [GameState.rank_name(), GameState.experience]
		if next > 0:
			rank_line += " (다음 승진 %d)" % next
		var options: Array = []
		for u: Dictionary in TaskData.UPGRADES:
			var lv := GameState.upgrade_level(str(u["id"]))
			var costs: Array = u["costs"]
			if lv >= costs.size():
				options.append("%s Lv%d (최대)" % [u["name"], lv])
			else:
				options.append("%s Lv%d -> %d: %d만원" % [u["name"], lv, lv + 1, int(costs[lv])])
		options.append("닫기")
		var c: int = await Dialogue.choose("성장·시설", "%s\n팀 예산 %s만원으로 무엇을 바꿀까요?" % [rank_line, Korean.comma(GameState.budget)], options)
		if c >= TaskData.UPGRADES.size():
			return
		var up: Dictionary = TaskData.UPGRADES[c]
		var id := str(up["id"])
		var level := GameState.upgrade_level(id)
		var cost_list: Array = up["costs"]
		if level >= cost_list.size():
			Dialogue.toast("이미 최고 레벨이에요.", UiTheme.COLOR_DIM)
			continue
		var cost := int(cost_list[level])
		var yes: int = await Dialogue.choose("성장·시설", "%s\n%d만원을 쓸까요?" % [up["desc"], cost], ["업그레이드", "취소"])
		if yes != 0:
			continue
		if GameState.spend_budget(cost):
			GameState.upgrades[id] = level + 1
			GameState.popup.emit("%s Lv%d!" % [up["name"], level + 1], UiTheme.COLOR_WARN)
			Dialogue.toast("%s Lv%d 완료!" % [up["name"], level + 1], UiTheme.COLOR_GOOD)
			GameState.stats_changed.emit()
		else:
			Dialogue.toast("팀 예산이 부족해요. 업무로 예산을 아껴 봐요.", UiTheme.COLOR_BAD)


# ================================================================ shops / items
func _shop(title: String, items: Array) -> void:
	while true:
		var options: Array = []
		for id: String in items:
			options.append("%s %s원" % [ItemDB.item_name(id), Korean.comma(ItemDB.price(id))])
		options.append("그만두기")
		var prompt := "무엇을 살까요? (지갑 %s원)" % Korean.comma(GameState.money)
		var c: int = await Dialogue.choose(title, prompt, options)
		if c >= items.size():
			return
		var item_id: String = items[c]
		if GameState.spend_money(ItemDB.price(item_id)):
			GameState.add_item(item_id)
			Dialogue.toast("%s 구입! (가방에서 사용)" % ItemDB.item_name(item_id), UiTheme.COLOR_GOOD)
		else:
			Dialogue.toast("돈이 부족해요.", UiTheme.COLOR_BAD)


func _item_menu() -> void:
	var ids: Array = []
	var options: Array = []
	for id: String in QUICK_ORDER:
		if GameState.item_count(id) > 0:
			ids.append(id)
			options.append("%s x%d" % [ItemDB.item_name(id), GameState.item_count(id)])
	if ids.is_empty():
		await Dialogue.say("가방", ["가진 아이템이 없어요. (지갑 %s원)" % Korean.comma(GameState.money), "구내식당 자판기나 식권 발매기에서 살 수 있어요."])
		return
	options.append("닫기")
	var c: int = await Dialogue.choose("가방", "무엇을 사용할까요? (피로도 %d / 지갑 %s원)" % [GameState.fatigue, Korean.comma(GameState.money)], options)
	if c < ids.size():
		Dialogue.toast(ItemDB.use(str(ids[c])), UiTheme.COLOR_GOOD)


# ================================================================ day cycle
func _on_forced_leave() -> void:
	if _forced_pending:
		return
	_forced_pending = true
	# Wait for the current conversation or scene change to finish.
	while _busy or Dialogue.is_open or SceneRouter.busy:
		await get_tree().process_frame
	_busy = true
	await Dialogue.say(npc_name("narumi"), ["앗, 너무 무리했어요! 피로도가 한계예요.", "오늘은 여기까지 하고 집에 가서 푹 쉬어요."])
	await _go_home_evening(true)
	_busy = false
	_forced_pending = false


## Work fatigue, reduced by the lounge upgrade. cap: never force a leave from this
## (driving, or helping at the school) - it stops at 99.
func _work_fatigue(amount: int, cap: bool) -> void:
	var scaled := roundi(amount * (1.0 - 0.15 * GameState.upgrade_level("lounge")))
	if cap:
		scaled = mini(scaled, GameState.FATIGUE_MAX - 1 - GameState.fatigue)
	GameState.add_fatigue(scaled)
	if scaled > 0:
		GameState.popup.emit("피로 +%d" % scaled, UiTheme.COLOR_WARN)


func _grade_color(g: String) -> Color:
	match g:
		"우수":
			return UiTheme.COLOR_GOOD
		"보통":
			return UiTheme.COLOR_WARN
	return UiTheme.COLOR_BAD


func _tip(key: String) -> void:
	var flag := "tip_" + key
	if GameState.has_flag(flag) or not POLICY_TIPS.has(key):
		return
	GameState.set_flag(flag)
	await Dialogue.say(npc_name("narumi"), ["[조달 상식] " + str(POLICY_TIPS[key])])
