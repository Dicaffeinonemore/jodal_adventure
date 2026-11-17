extends MapBase
## 수요기관: 한빛초등학교. 행정실(좌상)에서 납품·검수, 아래쪽 현관으로 나가면 청사로 복귀.

const LAYOUT := [
		"############################",
		"#WWWWWWWWWWWW#WWWWWBWWWWWWW#",
		"#SSwwwwwwwwPS#wwwwwwwwwwwww#",
		"#wwwDDDDwwwww#wDDwwDDwwDDww#",
		"#wwwwwwwwwwww#wwwwwwwwwwwww#",
		"#wwwwwwwwwwww#wDDwwDDwwDDww#",
		"#Pwwwwwwwwwww#wwwwwwwwwwwww#",
		"######ww###########www######",
		"#P........................P#",
		"#..........................#",
		"#..........................#",
		"#..........................#",
		"#..........................#",
		"#..........................#",
		"#P........................P#",
		"############EEEE############",
]


func map_id() -> String:
	return "school"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(13, 13),
		"arrival": Vector2i(13, 13),
	}


func npcs() -> Array:
	return [
		{"id": "officer_school", "cell": Vector2i(6, 4)},
	]


func exits() -> Array:
	return [
		{"rect": Rect2i(12, 15, 4, 1), "to": "office", "spawn": "parking"},
	]
