extends Node
## Game rules and dialogue that span scenes: the day cycle (집 -> 청사 -> 집),
## the core loop (요청 접수 -> 업체 선정 -> 운송 -> 납품·검수 -> 보고 -> 보상),
## NPC conversations, shops, the cafeteria, upgrades, the menu, intros and forced leave.
##
## Destinations (수요기관) are listed in DESTINATIONS: each has its own map, receiver
## NPC (who inspects the delivery) and lines. Tasks pick one with "destination".
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
const QC_FATIGUE := 5
const LATE_REPUTATION := 4  # delivered after the driving time limit
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
	# 수요기관
	"teacher": {"name": "최 선생님", "sprite": "npc_teacher.png", "color": Color("ffc9a8")},
	"student": {"name": "하늘이", "sprite": "npc_student.png", "color": Color("ffe27a")},
	"officer_fire": {"name": "정 소방장", "sprite": "npc_officer_fire.png", "color": Color("ff9d8a")},
	"firefighter": {"name": "강 소방교", "sprite": "npc_firefighter.png", "color": Color("ffb36b")},
	"officer_clinic": {"name": "한 주무관", "sprite": "npc_officer_clinic.png", "color": Color("9ff0c8")},
	"nurse": {"name": "윤 간호사", "sprite": "npc_nurse.png", "color": Color("a8dcff")},
	"officer_center": {"name": "오 주무관", "sprite": "npc_officer_center.png", "color": Color("c8e6a0")},
	"citizen": {"name": "동네 어르신", "sprite": "npc_citizen.png", "color": Color("e0d0c0")},
	"inspector": {"name": "서 검사관", "sprite": "npc_inspector.png", "color": Color("b0e0ff")},
	"officer_nursing": {"name": "문 과장", "sprite": "npc_officer_nursing.png", "color": Color("f0c8a0")},
	"caregiver": {"name": "송 요양보호사", "sprite": "npc_caregiver.png", "color": Color("ffb8c8")},
	"grandma": {"name": "정 할머니", "sprite": "npc_grandma.png", "color": Color("d8c0f0")},
	"officer_police": {"name": "남 경위", "sprite": "npc_officer_police.png", "color": Color("a8c0ff")},
	"police": {"name": "권 순경", "sprite": "npc_police.png", "color": Color("d8f070")},
	"officer_hospital": {"name": "조 주무관", "sprite": "npc_officer_hospital.png", "color": Color("90e0e0")},
	"doctor": {"name": "백 선생님", "sprite": "npc_doctor.png", "color": Color("e8f0ff")},
	# 주차장의 교통사고 전문 변호사 (교통 안전 캐릭터)
	"wonmuncheol": {"name": "원문철 변호사", "sprite": "npc_wonmuncheol.png", "color": Color("ffd27a")},
}
## People who stay put (MapBase never lets them wander): the team leader at the desk,
## the cafeteria cook, the inspector at the QC station. Receivers (DESTINATIONS) also stay.
const STATIONARY := ["team_leader", "cafeteria", "inspector"]
## 출입증·옷장 화면의 선택지 이름 (GameState.LOOK_KEYS). 색 항목은 이름 대신 색 견본을 보여 준다.
const LOOK_LABELS := {
	"gender": "성별", "skin": "피부색", "hair_style": "헤어", "hair_color": "머리색",
	"outfit_style": "옷", "outfit_color": "옷 색",
}
const LOOK_NAMES := {
	"gender": ["남자", "여자"],
	"hair_style": ["짧은 머리", "가르마", "단발", "긴 머리", "포니테일"],
	"outfit_style": ["정장", "치마 정장", "니트 조끼", "활동복"],
}
const SPRITE_DIR := "res://assets/sprites/placeholder/"

const PLACE_NAMES := {"office": "정부청사", "home": "우리 집"}

