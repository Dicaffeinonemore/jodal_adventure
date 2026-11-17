class_name TaskData
## Procurement tasks (the core loop content) and facility upgrades.
## The first task is always TASKS[0] (tutorial); after that a random task is
## picked: first a destination (never the previous one, so every place comes up),
## then one of its tasks (pick_index). "destination" is a key of Story.DESTINATIONS
## (school, fire, clinic, center, nursing, police, hospital) with a map in SceneRouter.MAPS.
##
## Money: "budget" and vendor "price" are in 만원. The unspent budget goes to the
## team budget, which buys upgrades.
## Inspection score = vendor quality x cargo condition (0-100 after driving).
##   score >= required + GOOD_MARGIN -> 우수, >= required -> 보통, below -> 미흡.
## So the best pick is usually the cheapest vendor that still clears "required"
## with the cargo condition you expect to keep. "fragile" cargo takes 1.5x damage.
## Before driving, the quality inspection (QcGame) can raise the vendor quality:
## every defect caught is swapped for a good item (qc_quality()).
## "kind" picks the product picture on the inspection belt: furniture, device, soft, metal.

const GOOD_MARGIN := 15.0
const QC_ITEMS := 10  # goods on the inspection belt
const QC_REPLACE_GAIN := 0.35  # share of the missing quality won back if every defect is caught

