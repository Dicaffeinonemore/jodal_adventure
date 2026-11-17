extends MapBase
## 정부청사: 사무실(좌상), 구내식당(우상), 로비(좌하), 주차장(우하).
## 1층 현관(E)으로 나가면 퇴근(하루 업무를 다 마쳤을 때만). 로비 왼쪽 벽 문(E) -> 품질검사실.
## Keep every row 40 wide.

const LAYOUT := [
		"########################################",
		"#WWWWWWWBWWWWWWWWWWWWWW#WWWWWWWWWWWWWWW#",
		"#SSPSS,,,,,,DDD,,,,,ROP#.=====......KV.#",
		"#,,,,,,,,,,,,,,,,,,,,,,#...............#",
		"#,,,,,,,,,,,,,,,,,,,,,,#..T..T..T..T...#",
		"#,,,,,,,,,,,,,,,,,,,,,,#...............#",
		"#,,DDD,,,,,,DCD,,,,DDD,#...............#",
		"#,,,,,,,,,,,,,,,,,,,,,,...T..T..T..T...#",
		"#,,,,,,,,,,,,,,,,,,,,,,................#",
		"#,,DDD,,,,,,DDD,,,,DDD,#...............#",
		"#,,,,,,,,,,,,,,,,,,,,,,#..T..T..T..T...#",
		"#P,,,,,,,,,,,,,,,,,,,,P#P.............P#",
		"#####M#####..####B############..########",
		"#......................#aaaaaaaaaaaaaaa#",
		"#FFF.............P.....#aa|aa|aa|aa|aaa#",
		"#.........=====........#aa|aa|aa|aa|aaa#",
		"E.......................aa|aa|aa|aa|aaa#",
		"E........rrrrrr.........aaaaaaaaaaaaaaa#",
		"#P.......rrrrrr.........aaaaaaaaaaaaaaa#",
		"#........rrrrrr.......P#aaaaaaaaaaaaaaa#",
		"#......................#aaaaaaaaaaaaaaa#",
		"#P....................P#ggggggggggggggg#",
		"#......................#ggggggggggggggg#",
		"###########EE###########################",
]


func map_id() -> String:
	return "office"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(11, 21),
		"entrance": Vector2i(11, 21),
		"parking": Vector2i(31, 20),
		"office_door": Vector2i(11, 13),
		"lab_door": Vector2i(2, 16),
	}


func npcs() -> Array:
	var list: Array = [
		{"id": "dari", "cell": Vector2i(14, 20)},
		{"id": "narumi", "cell": Vector2i(16, 7)},
		{"id": "team_leader", "cell": Vector2i(13, 3)},
	]
	# P1 NPCs
	list.append({"id": "senior", "cell": Vector2i(6, 7)})
	list.append({"id": "vendor", "cell": Vector2i(5, 15)})
	list.append({"id": "cafeteria", "cell": Vector2i(27, 3)})
	return list


func objects() -> Array:
	return [
		{
			"id": "delivery_car", "cell": Vector2i(31, 18), "radius": 22.0,
			"texture": "res://assets/sprites/placeholder/car_player.png", "solid": true,
		},
	]


func exits() -> Array:
	return [
		{"rect": Rect2i(11, 23, 2, 1), "to": "home", "spawn": "door"},
		{"rect": Rect2i(0, 16, 1, 2), "to": "lab", "spawn": "default"},
	]


func signs() -> Array:
	return [{"text": "← 품질검사실", "cell": Vector2i(3, 15)}]