## 수요기관. receiver: NPC who inspects the delivery. where: how the objective names
## them. Each needs a map (SceneRouter.MAPS) that places the receiver.
const DESTINATIONS := {
	"school": {
		"name": "한빛초등학교", "receiver": "officer_school", "where": "행정실 박 실장님",
		"idle": ["한빛초 행정실이에요. 필요한 물품이 생기면 조달청에 요청한답니다."],
		"good": "꼼꼼하게 챙겨 주셨네요. 아이들이 정말 좋아하겠어요!",
		"help": "혹시 시간 괜찮으면 교실까지 옮기는 것 좀 도와주실래요?",
		"thanks": "정말 고마워요! 조달청 분들은 역시 다르네요.",
	},
	"fire": {
		"name": "한빛소방서", "receiver": "officer_fire", "where": "사무실 정 소방장님",
		"idle": ["소방 장비는 대원들 안전과 바로 이어져요.", "그래서 납품 검사도 늘 꼼꼼하게 봐요."],
		"good": "이 정도면 현장에서 믿고 쓰겠어요. 고맙습니다!",
		"help": "차고 선반까지 같이 옮겨 주실 수 있을까요?",
		"thanks": "덕분에 출동 준비가 빨라졌어요!",
	},
	"clinic": {
		"name": "한빛보건소", "receiver": "officer_clinic", "where": "접수대 앞 한 주무관님",
		"idle": ["보건소는 지역 주민의 건강을 돌보는 공공기관이에요.", "진료에 쓰는 물품이 들어오면 저희가 먼저 확인해요."],
		"good": "주민분들이 편하게 쓰시겠어요. 감사합니다!",
		"help": "창고 정리를 조금만 도와주실래요?",
		"thanks": "정말 고마워요! 오늘 진료 준비 끝!",
	},
	"center": {
		"name": "한빛동 행정복지센터", "receiver": "officer_center", "where": "민원 창구 오 주무관님",
		"idle": ["행정복지센터는 동네 주민의 민원과 복지를 맡고 있어요.", "주민분들이 매일 쓰는 물건이라 튼튼한 게 최고예요."],
		"good": "주민분들이 바로 쓰실 수 있겠어요!",
		"help": "민원실 의자 배치를 같이 해 주실래요?",
		"thanks": "고마워요! 대기실이 훨씬 넓어 보여요.",
	},
	"nursing": {
		"name": "한빛시립요양원", "receiver": "officer_nursing", "where": "사무실 문 과장님",
		"idle": ["요양원은 어르신들이 편안하게 생활하시도록 돌보는 곳이에요.", "어르신들이 매일 쓰시는 물건이라 안전이 제일이에요."],
		"good": "어르신들이 정말 좋아하시겠어요. 고맙습니다!",
		"help": "생활실까지 옮기는 것 좀 도와주실래요?",
		"thanks": "덕분에 어르신들 맞을 준비가 끝났어요!",
	},
	"police": {
		"name": "한빛경찰서", "receiver": "officer_police", "where": "민원실 남 경위님",
		"idle": ["경찰 장비는 시민 안전과 바로 이어져요.", "그래서 들어오는 물품은 꼼꼼히 확인해요."],
		"good": "현장에서 든든하게 쓰겠어요. 감사합니다!",
		"help": "장비실 선반 정리를 같이 해 주실래요?",
		"thanks": "고마워요! 순찰 준비가 훨씬 빨라졌어요.",
	},
	"hospital": {
		"name": "한빛시립병원", "receiver": "officer_hospital", "where": "원무과 조 주무관님",
		"idle": ["시립병원은 지역 주민 누구나 이용하는 공공 병원이에요.", "환자분들이 쓰는 물품이라 꼼꼼히 확인해요."],
		"good": "환자분들이 안심하고 쓰시겠어요. 고맙습니다!",
		"help": "병동까지 같이 옮겨 주실 수 있을까요?",
		"thanks": "덕분에 병동 준비가 빨리 끝났어요!",
	},
}

## People who only chat (no quest role).
const AMBIENT := {
	"senior": ["업무는 할 만해요? 팁 하나 줄게요.", "검수 기준만 넘으면 비싼 업체를 고를 필요는 없어요. 대신 운전은 조심!"],
	"vendor": ["저희 회사도 나라장터에 입찰 참가 등록을 했어요.", "좋은 제품으로 공정하게 경쟁하겠습니다!"],
	"cafeteria": ["오늘 국밥 맛있어요~ 옆의 식권 발매기에서 메뉴를 골라요.", "밥은 여기서 바로 먹고 가요. 하루 두 끼까지!"],
	"teacher": ["새 물품이 들어오는 날엔 아이들이 제일 먼저 알아요.", "검수 꼼꼼히 해 주셔서 늘 고마워요."],
	"student": ["우와, 조달청에서 왔어요?", "우리 교실 책상도 조달청이 골라 준 거예요?"],
	"firefighter": ["장비가 튼튼해야 현장에서 마음 놓고 뛰어들 수 있어요.", "소방차는 언제든 출동할 수 있게 매일 점검해요."],
	"nurse": ["진료실 물품은 주민 건강과 바로 이어져요.", "그래서 품질이 제일 중요해요!"],
	"citizen": ["번호표 뽑고 기다리면 금방 불러 줘요.", "센터 의자가 낡아서 허리가 아팠는데, 새 의자 오면 좋겠네. 허허."],
	"caregiver": ["어르신들 식사랑 산책을 함께해요.", "미끄럼 방지 매트 하나도 어르신 안전에는 정말 중요해요."],
	"grandma": ["아이고, 젊은 양반이 수고가 많네.", "새 침대가 들어오면 허리가 덜 아프려나. 허허."],
	"police": ["순찰 다녀왔어요! 오늘도 한빛동은 평화로워요.", "납품 운전할 때도 과속은 금물이에요!"],
	"doctor": ["진료 장비가 좋아야 진단도 정확해요.", "필요한 장비를 제때 받으면 환자분들께 큰 도움이 돼요."],
	"inspector": ["품질검사실 서 검사관이에요. 업체를 정했으면 납품 전에 검사대로 오세요.", "흠집, 얼룩, 금, 빠진 부분! 이 네 가지만 잘 보면 돼요."],
}

