extends MapBase
## 품질검사실 (청사 1층 로비 왼쪽 문). 업체를 고른 뒤 납품 전에 검사대(J)에서 품질 검사를 한다.
## 컨베이어(v)와 서 검사관. 아래 문으로 나가면 로비. Keep every row 18 wide (small room: shown at 2x).

const LAYOUT := [
		"##################",
		"#WWWWWWWWBWWWWWWW#",
		"#SSiiiiiiiiiiiiPS#",
		"#iivvvvvJvvvvvvii#",
		"#iiiiiiiiiiiiiiii#",
		"#iPiiiiiiiiiiiiPi#",
		"#iiiiiiiiiiiiiiii#",
		"########EE########",
]


func map_id() -> String:
	return "lab"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {"default": Vector2i(8, 6)}


func npcs() -> Array:
	return [{"id": "inspector", "cell": Vector2i(11, 4)}]


func exits() -> Array:
	return [{"rect": Rect2i(8, 7, 2, 1), "to": "office", "spawn": "lab_door"}]