const TASKS := [
	{
		"id": "school_desks",
		"kind": "furniture",
		"destination": "school",
		"item": "교실 책상 30개",
		"budget": 600,
		"required": 60,
		"fragile": false,
		"brief": [
			"한빛초등학교에서 교실 책상 30개를 요청했어요.",
			"검수 기준은 품질 60점 이상이에요. 기준만 넘으면 예산을 아낄수록 좋아요.",
		],
		"vendors": [
			{"name": "튼튼가구", "price": 560, "quality": 92, "desc": "품질 인증을 받은 업체. 가격이 높다."},
			{"name": "바른공방", "price": 470, "quality": 78, "desc": "가격과 품질이 균형 잡힌 중소기업."},
			{"name": "알뜰책상", "price": 390, "quality": 52, "desc": "가장 싸지만 품질 평가가 낮다."},
		],
		"exp": 40,
	},
	{
		"id": "school_projectors",
		"kind": "device",
		"destination": "school",
		"item": "빔프로젝터 5대",
		"budget": 450,
		"required": 70,
		"fragile": true,
		"brief": [
			"한빛초에서 교실용 빔프로젝터 5대 요청이 들어왔어요.",
			"전자제품이라 파손 주의예요. 부딪히면 화물이 1.5배로 상해요.",
		],
		"vendors": [
			{"name": "밝은영상", "price": 430, "quality": 92, "desc": "A/S망이 넓은 업체. 비싸다."},
			{"name": "새빛전자", "price": 360, "quality": 82, "desc": "가성비가 좋은 신생 기업 제품."},
			{"name": "싼마트", "price": 290, "quality": 50, "desc": "최저가. 고장 이력이 있다."},
		],
		"exp": 50,
	},
	{
		"id": "school_purifiers",
		"kind": "device",
		"destination": "school",
		"item": "공기청정기 10대",
		"budget": 500,
		"required": 65,
		"fragile": false,
		"brief": [
			"학교에 공기청정기 10대가 필요하대요.",
			"아이들이 쓰는 물건이라 품질 65점 이상이어야 해요.",
		],
		"vendors": [
			{"name": "맑은숨", "price": 480, "quality": 90, "desc": "친환경 인증 제품을 만드는 업체."},
			{"name": "푸른바람", "price": 400, "quality": 77, "desc": "무난한 품질의 중견기업."},
			{"name": "대충공조", "price": 330, "quality": 56, "desc": "싸지만 필터 품질이 들쭉날쭉하다."},
		],
		"exp": 50,
	},
	{
		"id": "school_mats",
		"kind": "soft",
		"destination": "school",
		"item": "체육 매트 20장",
		"budget": 300,
		"required": 45,
		"fragile": false,
		"brief": [
			"체육관에서 쓸 매트 20장이 필요하대요.",
			"기준은 품질 45점으로 낮은 편이에요. 너무 비싼 걸 살 필요는 없겠죠?",
		],
		"vendors": [
			{"name": "든든스포츠", "price": 290, "quality": 88, "desc": "프로 선수용 매트도 만드는 업체."},
			{"name": "말랑매트", "price": 220, "quality": 70, "desc": "학교 납품 경험이 많은 업체."},
			{"name": "반값매트", "price": 160, "quality": 60, "desc": "단순한 제품이지만 튼튼하다는 평."},
		],
		"exp": 40,
	},
	{
		"id": "school_shelves",
		"kind": "furniture",
		"destination": "school",
		"item": "도서관 책장 8개",
		"budget": 400,
		"required": 55,
		"fragile": false,
		"brief": [
			"도서관 책장 8개 요청이에요.",
			"검수 기준은 품질 55점 이상이에요.",
		],
		"vendors": [
			{"name": "나무향", "price": 380, "quality": 88, "desc": "원목 가구 전문 업체."},
			{"name": "책사랑", "price": 300, "quality": 70, "desc": "도서관 가구를 주로 만드는 중소기업."},
			{"name": "막조립", "price": 240, "quality": 50, "desc": "싸지만 조립 불량 이야기가 있다."},
		],
		"exp": 45,
	},
	{
		"id": "school_microscopes",
		"kind": "device",
		"destination": "school",
		"item": "과학실 현미경 15대",
		"budget": 700,
		"required": 75,
		"fragile": true,
		"brief": [
			"과학실 현미경 15대가 필요하대요. 기준이 75점으로 높아요.",
			"정밀 기기라 파손 주의예요. 운전 실력에 자신 있으면 중간 업체도 괜찮아요.",
		],
		"vendors": [
			{"name": "정밀광학", "price": 680, "quality": 96, "desc": "연구소에도 납품하는 업체. 아주 비싸다."},
			{"name": "렌즈마을", "price": 560, "quality": 86, "desc": "교육용 현미경을 주로 만든다."},
			{"name": "대충렌즈", "price": 420, "quality": 62, "desc": "싸지만 렌즈 품질이 고르지 않다."},
		],
		"exp": 60,
	},
	{
		"id": "school_trays",
		"kind": "metal",
		"destination": "school",
		"item": "급식실 식판 300개",
		"budget": 250,
		"required": 50,
		"fragile": false,
		"brief": [
			"급식실 식판 300개 요청이 들어왔어요.",
			"기준은 품질 50점 이상이에요.",
		],
		"vendors": [
			{"name": "반짝주방", "price": 240, "quality": 90, "desc": "위생 관리가 철저한 주방용품 업체."},
			{"name": "스텐마을", "price": 190, "quality": 72, "desc": "스테인리스 제품을 오래 만든 업체."},
			{"name": "그냥식판", "price": 140, "quality": 48, "desc": "가장 싸지만 마감이 거칠다."},
		],
		"exp": 40,
	},
	# ---- 한빛소방서
	{
		"id": "fire_suits",
		"kind": "soft",
		"destination": "fire",
		"item": "방화복 20벌",
		"budget": 800,
		"required": 70,
		"fragile": false,
		"brief": [
			"한빛소방서에서 방화복 20벌을 요청했어요.",
			"대원들 안전이 걸린 장비라 검수 기준이 품질 70점 이상이에요.",
		],
		"vendors": [
			{"name": "불꽃안전", "price": 780, "quality": 94, "desc": "소방 장비만 30년 만든 업체. 비싸다."},
			{"name": "든든방호", "price": 640, "quality": 82, "desc": "납품 실적이 꾸준한 중소기업."},
			{"name": "값싼장비", "price": 520, "quality": 58, "desc": "가장 싸지만 내열 시험 점수가 낮다."},
		],
		"exp": 55,
	},
	{
		"id": "fire_breathing",
		"kind": "device",
		"destination": "fire",
		"item": "공기호흡기 10세트",
		"budget": 900,
		"required": 75,
		"fragile": true,
		"brief": [
			"소방서 공기호흡기 10세트 요청이에요. 기준이 75점으로 높아요.",
			"정밀 장비라 파손 주의예요. 중간 업체를 고르면 운전을 아주 잘해야 해요.",
		],
		"vendors": [
			{"name": "숨결테크", "price": 880, "quality": 97, "desc": "해외 인증까지 받은 업체. 아주 비싸다."},
			{"name": "안심호흡", "price": 720, "quality": 88, "desc": "국내 소방서 납품 경험이 많은 업체."},
			{"name": "대충산소", "price": 560, "quality": 64, "desc": "싸지만 밸브 불량 신고가 있다."},
		],
		"exp": 65,
	},
	# ---- 한빛보건소
	{
		"id": "clinic_wheelchairs",
		"kind": "metal",
		"destination": "clinic",
		"item": "휠체어 15대",
		"budget": 450,
		"required": 60,
		"fragile": false,
		"brief": [
			"한빛보건소에서 휠체어 15대를 요청했어요.",
			"어르신들이 타실 거라 품질 60점 이상이어야 해요.",
		],
		"vendors": [
			{"name": "편안모빌", "price": 440, "quality": 92, "desc": "병원 납품을 주로 하는 업체. 비싸다."},
			{"name": "바퀴나라", "price": 350, "quality": 76, "desc": "가볍고 튼튼하다는 평이 많은 중소기업."},
			{"name": "삐걱휠", "price": 260, "quality": 50, "desc": "가장 싸지만 바퀴가 자주 빠진다는 소문."},
		],
		"exp": 45,
	},
	{
		"id": "clinic_thermometers",
		"kind": "device",
		"destination": "clinic",
		"item": "전자 체온계 100개",
		"budget": 200,
		"required": 70,
		"fragile": true,
		"brief": [
			"보건소 전자 체온계 100개 요청이에요. 기준은 품질 70점 이상.",
			"작은 전자기기라 파손 주의예요!",
		],
		"vendors": [
			{"name": "정확메디", "price": 190, "quality": 95, "desc": "의료기기 인증을 받은 업체."},
			{"name": "온도쟁이", "price": 150, "quality": 85, "desc": "가성비 좋은 신생 기업 제품."},
			{"name": "깜빡체온", "price": 100, "quality": 60, "desc": "싸지만 측정값이 들쭉날쭉하다."},
		],
		"exp": 45,
	},
	# ---- 한빛동 행정복지센터
	{
		"id": "center_chairs",
		"kind": "furniture",
		"destination": "center",
		"item": "민원실 대기 의자 40개",
		"budget": 300,
		"required": 45,
		"fragile": false,
		"brief": [
			"한빛동 행정복지센터에서 민원실 대기 의자 40개를 요청했어요.",
			"기준은 품질 45점으로 낮은 편이에요. 예산을 아낄 기회죠!",
		],
		"vendors": [
			{"name": "푹신가구", "price": 290, "quality": 88, "desc": "호텔 로비 의자도 만드는 업체."},
			{"name": "앉아봐", "price": 220, "quality": 70, "desc": "관공서 납품 경험이 많은 업체."},
			{"name": "딱딱의자", "price": 150, "quality": 52, "desc": "단순하지만 쓸 만하다는 평."},
		],
		"exp": 40,
	},
	{
		"id": "center_generators",
		"kind": "device",
		"destination": "center",
		"item": "비상 발전기 2대",
		"budget": 600,
		"required": 65,
		"fragile": true,
		"brief": [
			"행정복지센터에서 정전에 대비할 비상 발전기 2대를 요청했어요.",
			"기계 장비라 파손 주의, 기준은 품질 65점 이상이에요.",
		],
		"vendors": [
			{"name": "튼튼파워", "price": 590, "quality": 93, "desc": "공장용 발전기도 만드는 업체. 비싸다."},
			{"name": "동네전기", "price": 470, "quality": 81, "desc": "A/S가 빠른 지역 중소기업."},
			{"name": "반짝발전", "price": 360, "quality": 58, "desc": "싸지만 소음과 고장이 잦다는 평."},
		],
		"exp": 50,
	},
	# ---- 한빛시립요양원
	{
		"id": "nursing_beds",
		"kind": "furniture",
		"destination": "nursing",
		"item": "전동 침대 10대",
		"budget": 900,
		"required": 70,
		"fragile": false,
		"brief": [
			"한빛시립요양원에서 어르신용 전동 침대 10대를 요청했어요.",
			"매일 쓰시는 침대라 검수 기준이 품질 70점 이상이에요.",
		],
		"vendors": [
			{"name": "편안잠", "price": 880, "quality": 94, "desc": "병원 침대도 만드는 업체. 비싸다."},
			{"name": "늘봄가구", "price": 720, "quality": 82, "desc": "요양시설 납품 경험이 많은 중소기업."},
			{"name": "대충침대", "price": 560, "quality": 58, "desc": "가장 싸지만 모터 고장 이야기가 있다."},
		],
		"exp": 55,
	},
	{
		"id": "nursing_mats",
		"kind": "soft",
		"destination": "nursing",
		"item": "미끄럼 방지 매트 50장",
		"budget": 250,
		"required": 50,
		"fragile": false,
		"brief": [
			"요양원 복도와 욕실에 깔 미끄럼 방지 매트 50장 요청이에요.",
			"기준은 품질 50점이에요. 너무 비싼 걸 살 필요는 없겠죠?",
		],
		"vendors": [
			{"name": "안심바닥", "price": 240, "quality": 90, "desc": "병원 바닥재 전문 업체."},
			{"name": "폭신매트", "price": 180, "quality": 72, "desc": "무난한 품질의 중견기업."},
			{"name": "얇은매트", "price": 130, "quality": 56, "desc": "가장 싸지만 얇다는 평이 있다."},
		],
		"exp": 40,
	},
	{
		"id": "nursing_chairs",
		"kind": "furniture",
		"destination": "nursing",
		"item": "식당 의자 30개",
		"budget": 400,
		"required": 55,
		"fragile": false,
		"brief": [
			"요양원 식당에서 쓸 의자 30개가 필요하대요.",
			"팔걸이가 튼튼해야 해요. 검수 기준은 품질 55점 이상이에요.",
		],
		"vendors": [
			{"name": "튼튼원목", "price": 380, "quality": 90, "desc": "원목 가구 전문 업체."},
			{"name": "다정가구", "price": 300, "quality": 74, "desc": "복지시설 가구를 주로 만드는 업체."},
			{"name": "삐걱의자", "price": 220, "quality": 50, "desc": "싸지만 다리가 흔들린다는 소문."},
		],
		"exp": 45,
	},
	# ---- 한빛경찰서
	{
		"id": "police_vests",
		"kind": "soft",
		"destination": "police",
		"item": "방검복 30벌",
		"budget": 900,
		"required": 75,
		"fragile": false,
		"brief": [
			"한빛경찰서에서 방검복 30벌을 요청했어요.",
			"경찰관 안전이 걸린 장비라 검수 기준이 품질 75점으로 높아요.",
		],
		"vendors": [
			{"name": "철벽방호", "price": 880, "quality": 96, "desc": "보호 장비만 만드는 업체. 아주 비싸다."},
			{"name": "든든안전", "price": 740, "quality": 86, "desc": "공공기관 납품 실적이 꾸준한 업체."},
			{"name": "얇은조끼", "price": 560, "quality": 62, "desc": "가장 싸지만 시험 점수가 낮다."},
		],
		"exp": 60,
	},
	{
		"id": "police_cameras",
		"kind": "device",
		"destination": "police",
		"item": "순찰차 블랙박스 20대",
		"budget": 400,
		"required": 65,
		"fragile": true,
		"brief": [
			"순찰차에 달 블랙박스 20대 요청이에요.",
			"전자기기라 파손 주의, 검수 기준은 품질 65점 이상이에요.",
		],
		"vendors": [
			{"name": "선명영상", "price": 390, "quality": 92, "desc": "야간 화질이 좋기로 유명한 업체."},
			{"name": "또렷캠", "price": 320, "quality": 80, "desc": "가성비 좋은 신생 기업 제품."},
			{"name": "흐릿캠", "price": 240, "quality": 55, "desc": "싸지만 화질이 흐릿하다는 평."},
		],
		"exp": 50,
	},
	{
		"id": "police_cones",
		"kind": "metal",
		"destination": "police",
		"item": "교통 안전 고깔 200개",
		"budget": 200,
		"required": 45,
		"fragile": false,
		"brief": [
			"교통 정리에 쓸 안전 고깔 200개가 필요하대요.",
			"기준은 품질 45점으로 낮은 편이에요. 예산을 아낄 기회죠!",
		],
		"vendors": [
			{"name": "단단안전", "price": 190, "quality": 88, "desc": "반사띠가 오래가는 업체."},
			{"name": "주황산업", "price": 150, "quality": 70, "desc": "도로 공사 현장 납품이 많은 업체."},
			{"name": "대충고깔", "price": 100, "quality": 52, "desc": "가장 싸지만 쓸 만하다는 평."},
		],
		"exp": 40,
	},
	# ---- 한빛시립병원
	{
		"id": "hospital_beds",
		"kind": "furniture",
		"destination": "hospital",
		"item": "병동 침대 12대",
		"budget": 960,
		"required": 70,
		"fragile": false,
		"brief": [
			"한빛시립병원에서 병동 침대 12대를 요청했어요.",
			"환자분들이 쓰실 거라 검수 기준은 품질 70점 이상이에요.",
		],
		"vendors": [
			{"name": "메디베드", "price": 940, "quality": 95, "desc": "대학병원에도 납품하는 업체. 비싸다."},
			{"name": "쾌유가구", "price": 780, "quality": 84, "desc": "공공병원 납품 경험이 많은 업체."},
			{"name": "반값침대", "price": 600, "quality": 60, "desc": "가장 싸지만 바퀴 잠금이 약하다."},
		],
		"exp": 55,
	},
	{
		"id": "hospital_monitors",
		"kind": "device",
		"destination": "hospital",
		"item": "환자 감시 장치 6대",
		"budget": 1200,
		"required": 80,
		"fragile": true,
		"brief": [
			"병원 중환자실에 쓸 환자 감시 장치 6대 요청이에요. 기준이 80점으로 아주 높아요.",
			"정밀 의료기기라 파손 주의예요. 품질 검사와 운전 둘 다 중요해요!",
		],
		"vendors": [
			{"name": "생명테크", "price": 1180, "quality": 97, "desc": "의료기기 인증을 여럿 받은 업체. 아주 비싸다."},
			{"name": "바이탈메디", "price": 980, "quality": 90, "desc": "국내 병원 납품 실적이 많은 업체."},
			{"name": "깜빡모니터", "price": 760, "quality": 66, "desc": "싸지만 화면이 자주 꺼진다는 신고."},
		],
		"exp": 70,
	},
	{
		"id": "hospital_gowns",
		"kind": "soft",
		"destination": "hospital",
		"item": "환자복 200벌",
		"budget": 300,
		"required": 50,
		"fragile": false,
		"brief": [
			"병원에서 환자복 200벌이 필요하대요.",
			"기준은 품질 50점 이상이에요.",
		],
		"vendors": [
			{"name": "포근의류", "price": 290, "quality": 90, "desc": "의료용 섬유 전문 업체."},
			{"name": "깨끗봉제", "price": 220, "quality": 74, "desc": "병원 세탁에도 튼튼하다는 평."},
			{"name": "얇은옷감", "price": 160, "quality": 54, "desc": "가장 싸지만 금방 해진다는 소문."},
		],
		"exp": 40,
	},
	# ---- 11/18 추가 (뒤에만 추가: 저장 파일의 업무 번호가 바뀌지 않게)
	{
		"id": "fire_hoses",
		"kind": "metal",
		"destination": "fire",
		"item": "소방 호스 30본",
		"budget": 500,
		"required": 60,
		"fragile": false,
		"brief": [
			"한빛소방서에서 소방 호스 30본을 요청했어요.",
			"물이 새면 큰일이라 검수 기준은 품질 60점 이상이에요.",
		],
		"vendors": [
			{"name": "강철호스", "price": 480, "quality": 92, "desc": "압력 시험을 통과한 업체. 비싸다."},
			{"name": "물길산업", "price": 400, "quality": 78, "desc": "소방서 납품 실적이 많은 중소기업."},
			{"name": "새는호스", "price": 300, "quality": 52, "desc": "가장 싸지만 이음새 불량 신고가 있다."},
		],
		"exp": 50,
	},
]

