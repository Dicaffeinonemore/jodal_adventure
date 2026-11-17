class_name TaskData
## Procurement tasks (the core loop content). Tasks are handed out in order and
## loop when they run out. All P0 tasks deliver to the school map; add a map id
## to SceneRouter.MAPS before using another "destination".
##
## Money: "budget" and vendor "price" are in 만원. Choosing a cheaper vendor
## saves team budget, but low quality risks a poor inspection grade.
## vendor quality (0-100) x cargo condition after driving = inspection score.

const TASKS := [
	{
		"id": "school_desks",
		"title": "한빛초 교실 책상 30개",
		"requester": "officer_school",
		"destination": "school",
		"item": "교실 책상 30개",
		"budget": 600,
		"brief": [
			"한빛초등학교에서 교실 책상 30개를 요청했어요.",
			"나라장터 PC에서 업체를 고르고, 주차장 차로 직접 납품해 주세요.",
		],
		"vendors": [
			{"name": "튼튼가구", "price": 560, "quality": 92, "desc": "품질 인증을 받은 업체. 가격이 높다."},
			{"name": "바른공방", "price": 470, "quality": 76, "desc": "가격과 품질이 균형 잡힌 중소기업."},
			{"name": "알뜰책상", "price": 390, "quality": 52, "desc": "가장 싸지만 품질 평가가 낮다."},
		],
		"exp": 40,
	},
	{
		"id": "school_projectors",
		"title": "한빛초 교실용 빔프로젝터 5대",
		"requester": "officer_school",
		"destination": "school",
		"item": "빔프로젝터 5대",
		"budget": 450,
		"brief": [
			"이번엔 같은 학교에서 빔프로젝터 5대 요청이 들어왔어요.",
			"전자제품이라 운전할 때 특히 조심하고요.",
		],
		"vendors": [
			{"name": "밝은영상", "price": 430, "quality": 90, "desc": "A/S망이 넓은 업체. 비싸다."},
			{"name": "새빛전자", "price": 360, "quality": 72, "desc": "혁신제품으로 지정된 신생 기업 제품."},
			{"name": "싼마트", "price": 290, "quality": 45, "desc": "최저가. 고장 이력이 있다."},
		],
		"exp": 50,
	},
	{
		"id": "school_purifiers",
		"title": "한빛초 공기청정기 10대",
		"requester": "officer_school",
		"destination": "school",
		"item": "공기청정기 10대",
		"budget": 500,
		"brief": [
			"학교에 공기청정기 10대가 필요하대요.",
			"아이들이 쓰는 물건이니 품질을 꼼꼼히 봐 주세요.",
		],
		"vendors": [
			{"name": "맑은숨", "price": 480, "quality": 88, "desc": "친환경 인증 제품을 만드는 업체."},
			{"name": "푸른바람", "price": 400, "quality": 70, "desc": "무난한 품질의 중견기업."},
			{"name": "대충공조", "price": 330, "quality": 48, "desc": "싸지만 필터 품질이 들쭉날쭉하다."},
		],
		"exp": 50,
	},
]


static func get_task(index: int) -> Dictionary:
	return TASKS[index % TASKS.size()]


static func grade(score: float) -> String:
	if score >= 80.0:
		return "우수"
	if score >= 55.0:
		return "보통"
	return "미흡"


static func reputation_for(grade_name: String) -> int:
	match grade_name:
		"우수":
			return 15
		"보통":
			return 8
	return -5
