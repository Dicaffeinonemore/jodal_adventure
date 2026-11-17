extends Node
## Game rules and dialogue that span scenes: the core loop
## (요청 접수 -> 업체 선정 -> 운송 -> 납품·검수 -> 보고 -> 보상), NPC conversations,
## shops, the menu, the intro and forced leave.
##
## GameState.task is {} when idle, otherwise:
##   {"index": int (TaskData index), "step": Step, "vendor": int (-1 = none),
##    "cargo": int (0-100, after driving), "grade": String (after inspection)}
##
## All player-facing text lives in this file and in scripts/data/task_data.gd.
## Review policy facts (POLICY_TIPS, GENERAL_TIPS) against official 조달청 sources
## before submitting.

enum Step { NONE, ACCEPTED, VENDOR_CHOSEN, ARRIVED, DELIVERED }

# Balancing (initial values). One task costs about 35 fatigue, so the third task
# of the day hits the limit unless the player eats or drinks something.
const DAILY_TASKS := 3
const DRIVE_FATIGUE := 20
const SELECT_FATIGUE := 8
const RETURN_FATIGUE := 7

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

const PLACE_NAMES := {"school": "한빛초등학교", "office": "정부청사"}

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


func objective_text() -> String:
	if not GameState.has_flag("intro_done"):
		return ""
	if GameState.task.is_empty():
		if not GameState.has_flag("met_leader"):
			return "목표: 사무실의 김 팀장님께 인사하기"
		if GameState.tasks_done_today >= DAILY_TASKS:
			return "목표: 팀장님께 퇴근 인사하기"
		return "목표: 팀장님께 새 업무 받기"
	match step():
		Step.ACCEPTED:
			return "목표: 내 자리 나라장터 PC에서 업체 고르기"
		Step.VENDOR_CHOSEN:
			return "목표: 주차장 납품 차량으로 출발하기"
		Step.ARRIVED:
			return "목표: %s 행정실에 납품하기" % destination_name()
		Step.DELIVERED:
			return "목표: 청사로 돌아가 팀장님께 보고하기"
	return ""


## Drives the "!" marker above NPC heads.
func npc_has_news(id: String) -> bool:
	if not GameState.has_flag("intro_done"):
		return false
	match id:
		"team_leader":
			return step() == Step.NONE or step() == Step.DELIVERED
		"officer_school":
			return step() == Step.ARRIVED
	return false


func quick_item_id(in_drive: bool) -> String:
	for id: String in QUICK_ORDER:
		if GameState.item_count(id) > 0 and (not in_drive or ItemDB.usable_in_drive(id)):
			return id
	return ""


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
			await Dialogue.say(npc_name(id), ["업무는 할 만해요? 모르는 건 언제든 물어봐요.", "(조달 상식 퀴즈는 준비 중 - P2)"])
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
			await Dialogue.say("", ["거울 속 %s 씨, 오늘도 단정하다." % GameState.player_name])
		"notice_board":
			var tip: String = GENERAL_TIPS.pick_random()
			await Dialogue.say("게시판", ["[조달 상식] " + tip])
		_:
			await Dialogue.say("", ["특별한 것은 없다."])
	_busy = false


func open_menu() -> void:
	if _busy:
		return
	_busy = true
	var c: int = await Dialogue.choose("메뉴", "무엇을 할까요?", ["아이템", "저장하기", "타이틀로", "닫기"])
	match c:
		0:
			await _item_menu()
		1:
			GameState.save_game()
			Dialogue.toast("저장했어요.")
		2:
			var yes: int = await Dialogue.choose("메뉴", "타이틀로 돌아갈까요? (저장하지 않은 진행은 사라져요)", ["돌아가기", "취소"])
			if yes == 0:
				_busy = false
				SceneRouter.goto(SceneRouter.TITLE)
				return
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
	if from_map == "school" and to_map == "office":
		if step() == Step.ARRIVED:
			Dialogue.toast("아직 납품을 안 했어요! 다시 차를 타고 와야 해요.", UiTheme.COLOR_WARN)
		await SceneRouter.goto_map(to_map, spawn)
		if step() == Step.DELIVERED:
			Dialogue.toast("청사로 복귀! 팀장님께 보고하러 가요.")
			GameState.add_fatigue(RETURN_FATIGUE)  # after arrival, so a forced leave starts in the office
		return
	SceneRouter.goto_map(to_map, spawn)


func on_arrived(map: String) -> void:
	if step() == Step.ARRIVED and map == destination_id():
		Dialogue.toast("%s에 도착! 행정실로 가요." % destination_name())