## Shown once each, by Narumi, the first time the matching moment comes up.
## Sources for every fact: docs/procurement-facts.md. Check it before editing.
const POLICY_TIPS := {
	"accepted": ["조달청은 학교·소방서·보건소 같은 공공기관이 필요한 물품·서비스·시설공사를 대신 사고 계약해요."],
	"vendor": [
		"공공기관 입찰 정보는 '나라장터' 한곳에 모여요. 등록한 업체라면 같은 조건으로 입찰할 수 있어요.",
		"실제 입찰도 가장 싼 업체부터 이행 능력을 따져서 낙찰해요. 이걸 '적격심사'라고 해요.",
	],
	"car": [
		"사실 진짜 조달에서는 업체가 물건을 직접 납품해요.",
		"조달청은 계약이 잘 지켜지는지, 품질이 괜찮은지 챙기는 역할이에요. 오늘은 현장 공부 겸 같이 가 봐요!",
	],
	"inspection": ["납품된 물품은 계약한 규격과 품질에 맞는지 검사를 거쳐요. 품질 관리가 공공조달의 신뢰를 지켜요."],
	"report": [
		"업체를 고를 때는 가격만 보지 않아요. 품질과 납품 능력까지 함께 따져야 예산을 제대로 아낄 수 있어요.",
		"조달청 청훈이 '좋은 제품을 보다 싸고, 빠르고, 바르게'예요. 오늘 한 일이 딱 그거죠!",
	],
	"qc": [
		"조달청에는 조달물자의 품질을 관리하는 조달품질원이 있어요. 2014년에 품질관리단에서 이름이 바뀌었어요.",
		"납품 전에 불량품을 걸러 내면 수요기관이 믿고 쓸 수 있어요.",
	],
	"urgent": ["재난처럼 급할 때는 입찰 공고 기간을 5일로 줄인 '긴급입찰'로 빠르게 계약하기도 해요."],
	"place_fire": ["국민 안전과 관련된 물품은 조달청이 지정한 전문검사기관이 납품 전에 검사하기도 해요."],
	"place_clinic": ["납품된 물품에 문제가 생기면 '조달품질신문고'로 하자를 신고할 수 있어요."],
	"place_center": ["나라장터는 7만 1천여 공공기관과 60만여 조달업체가 함께 쓰는 시스템이에요."],
	"place_nursing": ["공공기관은 환경표지·저탄소·우수재활용 인증을 받은 녹색제품을 의무적으로 사야 해요."],
	"place_police": ["국가 계약에서 물품 납품이 늦어지면 업체는 하루에 계약금액의 0.075%를 지체상금으로 물어요."],
	"place_hospital": ["조달청은 중소기업과 혁신 기업의 제품이 공공시장에 진출하도록 돕는 일도 해요."],
}
const GENERAL_TIPS := [
	"조달청은 공공기관이 필요한 물품과 서비스를 대신 구매하고 계약하는 기관이에요.",
	"공공기관 입찰 정보는 '나라장터' 한곳에 모여서 누구나 볼 수 있어요.",
	"조달청은 중소기업과 혁신 기업의 제품이 공공시장에 진출하도록 돕는 일도 해요.",
	"조달청은 알루미늄 같은 주요 원자재를 비축했다가 필요할 때 방출해요.",
	"친환경 제품 구매도 공공조달에서 중요하게 다루는 가치예요.",
	"공공기관은 환경표지·저탄소·우수재활용 인증을 받은 녹색제품을 의무적으로 사야 해요.",
	"조달청은 1949년 임시외자총국으로 시작해서 1961년에 조달청이 되었어요.",
	"나라장터는 2002년에 문을 연 국가종합전자조달시스템이에요.",
	"조달청 본청은 대전 정부대전청사에 있고, 전국에 지방조달청이 11곳 있어요.",
	"조달청 청훈은 '좋은 제품을 보다 싸고, 빠르고, 바르게'예요.",
	"국가 계약에서 업체는 보통 계약금액의 10% 이상을 계약보증금으로 내요. 약속을 지키겠다는 표시예요.",
	"국가 계약에서 물품 납품이 늦어지면 업체는 하루에 계약금액의 0.075%를 지체상금으로 물어요.",
	"나르미는 투명을 상징하는 황새, 달이는 영리하고 민첩한 다람쥐가 모티브예요.",
]

## 원문철 변호사 (청사 주차장): 블랙박스 퀴즈. [question, options, correct index, explanation]
## Safe-driving common sense tied to the drive minigame, not legal numbers.
const DASHCAM_QUIZ := [
	["앞에 느린 차가 가고 있어요. 어떻게 할까요?", ["감속하고 거리를 둔다", "그대로 밀어붙인다", "반대 차선으로 쌩 추월한다"], 0,
			"정답! 앞차와 거리를 두면 부딪힐 일이 없어요. 반대 차선 추월은 마주 오는 차와 부딪히기 쉬워요."],
	["급한 커브가 다가와요. 언제 속도를 줄일까요?", ["커브에 들어가기 전에 미리", "커브 한가운데서 급하게", "줄이지 않는다"], 0,
			"정답! 커브 전에 미리 줄여야 차가 밖으로 밀려나지 않아요."],
	["운전하다 졸음이 쏟아져요. 가장 좋은 방법은?", ["창문만 열고 계속 달린다", "안전한 곳에서 쉬었다 간다", "속도를 높여 빨리 도착한다"], 1,
			"정답! 졸음운전은 정말 위험해요. 컨디션이 나쁘면 밥을 먹고 쉬어서 피로부터 풀어요."],
	["도로에 공사 울타리가 보여요. 어떻게 할까요?", ["속도를 줄이고 비켜 간다", "경적을 울리며 지나간다", "울타리를 밀고 간다"], 0,
			"정답! 공사 구간에서는 천천히, 미리 차선을 바꿔요."],
]

const VENDING_ITEMS := ["coffee", "energybar"]
const TICKET_MEALS := ["gukbap", "set_meal", "curry"]  # ItemDB.MEALS, eaten on the spot
const QUICK_ORDER := ["coffee", "energybar", "gukbap", "meal"]  # gukbap / meal: old saves only
## Result text colors on the cream meal window.
const INK_GOOD := Color("2f8f4e")
const INK_BAD := Color("c0392b")
const INK_TEXT := Color("2e2636")

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


## Whether MapBase lets this NPC walk around (everyone but STATIONARY and receivers).
func npc_wanders(id: String) -> bool:
	return not STATIONARY.has(id) and receiver_place(id) == ""


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
	return place_name(destination_id())


func place_name(id: String) -> String:
	if DESTINATIONS.has(id):
		return str((DESTINATIONS[id] as Dictionary)["name"])
	return str(PLACE_NAMES.get(id, id))


