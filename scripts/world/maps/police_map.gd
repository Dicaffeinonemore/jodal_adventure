extends MapBase
## 수요기관: 한빛경찰서. 왼쪽은 민원실(카운터 뒤 남 경위, 대기 의자, 번호표 발급기),
## 오른쪽은 사무실(사물함·책상). 앞마당 주차장에 납품 차량(arrival). Keep every row 28 wide.

const LAYOUT := [
		"############################",
		"#WWWWWWWWWWWWW#WWWWWBWWWWWW#",
		"#SS..........P#kkkk,,,,,,RP#",
		"#.===========.#,,,,,,,,,,,,#",
		"#.............#,DD,,DD,,DD,#",
		"#.FFF..FFF.....,,,,,,,,,,,,#",
		"#.........N...#,,,,,,,,,,OP#",
		"#P...........P#P,,,,,,,,,,P#",
		"77777777777GG777777777777777",
		"YuuuqqqqqqqppqqqqqqqqaaaaaaY",
		"YqqqqqqqqqqppqqqqqqqqaaaaaaY",
		"YqqqqqqqqqqpppppppppaaaaaaaY",
		"YuuqqqqqqqqppqqqqqqqqaaaaaaY",
		"YYYYYYYYYYYEEYYYYYYYYYYYYYYY",
]


func map_id() -> String:
	return "police"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(12, 11),
		"arrival": Vector2i(19, 11),
	}


func npcs() -> Array:
	return [
		# Behind the counter: talk to him across it from the waiting side.
		{"id": "officer_police", "cell": Vector2i(7, 2), "reach": 26.0, "from": Vector2i(7, 4)},
		{"id": "police", "cell": Vector2i(20, 5)},
	]


func objects() -> Array:
	return [Story.parked_truck(Vector2i(23, 10))]


func signs() -> Array:
	return [{"text": "한빛경찰서", "cell": Vector2i(19, 8)}]


func exits() -> Array:
	return [
		{"rect": Rect2i(11, 13, 2, 1), "to": "office", "spawn": "parking"},
	]