## Called by the drive minigame when the trip ends.
func on_drive_finished(cargo: int) -> void:
	GameState.task["cargo"] = clampi(cargo, 0, 100)
	GameState.task["step"] = Step.ARRIVED
	GameState.set_task(GameState.task)
	_add_capped_fatigue(DRIVE_FATIGUE)
	SceneRouter.goto_map(destination_id(), "arrival")


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
		"먼저 위층 사무실의 김 팀장님께 인사하러 가 봐요!",
	])
	if GameState.is_touch_device():
		await Dialogue.say("", ["[조작] 이동: 화면 왼쪽을 누르고 끌기", "말 걸기·조사: A 버튼 / 메뉴: B 버튼 / 노란 버튼: 아이템"])
	else:
		await Dialogue.say("", ["[조작] 이동: 방향키 또는 WASD", "말 걸기·조사: Space·Enter / 메뉴: Esc / 아이템: Q"])
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
				var c: int = await Dialogue.choose(n, "오늘 정말 수고 많았어요. 이제 퇴근해요!", ["퇴근하기", "조금 더 둘러보기"])
				if c == 0:
					await _end_day()
				return
			await _assign_task()
		Step.ACCEPTED:
			await Dialogue.say(n, ["자리에 있는 나라장터 PC에서 업체를 골라 주세요."])
		Step.VENDOR_CHOSEN, Step.ARRIVED:
			await Dialogue.say(n, ["주차장에 납품 차량이 있어요. %s까지 조심히 다녀와요." % destination_name()])
		Step.DELIVERED:
			await _report()


func _assign_task() -> void:
	var index := GameState.tasks_completed
	var t := TaskData.get_task(index)
	await Dialogue.say(npc_name("team_leader"), t["brief"])
	GameState.set_task({"index": index, "step": Step.ACCEPTED, "vendor": -1, "cargo": 0, "grade": ""})
	await _tip("accepted")


func _use_pc() -> void:
	if step() != Step.ACCEPTED:
		await Dialogue.say("나라장터", ["국가종합전자조달시스템 '나라장터' 화면이 켜져 있다.", "지금은 진행 중인 입찰이 없다."])
		return
	var t := current_task()
	var vendors: Array = t["vendors"]
	var lines: Array = ["[%s] 입찰 결과가 도착했다. 배정 예산은 %d만원." % [t["item"], int(t["budget"])]]
	for v: Dictionary in vendors:
		lines.append("%s - %d만원 / 품질 %d점\n%s" % [v["name"], int(v["price"]), int(v["quality"]), v["desc"]])
	await Dialogue.say("나라장터", lines)
	var options: Array = []
	for v: Dictionary in vendors:
		options.append("%s (%d만원)" % [v["name"], int(v["price"])])
	options.append("나중에 고르기")
	var c: int = await Dialogue.choose("나라장터", "어느 업체와 계약할까?", options)
	if c >= vendors.size():
		return
	var chosen: Dictionary = vendors[c]
	GameState.task["vendor"] = c
	GameState.task["step"] = Step.VENDOR_CHOSEN
	GameState.set_task(GameState.task)
	GameState.add_fatigue(SELECT_FATIGUE)  # a forced leave waits until this conversation ends
	await Dialogue.say("", ["%s 계약했다! 주차장의 납품 차량으로 가자." % Korean.wa(str(chosen["name"]))])
	await _tip("vendor")


func _use_car() -> void:
	if step() != Step.VENDOR_CHOSEN and step() != Step.ARRIVED:
		await Dialogue.say("", ["조달청 납품 차량이다. 지금은 실을 물건이 없다."])
		return
	var c: int = await Dialogue.choose("", "%s 납품하러 출발할까?" % Korean.ro(destination_name()), ["출발!", "아직"])
	if c == 0:
		SceneRouter.goto(SceneRouter.DRIVE)


func _talk_officer() -> void:
	var n := npc_name("officer_school")
	if step() == Step.ARRIVED and destination_id() == "school":
		var t := current_task()
		var vendors: Array = t["vendors"]
		var v: Dictionary = vendors[int(GameState.task["vendor"])]
		var cargo := int(GameState.task.get("cargo", 100))
		var score := float(v["quality"]) * cargo / 100.0
		var g := TaskData.grade(score)
		var reaction := "꼼꼼하게 챙겨 주셨네요. 아이들이 정말 좋아하겠어요!"
		if g == "보통":
			reaction = "쓰는 데는 문제없겠어요. 다음엔 조금 더 신경 써 주세요."
		elif g == "미흡":
			reaction = "음... 상태가 좋지 않은 게 섞여 있네요. 보완이 필요하겠어요."
		await Dialogue.say(n, [
			"조달청에서 오셨군요! %s 맞죠?" % t["item"],
			"바로 검수해 볼게요...",
			"검수 결과: [%s] (품질 %d점 x 화물 상태 %d%%)" % [g, int(v["quality"]), cargo],
			reaction,
		])
		GameState.task["grade"] = g
		GameState.task["step"] = Step.DELIVERED
		GameState.set_task(GameState.task)
		await _tip("inspection")
	elif step() == Step.DELIVERED:
		await Dialogue.say(n, ["수고하셨어요. 청사에 돌아가서 보고 잘 하세요!"])
	else:
		await Dialogue.say(n, ["한빛초 행정실이에요. 필요한 물품이 생기면 조달청에 요청한답니다."])