## The destination whose receiver this NPC is, or "".
func receiver_place(npc_id: String) -> String:
	for place: String in DESTINATIONS:
		if str((DESTINATIONS[place] as Dictionary)["receiver"]) == npc_id:
			return place
	return ""


## Delivery truck parked in a destination's yard (for MapBase.objects()).
func parked_truck(cell: Vector2i) -> Dictionary:
	return {
		"id": "parked_truck", "cell": cell, "radius": 20.0,
		"texture": SPRITE_DIR + "car_player.png", "solid": true,
	}


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
	if DESTINATIONS.has(map):
		if step() == Step.ARRIVED and destination_id() == map:
			return "목표: %s께 납품하기" % (DESTINATIONS[map] as Dictionary)["where"]
		return "목표: 맨 아래 출구로 나가 청사로 돌아가기"
	if map == "lab":
		if step() == Step.VENDOR_CHOSEN:
			return "목표: 아래 문으로 나가 주차장 납품 차량으로 가기" if qc_done() else "목표: 검사대에서 납품 전 품질 검사하기"
		return ""
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
			if not qc_done():
				return "목표: 1층 로비 왼쪽 품질검사실에서 검사하기"
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
	if DESTINATIONS.has(map):
		if step() == Step.ARRIVED and destination_id() == map:
			return str((DESTINATIONS[map] as Dictionary)["receiver"])
		return "exit:office"
	if map == "lab":
		return "qc_station" if step() == Step.VENDOR_CHOSEN and not qc_done() else "exit:office"
	if not GameState.has_flag("intro_done"):
		return ""
	if GameState.task.is_empty():
		if GameState.has_flag("met_leader") and GameState.tasks_done_today >= DAILY_TASKS:
			return "exit:home"
		return "team_leader"
	match step():
		Step.ACCEPTED:
			return "narajangteo_pc"
		Step.VENDOR_CHOSEN:
			return "delivery_car" if qc_done() else "exit:lab"
		Step.ARRIVED:
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
	var place := receiver_place(id)
	if place != "":
		return step() == Step.ARRIVED and destination_id() == place
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


func qc_done() -> bool:
	return bool(GameState.task.get("qc_done", false))


## Vendor quality for the inspection at the destination (after the QC swap, if any).
func delivered_quality() -> int:
	var t := current_task()
	var vi := int(GameState.task.get("vendor", -1))
	if vi < 0:
		return 0
	var base: int = int(((t["vendors"] as Array)[vi] as Dictionary)["quality"])
	return int(GameState.task.get("qc_quality", base))


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
		"narumi":
			await _talk_narumi()
		"dari":
			await _talk_dari()
		"wonmuncheol":
			await _talk_wonmuncheol()
		_:
			if receiver_place(id) != "":
				await _talk_receiver(id)
			elif AMBIENT.has(id):
				await Dialogue.say(npc_name(id), AMBIENT[id])
			else:
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
			await _use_ticket_machine()
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
		"parked_truck":
			await Dialogue.say("", ["조달청 납품 차량이에요. 청사로 돌아갈 때는 맨 아래 출구로 나가요."])
		"fire_truck":
			await Dialogue.say("", ["출동 대기 중인 소방차예요. 반짝반짝 잘 닦여 있어요."])
		"ambulance":
			await Dialogue.say("", ["구급차예요. 언제든 나갈 수 있게 준비돼 있어요."])
		"number_kiosk":
			await Dialogue.say("번호표 발급기", ["딩동! 번호표가 나왔어요. [%03d번]" % GameState.rng.randi_range(1, 99), "민원 업무는 없으니까 마음만 받을게요."])
		"chalkboard":
			await Dialogue.say("", ["칠판에 '새 물품 도착하면 깨끗하게 쓰기!'라고 적혀 있어요."])
		"med_cabinet":
			await Dialogue.say("", ["약품장이 가지런히 정리돼 있어요."])
		"qc_station":
			await _use_qc_station()
		_:
			await Dialogue.say("", ["특별한 것은 없어요."])
	_busy = false


## Esc / touch B: the player's smartphone (PhoneMenu) with one app per panel.
func open_menu() -> void:
	if _busy:
		return
	_busy = true
	var phone := PhoneMenu.new()
	get_tree().root.add_child(phone)
	var obj := objective_text().replace("목표: ", "")
	var hint := "B 버튼: 닫기" if GameState.is_touch_device() else "방향키 고르기 · Space 열기 · Esc 닫기"
	var app: String = await phone.run({
		"status": "%d일차" % GameState.day, "clock": GameState.clock_text(),
		"date": "%s %s" % [GameState.rank_name(), GameState.player_name],
		"battery": GameState.FATIGUE_MAX - GameState.fatigue, "battery_label": "체력 ",
		"apps": [
			{"id": "task", "label": "업무"}, {"id": "bag", "label": "가방"}, {"id": "growth", "label": "성장"},
			{"id": "save", "label": "저장"}, {"id": "sound", "label": "소리"}, {"id": "title", "label": "타이틀"},
		],
		"note_title": "알림 · 오늘 할 일", "note": obj if obj != "" else "지금은 특별한 일이 없어요.",
		"hint": hint,
	})
	phone.queue_free()
	match app:
		"task":
			await _task_info()
		"bag":
			await _item_menu()
		"growth":
			await _growth_menu()
		"save":
			GameState.save_game()
			Dialogue.toast("저장했어요.")
		"sound":
			await _sound_menu()
		"title":
			var yes: int = await Dialogue.choose("메뉴", "타이틀로 돌아갈까요? (저장하지 않은 진행은 사라져요)", ["돌아가기", "취소"])
			if yes == 0:
				_busy = false
				SceneRouter.goto(SceneRouter.TITLE)
				return
	_busy = false


