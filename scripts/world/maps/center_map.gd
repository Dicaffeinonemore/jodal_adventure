extends MapBase
## 수요기관: 한빛동 행정복지센터. 민원 창구(카운터 뒤 오 주무관), 대기 의자, 번호표 발급기(N).
## 앞마당 주차장에 납품 차량(arrival). Keep every row 28 wide.

const LAYOUT := [
		"############################",
		"#WWWWWWWWWBWWWWWWWWWWWWWWWW#",
		"#SS....................ROPS#",
		"#..==========....DD..DD....#",
		"#..........................#",
		"#.FFF.FFF.FFF.......rrrr...#",
		"#.........N.........rrrr...#",
		"#P........................P#",
		"55555555555GG555555555555555",
		"YuuuqqqqqqqppqqqqqqqqaaaaaaY",
		"YqqqqqqqqqqppqqqqqqqqaaaaaaY",
		"YqqqqqqqqqqpppppppppaaaaaaaY",
		"YuuqqqqqqqqppqqqqqqqqaaaaaaY",
		"YYYYYYYYYYYEEYYYYYYYYYYYYYYY",
]


func map_id() -> String:
	return "center"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(12, 11),
		"arrival": Vector2i(19, 11),
	}


func npcs() -> Array:
	return [
		# Behind the counter: talk to her across it from the waiting side.
		{"id": "officer_center", "cell": Vector2i(7, 2), "reach": 26.0, "from": Vector2i(7, 4)},
		{"id": "citizen", "cell": Vector2i(6, 6)},
	]


func objects() -> Array:
	return [Story.parked_truck(Vector2i(23, 10))]


func signs() -> Array:
	return [{"text": "한빛동 행정복지센터", "cell": Vector2i(19, 8)}]


func exits() -> Array:
	return [
		{"rect": Rect2i(11, 13, 2, 1), "to": "office", "spawn": "parking"},
	]
