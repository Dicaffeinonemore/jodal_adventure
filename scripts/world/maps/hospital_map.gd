extends MapBase
## 수요기관: 한빛시립병원. 왼쪽은 원무과(카운터 뒤 조 주무관)와 대기실, 오른쪽은 병동(병상·약품장).
## 앞마당에 구급차와 납품 차량(arrival). Keep every row 28 wide.

const LAYOUT := [
		"############################",
		"#WWWWWWWWWWWWW#WWWWWWWWWWWW#",
		"#Piiiiiiiiiiii#xiixiixiixi+#",
		"#i==========ii#xiixiixiixii#",
		"#iiiiiiiiiiiii#iiiiiiiiiiii#",
		"#iFFFiFFFiiNiiiiiiiiiiiiiii#",
		"#iiiiiiiiiiiii#iiiiiiiiiOii#",
		"#Piiiiiiiiiiii#Piiiiiiiiii+#",
		"888888GG88888888888888888888",
		"YuuuuqppquuuuuqqqqqaaaaaaaaY",
		"YqqqqqppqqqqqqqqqqqaaaaaaaaY",
		"YqqqqqpppppppppppppaaaaaaaaY",
		"YqqqqqppqqqqqqqqqqqaaaaaaaaY",
		"YYYYYYEEYYYYYYYYYYYYYYYYYYYY",
]


func map_id() -> String:
	return "hospital"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(7, 11),
		"arrival": Vector2i(17, 11),
	}


func npcs() -> Array:
	return [
		# Behind the 원무과 counter: talk across it.
		{"id": "officer_hospital", "cell": Vector2i(6, 2), "reach": 26.0, "from": Vector2i(6, 4)},
		{"id": "doctor", "cell": Vector2i(20, 4)},
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
	return [{"text": "한빛시립병원", "cell": Vector2i(14, 8)}]


func exits() -> Array:
	return [
		{"rect": Rect2i(6, 13, 2, 1), "to": "office", "spawn": "parking"},
	]
