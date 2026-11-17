extends MapBase
## 수요기관: 한빛보건소. 왼쪽은 접수대와 대기실, 오른쪽은 진료실(병상·약품장).
## 앞마당에 구급차와 납품 차량(arrival). 유리문(G)으로 들어가 접수대 앞 한 주무관님께 납품한다.
## Keep every row 28 wide.

const LAYOUT := [
		"############################",
		"#WWWWWWWWWWWWW#WWWWWWWWWWWW#",
		"#PiiiiiiiiiiiS#xiixiixii++P#",
		"#i=====iiiiiii#xiixiixiiiii#",
		"#iiiiiiiiiiiii#iiiiiiiiiiii#",
		"#iFFiiFFiiiiNiiiiiiiiiiiiii#",
		"#iiiiiiiiiiiii#iiiiiiiiiOii#",
		"#PiiiiiiiiiiiP#Piiiiiiiiiii#",
		"444444GG44444444444444444444",
		"YuuuuqppquuuuuqqqqqaaaaaaaaY",
		"YqqqqqppqqqqqqqqqqqaaaaaaaaY",
		"YqqqqqpppppppppppppaaaaaaaaY",
		"YqqqqqppqqqqqqqqqqqaaaaaaaaY",
		"YYYYYYEEYYYYYYYYYYYYYYYYYYYY",
]


func map_id() -> String:
	return "clinic"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(7, 11),
		"arrival": Vector2i(17, 11),
	}


func npcs() -> Array:
	return [
		{"id": "officer_clinic", "cell": Vector2i(4, 4), "from": Vector2i(4, 5)},
		{"id": "nurse", "cell": Vector2i(19, 4)},
	]


func objects() -> Array:
	return [
		{
			"id": "ambulance", "cell": Vector2i(21, 10), "radius": 20.0,
			"texture": "res://assets/sprites/placeholder/ambulance.png", "solid": true,
		},
		Story.parked_truck(Vector2i(25, 10)),
	]


func signs() -> Array:
	return [{"text": "한빛보건소", "cell": Vector2i(3, 8)}]


func exits() -> Array:
	return [
		{"rect": Rect2i(6, 13, 2, 1), "to": "office", "spawn": "parking"},
	]
