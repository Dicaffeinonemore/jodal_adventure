extends MapBase
## 수요기관: 한빛초등학교. 위쪽이 건물 안(행정실·교실·복도), 아래쪽이 앞마당.
## 납품 차량은 앞마당 주차장에 서 있고(arrival), 유리문(G)으로 들어가 행정실 박 실장님께 납품한다.
## 맨 아래 출구(E)로 나가면 청사로 복귀. Keep every row 28 wide.

const LAYOUT := [
		"############################",
		"#WWWWWWWWWWWW#WWWWWAWWWWWWW#",
		"#SSwwwwwwwwPS#wwwwwwwwwwwww#",
		"#wwwDDDDwwwww#wDDwwDDwwDDww#",
		"#wwwwwwwwwwww#wwwwwwwwwwwww#",
		"#wwwwwwwwwwww#wDDwwDDwwDDww#",
		"#Pwwwwwwwwwww#wwwwwwwwwwwww#",
		"######ww###########www######",
		"#P........................P#",
		"#..........................#",
		"#B.........................#",
		"#P........................P#",
		"1111111111111GG1111111111111",
		"YuuqqqqqqqqqqppqqqqqqqqquuuY",
		"YqqqqqqqqqqqqppqqqaaaaaaaaaY",
		"Yqqqqqqqqqqqqpppppa|aa|aaaaY",
		"YqqqqqqqqqqqqppqqqaaaaaaaaaY",
		"YYYYYYYYYYYYYEEYYYYYYYYYYYYY",
]


func map_id() -> String:
	return "school"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(14, 15),
		"arrival": Vector2i(16, 15),
	}


func npcs() -> Array:
	return [
		{"id": "officer_school", "cell": Vector2i(6, 4), "from": Vector2i(6, 5)},
		{"id": "teacher", "cell": Vector2i(20, 4)},
		{"id": "student", "cell": Vector2i(8, 14)},
	]


func objects() -> Array:
	return [Story.parked_truck(Vector2i(24, 15))]


func signs() -> Array:
	return [{"text": "한빛초등학교", "cell": Vector2i(7, 12)}]


func exits() -> Array:
	return [
		{"rect": Rect2i(13, 17, 2, 1), "to": "office", "spawn": "parking"},
	]