## Facility upgrades bought with the team budget (만원). "costs" has one entry per level.
const UPGRADES := [
	{
		"id": "truck",
		"name": "납품 차량 정비",
		"desc": "부딪혔을 때 화물 피해가 레벨마다 20% 줄어요.",
		"costs": [120, 250, 400],
	},
	{
		"id": "lounge",
		"name": "휴게실 소파",
		"desc": "업무로 쌓이는 피로가 레벨마다 15% 줄어요.",
		"costs": [100, 200, 350],
	},
	{
		"id": "analysis",
		"name": "업체 분석 노트",
		"desc": "나라장터 PC에서 업체별 예상 검수 등급을 보여 줘요.",
		"costs": [150],
	},
]


static func get_task(index: int) -> Dictionary:
	return TASKS[posmod(index, TASKS.size())]


## Destinations that have tasks, in TASKS order.
static func destinations() -> Array:
	var out: Array = []
	for t: Dictionary in TASKS:
		var d := str(t["destination"])
		if not out.has(d):
			out.append(d)
	return out


## Next task after `last` (a TASKS index, -1 = none): a random destination other than
## the last task's, then a random task there. Schools no longer dominate (7 of 23 tasks).
static func pick_index(last: int, rng: RandomNumberGenerator) -> int:
	var places := destinations()
	if last >= 0 and places.size() > 1:
		places.erase(str(get_task(last)["destination"]))
	var place: String = places[rng.randi() % places.size()]
	var options: Array = []
	for i in TASKS.size():
		if str((TASKS[i] as Dictionary)["destination"]) == place:
			options.append(i)
	return int(options[rng.randi() % options.size()])


static func grade(score: float, required: float) -> String:
	if score >= required + GOOD_MARGIN:
		return "우수"
	if score >= required:
		return "보통"
	return "미흡"


## Defective items in a vendor's batch of QC_ITEMS (lower quality, more defects).
static func qc_defects(quality: int) -> int:
	return clampi(roundi((100 - quality) / 12.0), 1, 5)


## Vendor quality after the inspection: caught defects are replaced.
static func qc_quality(quality: int, defects: int, caught: int) -> int:
	if defects <= 0:
		return quality
	return mini(100, roundi(quality + (100 - quality) * QC_REPLACE_GAIN * caught / float(defects)))


static func reputation_for(grade_name: String) -> int:
	match grade_name:
		"우수":
			return 12
		"보통":
			return 6
	return -8


## Personal bonus (원) paid with each report.
static func bonus_for(grade_name: String) -> int:
	match grade_name:
		"우수":
			return 3000
		"보통":
			return 1000
	return 0


static func get_upgrade(id: String) -> Dictionary:
	for u: Dictionary in UPGRADES:
		if str(u["id"]) == id:
			return u
	return {}
