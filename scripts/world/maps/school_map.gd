extends MapBase
## 수요기관: 한빛초등학교. 행정실(좌상)에서 납품·검수, 아래쪽 현관으로 나가면 청사로 복귀.

const LAYOUT := [
		"################################",
		"#WWWWWWWWWWWWWW#WWWWWWWBWWWWWWW#",
		"#wPwwwwwwwwwwwP#wwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwww#wwwwwwwwwwwwwww#",
		"#ww=======wwwww#wDDwwDDwwDDwwww#",
		"#wwwwwwwwwwwwww#wwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwww#wwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwww#wDDwwDDwwDDwwww#",
		"#wwwwwwwwwwwwww#wwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwww#wwwwwwwwwwwwwww#",
		"#######ww#######wwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwwwwwwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwwwwwwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwwwwwwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwwwwwwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwwwwwwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwwwwwwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwwwwwwwwwwwwwwwwwww#",
		"#wwwwwwwwwwwwwwwwwwwwwwwwwwwwww#",
		"##############EEEE##############",
]


func map_id() -> String:
	return "school"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(15, 17),
		"arrival": Vector2i(15, 17),
	}


func npcs() -> Array:
	return [
		{"id": "officer_school", "cell": Vector2i(6, 5)},
	]


func exits() -> Array:
	return [
		{"rect": Rect2i(14, 19, 4, 1), "to": "office", "spawn": "parking"},
	]


func on_map_ready() -> void:
	Story.on_arrived("school")