func _sound_menu() -> void:
	var names: Array = ["배경음악 + 효과음", "효과음만", "소리 끄기"]
	var options: Array = []
	for i in names.size():
		options.append(("● " if i == Sound.mode else "○ ") + str(names[i]))
	options.append("닫기")
	var c: int = await Dialogue.choose("소리 설정", "소리를 어떻게 할까요?", options)
	if c < names.size():
		Sound.set_mode(c as Sound.Mode)
		Dialogue.toast("소리: " + str(names[c]))


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
	if DESTINATIONS.has(from_map) and to_map == "office":
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
		_:
			if DESTINATIONS.has(map) and step() == Step.ARRIVED and destination_id() == map:
				Dialogue.toast("%s에 도착! %s께 가요." % [destination_name(), (DESTINATIONS[map] as Dictionary)["where"]])


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
	Sound.play("alarm")
	await Dialogue.say("", [
		"띠리리리! 알람이 울려요.",
		"오늘은 조달청 첫 출근 날! %s 씨, 일어날 시간이에요." % GameState.player_name,
	])
	if GameState.is_touch_device():
		await Dialogue.say("", ["[조작] 이동: 화면 왼쪽을 누르고 끌기 (끝까지 밀면 달리기)", "말 걸기·조사: A 버튼 / 스마트폰 메뉴: B 버튼 / 노란 버튼: 아이템", "아래쪽 메뉴 바에서 업무·가방·성장을 볼 수 있어요."])
	else:
		await Dialogue.say("", ["[조작] 이동: 방향키 또는 WASD / 달리기: Shift를 누른 채 이동", "말 걸기·조사: Space·Enter / 스마트폰 메뉴: Esc / 아이템: Q", "단축키: 업무 B / 가방 I / 성장 C / 저장 U (아래쪽 메뉴 바를 눌러도 돼요)"])
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
			"우리 조달청은 공공기관에 필요한 물건을 대신 사고 계약하는 일을 해요.",
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
		# A different place each time, so every 수요기관 comes up (not mostly the school).
		index = TaskData.pick_index(GameState.last_task_index, GameState.rng)
	GameState.last_task_index = index
	var t := TaskData.get_task(index)
	var urgent := GameState.tasks_completed > 0 and GameState.rng.randf() < URGENT_CHANCE
	var lines: Array = (t["brief"] as Array).duplicate()
	if urgent:
		lines.append("[긴급] 그리고 이건 급한 요청이에요! 보상이 1.5배예요.")
	lines.append("납품처는 %s예요. 나라장터 PC에서 업체부터 골라 주세요." % place_name(str(t.get("destination", "school"))))
	await Dialogue.say(npc_name("team_leader"), lines)
	GameState.set_task({
		"index": index, "step": Step.ACCEPTED, "vendor": -1, "cargo": 0, "grade": "",
		"urgent": urgent, "discount": -1, "discount_rolled": false, "stars": 0,
	})
	GameState.advance_clock(10)
	await _tip("accepted")
	if urgent:
		await _tip("urgent")


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
	var pc := ProcurementPC.new()
	get_tree().root.add_child(pc)
	var c: int = await pc.run(_pc_screen(t))
	pc.queue_free()
	if c < 0 or c >= vendors.size():
		return
	var chosen: Dictionary = vendors[c]
	GameState.task["vendor"] = c
	GameState.task["step"] = Step.VENDOR_CHOSEN
	GameState.set_task(GameState.task)
	GameState.advance_clock(20)
	_work_fatigue(SELECT_FATIGUE, false)  # a forced leave waits until this conversation ends
	await Dialogue.say("", ["%s 계약했어요!" % Korean.wa(str(chosen["name"])), "납품 전에 1층 로비 왼쪽 품질검사실에서 물품을 검사해요."])
	await _tip("vendor")