func _report() -> void:
	var n := npc_name("team_leader")
	var t := current_task()
	var vendors: Array = t["vendors"]
	var v: Dictionary = vendors[int(GameState.task["vendor"])]
	var g := str(GameState.task.get("grade", "보통"))
	var saved := int(t["budget"]) - int(v["price"])
	var mult := GameState.reward_multiplier()
	var rep := roundi(TaskData.reputation_for(g) * mult)
	var xp := roundi(int(t["exp"]) * mult)
	var lines: Array = ["보고 잘 받았어요. 검수 결과는 [%s]이군요." % g]
	if saved > 0:
		lines.append("예산도 %d만원 아꼈네요." % saved)
	if g == "미흡":
		lines.append("싼 게 항상 좋은 건 아니에요. 품질도 꼭 같이 봐요.")
	elif g == "우수":
		lines.append("아주 잘했어요! 수요기관에서도 칭찬이 자자하네요.")
	lines.append("보상: 팀 예산 %+d만원, 평판 %+d, 경험치 +%d (컨디션 %s)" % [saved, rep, xp, GameState.condition_label()])
	await Dialogue.say(n, lines)
	var promoted := GameState.add_rewards(saved, rep, xp)
	GameState.tasks_done_today += 1
	GameState.tasks_completed += 1
	GameState.set_task({})
	if promoted:
		await Dialogue.say(n, ["그리고... 축하해요! 오늘부로 %s 승진이에요!" % Korean.ro(GameState.rank_name())])
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
		await Dialogue.say(n, ["얼굴이 피곤해 보여요! 구내식당 국밥 한 그릇 어때요?", "메뉴(Esc / B 버튼)에서 아이템을 쓸 수 있어요."])
	elif GameState.coffee_today > GameState.COFFEE_LIMIT:
		await Dialogue.say(n, ["커피를 너무 많이 마셨어요! 컨디션이 떨어졌을 거예요."])
	else:
		await Dialogue.say(n, ["오늘도 힘내요! 피로도가 70을 넘으면 컨디션이 나빠지니까 조심해요."])


# ================================================================ shops / items
func _shop(title: String, items: Array) -> void:
	while true:
		var options: Array = []
		for id: String in items:
			options.append("%s %s원" % [ItemDB.item_name(id), Korean.comma(ItemDB.price(id))])
		options.append("그만두기")
		var prompt := "무엇을 살까? (지갑 %s원)" % Korean.comma(GameState.money)
		var c: int = await Dialogue.choose(title, prompt, options)
		if c >= items.size():
			return
		var item_id: String = items[c]
		if GameState.spend_money(ItemDB.price(item_id)):
			GameState.add_item(item_id)
			Dialogue.toast("%s 구입! (메뉴에서 사용)" % ItemDB.item_name(item_id), UiTheme.COLOR_GOOD)
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
		await Dialogue.say("", ["가진 아이템이 없다. 자판기나 식권 발매기에서 살 수 있다."])
		return
	options.append("닫기")
	var c: int = await Dialogue.choose("아이템", "무엇을 사용할까? (피로도 %d)" % GameState.fatigue, options)
	if c < ids.size():
		Dialogue.toast(ItemDB.use(str(ids[c])), UiTheme.COLOR_GOOD)


# ================================================================ day cycle
func _end_day() -> void:
	await Dialogue.say(npc_name("narumi"), ["오늘도 수고했어요! 푹 쉬고 내일 봐요."])
	GameState.end_day()
	await SceneRouter.goto(SceneRouter.OFFICE, "entrance")
	Dialogue.toast("%d일차 출근! 일당 %s원이 들어왔어요." % [GameState.day, Korean.comma(GameState.DAILY_PAY)])


func _on_forced_leave() -> void:
	if _forced_pending:
		return
	_forced_pending = true
	# Wait for the current conversation or scene change to finish.
	while _busy or Dialogue.is_open or SceneRouter.busy:
		await get_tree().process_frame
	_busy = true
	await Dialogue.say(npc_name("narumi"), ["앗, 너무 무리했어요! 피로도가 한계예요.", "오늘은 여기까지 하고 푹 쉬어요."])
	GameState.end_day()
	_busy = false
	_forced_pending = false
	await SceneRouter.goto(SceneRouter.OFFICE, "entrance")
	Dialogue.toast("%d일차 출근! 무리하지 말아요." % GameState.day)


## Driving never forces a leave mid-trip: fatigue from it stops at 99.
func _add_capped_fatigue(amount: int) -> void:
	GameState.add_fatigue(mini(amount, GameState.FATIGUE_MAX - 1 - GameState.fatigue))


func _tip(key: String) -> void:
	var flag := "tip_" + key
	if GameState.has_flag(flag) or not POLICY_TIPS.has(key):
		return
	GameState.set_flag(flag)
	await Dialogue.say(npc_name("narumi"), ["[조달 상식] " + str(POLICY_TIPS[key])])
