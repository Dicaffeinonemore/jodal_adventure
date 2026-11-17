extends MapBase
## 수요기관: 한빛시립요양원. 왼쪽은 사무실(문 과장), 오른쪽은 어르신 생활실(소파·러그·침대).
## 앞마당 주차장에 납품 차량(arrival). 유리문(G)으로 사무실에 들어가 문 과장님께 납품한다.
## Keep every row 28 wide.

const LAYOUT := [
		"############################",
		"#WWWWWWWWWWBW#WWWWWWWWWWWWW#",
		"#SS,,,,,,,,RP#wwwwwwwwwwxwx#",
		"#,,,,,,,,,,,,#wwFFFwwwwwwww#",
		"#,,DD,,,DD,,,#wwwwwwwrrrrww#",
		"#,,,,,,,,,,,,,wwwwwwwrrrrww#",
		"#,,,,,,,,,,,,#wwwwwwwwwwwOw#",
		"#P,,,,,,,,,,P#PwwwwwwwwwwwP#",
		"666666GG66666666666666666666",
		"YuuuuqppquuuuuqqqqqaaaaaaaaY",
		"YqqqqqppqqqqqqqqqqqaaaaaaaaY",
		"YqqqqqpppppppppppppaaaaaaaaY",
		"YqqqqqppqqqqqqqqqqqaaaaaaaaY",
		"YYYYYYEEYYYYYYYYYYYYYYYYYYYY",
]


func map_id() -> String:
	return "nursing"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(7, 11),
		"arrival": Vector2i(17, 11),
	}


func npcs() -> Array:
	return [
		{"id": "officer_nursing", "cell": Vector2i(6, 3), "from": Vector2i(6, 4)},
		{"id": "caregiver", "cell": Vector2i(20, 6)},
		{"id": "grandma", "cell": Vector2i(17, 4)},
	]


func objects() -> Array:
	return [Story.parked_truck(Vector2i(25, 10))]


func signs() -> Array:
	return [{"text": "한빛시립요양원", "cell": Vector2i(14, 8)}]


func exits() -> Array:
	return [
		{"rect": Rect2i(6, 13, 2, 1), "to": "office", "spawn": "parking"},
	]