## 품질검사실 검사대: conveyor minigame (QcGame), then the inspector's verdict (EventWindow).
## Caught defects are swapped for good items, which raises the delivered quality.
func _use_qc_station() -> void:
	if step() != Step.VENDOR_CHOSEN:
		await Dialogue.say("검사대", ["납품 전 품질 검사를 하는 검사대예요.", "업체와 계약하면 물품을 여기서 검사해요."])
		return
	if qc_done():
		await Dialogue.say("검사대", ["검사를 마쳤어요. 이제 주차장 납품 차량으로 가요."])
		return
	var t := current_task()
	var vi := int(GameState.task["vendor"])
	var v: Dictionary = (t["vendors"] as Array)[vi]
	var base := int(v["quality"])
	var n := npc_name("inspector")
	var c: int = await Dialogue.choose(n, "%s의 %s, 검사를 시작할까요?" % [v["name"], t["item"]], ["검사 시작", "나중에"])
	if c != 0:
		return
	if not GameState.has_flag("qc_tutorial"):
		GameState.set_flag("qc_tutorial")
		var key := "A 버튼" if GameState.is_touch_device() else "Space"
		await Dialogue.say(n, [
			"컨베이어로 물품이 지나가요. 노란 검사 구역에 왔을 때 불량품이면 %s(또는 화면 터치)로 불합격!" % key,
			"흠집, 얼룩, 금, 빠진 부분이 있으면 불량이에요. 멀쩡한 물건을 고르면 오판이에요.",
			"찾아낸 불량품은 업체가 새 제품으로 바꿔 줘서 납품 품질이 올라가요.",
		])
	var defects := TaskData.qc_defects(base)
	var qc := QcGame.new()
	get_tree().root.add_child(qc)
	var r: Dictionary = await qc.run({
		"title": "품질 검사 - %s (%s)" % [t["item"], v["name"]],
		"item": SPRITE_DIR + "product_%s.png" % str(t.get("kind", "device")), "kind": str(t.get("kind", "device")),
		"items": TaskData.QC_ITEMS, "defects": defects,
		"zone": "검사 구역", "reject": "불합격!",
		"hint": "흠집·얼룩·금·빠진 부분이 있으면 불합격!",
		"found": "찾은 불량 %d/%d", "wrong": "오판 %d", "left": "남은 물품 %d개",
		"hit": "불량 발견!", "miss": "불량을 놓쳤어요", "false_alarm": "정상품이에요!", "go": "검사 시작!",
	})
	qc.queue_free()
	var caught := int(r["caught"])
	var wrong := int(r["wrong"])
	var missed := int(r["missed"])
	var final := TaskData.qc_quality(base, int(r["defects"]), caught)
	GameState.task["qc_done"] = true
	GameState.task["qc_quality"] = final
	GameState.set_task(GameState.task)
	GameState.advance_clock(30 + wrong * 5)
	_work_fatigue(QC_FATIGUE, false)
	var required := int(t["required"])
	var result: Array = [["불량 %d개 중 %d개를 찾아 새 제품으로 바꿨어요." % [int(r["defects"]), caught], INK_TEXT],
		["납품 품질 %d → %d점 (검수 기준 %d점)" % [base, final, required], INK_GOOD if final >= required else INK_BAD]]
	if missed > 0:
		result.append(["놓친 불량 %d개는 그대로 실려 가요." % missed, INK_BAD])
	if wrong > 0:
		result.append(["정상품 %d개를 잘못 골라 다시 확인했어요. (+%d분)" % [wrong, wrong * 5], INK_BAD])
	var w := EventWindow.new()
	get_tree().root.add_child(w)
	await w.run({
		"title": "%s의 검사 결과" % n, "bg": SPRITE_DIR + "event_lab.png", "mode": "inspect",
		"npc": npc_sprite("inspector"), "item": SPRITE_DIR + "product_%s.png" % str(t.get("kind", "device")),
		"defects": caught, "caption": "꼼꼼히 검사하는 중...", "bubbles": ["흠...", "여기를 보면...", "좋아요!"],
		"stamp": "합격" if final >= required else "주의", "stamp_color": INK_GOOD if final >= required else Color("d07a10"),
		"result": result, "ok": "확인했어요",
	})
	w.queue_free()
	GameState.popup.emit("품질 %d → %d" % [base, final], UiTheme.COLOR_GOOD if final > base else UiTheme.COLOR_WARN)
	await Dialogue.say(n, ["검사 끝! 이제 로비로 나가서 주차장 납품 차량으로 가요."])
	await _tip("qc")


## Everything the 나라장터 monitor window shows (ProcurementPC.run).
func _pc_screen(t: Dictionary) -> Dictionary:
	var vendors: Array = t["vendors"]
	var required := int(t["required"])
	var tags: Array = []
	if bool(t.get("fragile", false)):
		tags.append("파손 주의")
	if is_urgent():
		tags.append("긴급")
	var analysis := GameState.upgrade_level("analysis") > 0
	var rows: Array = []
	var confirms: Array = []
	for i in vendors.size():
		var v: Dictionary = vendors[i]
		var note := ""
		if analysis:
			var q := float(v["quality"])
			note = "[분석] 화물 100%%면 %s · 85%%면 %s" % [TaskData.grade(q, required), TaskData.grade(q * 0.85, required)]
		rows.append({
			"name": v["name"], "price": "%s만원" % Korean.comma(vendor_price(i)),
			"sale": int(GameState.task.get("discount", -1)) == i, "sale_label": "특가",
			"quality": int(v["quality"]), "desc": v["desc"], "note": note,
		})
		confirms.append("%s 계약할까요?\n%s만원 / 품질 %d점" % [Korean.wa(str(v["name"])), Korean.comma(vendor_price(i)), int(v["quality"])])
	return {
		"title": "나라장터", "subtitle": "국가종합전자조달시스템",
		"crumb": "입찰·계약  >  %s  >  업체 선정" % t["item"],
		"info_title": "수요기관 요청",
		"info": [
			["수요기관", destination_name()], ["품목", t["item"]],
			["배정 예산", "%s만원" % Korean.comma(int(t["budget"]))], ["검수 기준", "품질 %d점 이상" % required],
		],
		"tags": tags,
		"formula": "검수 점수 = 업체 품질 x 화물 상태\n남은 예산은 팀 예산이 돼요.",
		"list_title": "참여 업체 %d곳" % vendors.size(),
		"vendors": rows, "required": required, "quality_label": "품질 %d점",
		"footer": "가장 싼 업체부터 기준을 넘는지 따져 봐요. 실제 '적격심사'도 낮은 가격 순으로 이행 능력을 심사해요.",
		"btn_ok": "계약하기", "btn_later": "나중에",
		"confirm": confirms, "btn_yes": "계약", "btn_no": "취소",
	}


func _use_car() -> void:
	if step() != Step.VENDOR_CHOSEN and step() != Step.ARRIVED:
		await Dialogue.say("", ["조달청 납품 차량이에요. 지금은 실을 물건이 없어요."])
		return
	if step() == Step.VENDOR_CHOSEN and not qc_done():
		await Dialogue.say("", ["아직 납품 전 검사를 안 했어요.", "1층 로비 왼쪽 품질검사실 검사대에서 먼저 검사해요."])
		return
	var warn := ""
	if bool(current_task().get("fragile", false)):
		warn = " (파손 주의!)"
	var c: int = await Dialogue.choose("", "%s 납품하러 출발할까요?%s" % [Korean.ro(destination_name()), warn], ["출발!", "아직"])
	if c == 0:
		await _tip("car")
		SceneRouter.goto(SceneRouter.DRIVE)


