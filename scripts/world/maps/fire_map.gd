extends MapBase
## 수요기관: 한빛소방서. 왼쪽은 소방차 차고(빨간 셔터), 오른쪽은 사무실.
## 앞마당 주차장에 납품 차량(arrival), 유리문(G)으로 사무실에 들어가 정 소방장님께 납품한다.
## Keep every row 28 wide.

const LAYOUT := [
		"############################",
		"#WWWWWWWWWWWWW#WWWWWBWWWWWW#",
		"#kkkccccccccck#SS,,,,,,,,RP#",
		"#ccccccccccccc#,,,,,,,,,,,,#",
		"#ccccccccccccc#,DD,,DD,,DD,#",
		"#ccccccccccccc#,,,,,,,,,,,,#",
		"#ccccccccccccc,,,,,,,,,,,,,#",
		"#ccccccccccccc#,,,,,,,,,,OP#",
		"22333333333332222222GG222222",
		"YcccccccccccccquqqqqppaaaaaY",
		"Ycccccccccccccqqqqqqppa|aaaY",
		"YcccccccccccccqqqqqqppaaaaaY",
		"YqqqqqqqqqqqqqqqqqqqppqqqqqY",
		"YYYYYYYYYYYYYYYYYYYYEEYYYYYY",
]


func map_id() -> String:
	return "fire"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(20, 11),
		"arrival": Vector2i(21, 11),
	}


func npcs() -> Array:
	return [
		{"id": "officer_fire", "cell": Vector2i(20, 5), "from": Vector2i(20, 6)},
		{"id": "firefighter", "cell": Vector2i(11, 5)},
	]


func objects() -> Array:
	return [
		{
			"id": "fire_truck", "cell": Vector2i(7, 4), "radius": 24.0,
			"texture": "res://assets/sprites/placeholder/firetruck.png", "solid": true,
		},
		Story.parked_truck(Vector2i(24, 10)),
	]


func signs() -> Array:
	return [{"text": "한빛소방서", "cell": Vector2i(7, 8)}]


func exits() -> Array:
	return [
		{"rect": Rect2i(20, 13, 2, 1), "to": "office", "spawn": "parking"},
	]
