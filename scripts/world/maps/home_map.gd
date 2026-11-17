extends MapBase
## 주인공의 집 (원룸). 하루가 여기서 시작하고 끝난다.
## 침대(b/n): 퇴근 후 잠자기 / 옷장(Z): 외형 바꾸기 / 냉장고(f): 하루 한 번 에너지 드링크.
## 아래쪽 현관(E)으로 나가면 청사 로비로 출근.

const LAYOUT := [
		"##################",
		"#HHHHHMHHHHHHHHHH#",
		"#bhhhhhhhhhhhZZfh#",
		"#nhhhrrrrhhhhhhhS#",
		"#hhhhrrrrhhhTThhP#",
		"#Phhhrrrrhhhhhhhh#",
		"#hhhhhhhmmhhhhhhh#",
		"########EE########",
]


func map_id() -> String:
	return "home"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(2, 3),
		"bed": Vector2i(2, 3),
		"door": Vector2i(8, 6),
		"wardrobe": Vector2i(13, 3),
	}


func exits() -> Array:
	return [
		{"rect": Rect2i(8, 7, 2, 1), "to": "office", "spawn": "entrance"},
	]