## The destination's receiver: inspects the delivery (score = quality x cargo).
func _talk_receiver(id: String) -> void:
	var n := npc_name(id)
	var place := receiver_place(id)
	var info: Dictionary = DESTINATIONS[place]
	if step() == Step.ARRIVED and destination_id() == place:
		var t := current_task()
		var vendors: Array = t["vendors"]
		var v: Dictionary = vendors[int(GameState.task["vendor"])]
		var cargo := int(GameState.task.get("cargo", 100))
		var required := int(t["required"])
		var quality := delivered_quality()
		var score := float(quality) * cargo / 100.0
		var g := TaskData.grade(score, required)
		var reaction := str(info["good"])
		if g == "보통":
			reaction = "기준은 통과예요. 쓰는 데 문제없겠어요."
		elif g == "미흡":
			reaction = "음... 기준에 못 미쳐요. 보완이 필요하겠어요."
		var greet := "조달청에서 오셨군요! %s 맞죠?" % t["item"]
		if bool(GameState.task.get("late", false)):
			greet = "조달청에서 오셨군요! 기다리고 있었어요. %s 맞죠?" % t["item"]
		await Dialogue.say(n, [
			greet,
			"바로 검수해 볼게요...",
			"검수 결과: [%s] %d점 (품질 %d x 화물 %d%%, 기준 %d점)" % [g, roundi(score), quality, cargo, required],
			reaction,
		])
		GameState.task["grade"] = g
		GameState.task["step"] = Step.DELIVERED
		GameState.set_task(GameState.task)
		GameState.advance_clock(20)
		GameState.popup.emit("검수 " + g, _grade_color(g))
		if GameState.tasks_completed > 0 and GameState.rng.randf() < REQUEST_CHANCE:
			await _officer_request(n, info)
		await _tip("inspection")
		await _tip("place_" + place)
	elif step() == Step.DELIVERED and destination_id() == place:
		await Dialogue.say(n, ["수고하셨어요. 청사에 돌아가서 보고 잘 하세요!"])
	else:
		await Dialogue.say(n, info["idle"])


func _officer_request(n: String, info: Dictionary) -> void:
	var c: int = await Dialogue.choose(n, str(info["help"]), ["도와드릴게요 (피로 +%d, 평판 +4)" % HELP_FATIGUE, "다음 일정이 있어서요"])
	if c == 0:
		_work_fatigue(HELP_FATIGUE, true)
		GameState.add_rewards(0, 4, 0)
		GameState.log_add("rep", 4)
		GameState.advance_clock(20)
		var w := EventWindow.new()
		get_tree().root.add_child(w)
		await w.run({
			"title": "일 돕기 - %s" % info["name"], "bg": SPRITE_DIR + "event_room.png", "mode": "carry",
			"npc": npc_sprite(str(info["receiver"])), "prop": SPRITE_DIR + "box_carry.png",
			"caption": "같이 나르는 중...", "bubbles": ["영차!", "으쌰!", "하나 더!"],
			"result": [[str(info["thanks"]), INK_TEXT], ["평판 +4 / 피로 +%d" % HELP_FATIGUE, INK_GOOD]],
			"ok": "별말씀을요!",
		})
		w.queue_free()
		GameState.popup.emit("평판 +4", UiTheme.COLOR_GOOD)
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
	var late := bool(GameState.task.get("late", false))
	if late:
		rep -= LATE_REPUTATION
	var xp := roundi(int(t["exp"]) * mult)
	var bonus := roundi(TaskData.bonus_for(g) * mult)
	var lines: Array = ["보고 잘 받았어요. 검수 결과는 [%s]이군요." % g]
	if saved > 0:
		lines.append("예산도 %d만원 아꼈네요. 팀 예산으로 시설을 바꿀 수 있어요." % saved)
	if g == "미흡":
		lines.append("싼 게 항상 좋은 건 아니에요. 검수 기준을 꼭 같이 봐요.")
	elif g == "우수":
		lines.append("아주 잘했어요! 수요기관에서도 칭찬이 자자하네요.")
	if late:
		lines.append("다만 납품 기한을 넘겨서 평판이 %d 깎였어요. 다음엔 서둘러요!" % LATE_REPUTATION)
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
	GameState.popup.emit("경험치 +%d" % xp, UiTheme.COLOR_WARN)
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


## 원문철 변호사: comments on the current delivery's cargo, then a dashcam quiz.
func _talk_wonmuncheol() -> void:
	var n := npc_name("wonmuncheol")
	var lines: Array = []
	if not GameState.has_flag("met_wonmuncheol"):
		GameState.set_flag("met_wonmuncheol")
		var brake := "감속 버튼" if GameState.is_touch_device() else "↓ 키"
		lines.append_array([
			"안녕하세요, 교통사고 전문 변호사 원문철이에요. 여기 주차장에서 블랙박스 영상을 보고 있었어요.",
			"납품 운전, 무작정 밟는다고 빨리 가는 게 아니에요. 위험하면 %s로 속도를 줄여요!" % brake,
		])
	if step() >= Step.ARRIVED:
		var cargo := int(GameState.task.get("cargo", 100))
		if cargo >= 90:
			lines.append("방금 운전 블랙박스 봤어요. 화물 상태 %d%%! 이건 무과실, 아주 모범 운전이에요." % cargo)
		elif cargo >= 70:
			lines.append("방금 운전, 화물 상태 %d%%네요. 몇 번 부딪혔죠? 앞차와 거리를 두면 피할 수 있었어요." % cargo)
		else:
			lines.append("화물 상태 %d%%... 이건 제가 변호해 드리기 어렵겠는데요? 다음엔 천천히 가요." % cargo)
	if not lines.is_empty():
		await Dialogue.say(n, lines)
	var q: Array = DASHCAM_QUIZ[GameState.rng.randi() % DASHCAM_QUIZ.size()]
	var c: int = await Dialogue.choose(n, "[블랙박스 퀴즈] " + str(q[0]), q[1])
	if c == int(q[2]):
		Sound.play("star")
		await Dialogue.say(n, [str(q[3])])
	else:
		await Dialogue.say(n, ["음, 그러면 사고 나요! 블랙박스를 다시 돌려 볼까요?", str(q[3]).replace("정답! ", "")])


func _talk_dari() -> void:
	var n := npc_name("dari")
	if GameState.fatigue >= GameState.FATIGUE_BAD_AT:
		await Dialogue.say(n, ["얼굴이 피곤해 보여요! 구내식당에서 밥 한 끼 어때요?", "식당 오른쪽 구석의 식권 발매기에서 메뉴를 고르면 바로 먹을 수 있어요."])
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
	Sound.play("sleep")
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
	GameState.popup.emit("에너지 드링크 +1", UiTheme.COLOR_GOOD)
	await Dialogue.say("", ["냉장고에서 에너지 드링크를 챙겼어요!", "운전 중에 Q(부스터 버튼)로 마시면 부스터가 돼요."])


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
	if qc_done():
		lines.append("품질 검사: 완료 (납품 품질 %d점)" % delivered_quality())
	elif vi >= 0:
		lines.append("품질 검사: 아직 (1층 로비 왼쪽 품질검사실)")
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


## Cafeteria: pick a meal at the ticket machine, pay, and eat it right there
## (MealWindow shows the meal, then fatigue and condition before -> after).
func _use_ticket_machine() -> void:
	if GameState.meals_today >= ItemDB.MEALS_PER_DAY:
		await Dialogue.say("식권 발매기", ["오늘은 벌써 두 끼를 먹었어요. 배가 불러서 더는 못 먹겠어요."])
		return
	var options: Array = []
	for id: String in TICKET_MEALS:
		var m := ItemDB.get_meal(id)
		var extra := ", 컨디션 UP" if bool(m["meal_bonus"]) else ""
		options.append("%s %s원 (피로 -%d%s)" % [m["name"], Korean.comma(int(m["price"])), int(m["fatigue"]), extra])
	options.append("그만두기")
	var c: int = await Dialogue.choose("식권 발매기", "어떤 메뉴를 먹을까요? (지갑 %s원)" % Korean.comma(GameState.money), options)
	if c >= TICKET_MEALS.size():
		return
	var meal_id: String = TICKET_MEALS[c]
	var meal := ItemDB.get_meal(meal_id)
	if not GameState.spend_money(int(meal["price"])):
		Dialogue.toast("돈이 부족해요.", UiTheme.COLOR_BAD)
		return
	Sound.play("ticket")
	Dialogue.toast("%s 식권이 나왔어요!" % meal["name"])
	var r := ItemDB.eat(meal_id)
	GameState.advance_clock(30)
	var recovered := int(r["fatigue_before"]) - int(r["fatigue_after"])
	var cond_before := str(r["cond_before"])
	var cond_after := str(r["cond_after"])
	var cond_color := INK_TEXT
	if cond_after != cond_before:
		cond_color = INK_GOOD
	elif cond_after == "나쁨":
		cond_color = INK_BAD
	var result: Array = [
		[str(meal["comment"]), INK_TEXT],
		["피로 %d → %d (-%d)" % [int(r["fatigue_before"]), int(r["fatigue_after"]), recovered], INK_GOOD],
		["컨디션 %s → %s" % [cond_before, cond_after], cond_color],
	]
	if bool(meal["meal_bonus"]):
		result.append(["골고루 먹어서 오늘 하루 컨디션이 한 단계 좋아져요.", INK_GOOD])
	var w := MealWindow.new()
	get_tree().root.add_child(w)
	await w.run({
		"title": "구내식당 - %s" % meal["name"], "food": SPRITE_DIR + str(meal["food"]),
		"eating": "냠냠 먹는 중...", "bite": "냠냠!", "result": result, "ok": "잘 먹었습니다!",
	})
	w.queue_free()
	GameState.popup.emit("피로 -%d" % recovered, UiTheme.COLOR_GOOD)


func _item_menu() -> void:
	var ids: Array = []
	var options: Array = []
	for id: String in QUICK_ORDER:
		if GameState.item_count(id) > 0:
			ids.append(id)
			options.append("%s x%d" % [ItemDB.item_name(id), GameState.item_count(id)])
	if ids.is_empty():
		await Dialogue.say("가방", ["가진 아이템이 없어요. (지갑 %s원)" % Korean.comma(GameState.money), "커피와 에너지 드링크는 구내식당 자판기에서 살 수 있어요. 밥은 식권 발매기에서 골라 바로 먹어요."])
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
	Sound.play("jingle_bad")
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
	var lines: Array = (POLICY_TIPS[key] as Array).duplicate()
	lines[0] = "[조달 상식] " + str(lines[0])
	await Dialogue.say(npc_name("narumi"), lines)
