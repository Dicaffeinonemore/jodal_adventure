extends MapBase
## 정부청사: 사무실(좌상), 구내식당(우상), 로비(하단), 주차장(우하).
## Edit the layout freely; keep every row the same length (52).

const LAYOUT := [
		"####################################################",
		"#WWWWWWWWWWWWWWWWWWWBWWWWWWW#WWWWWWWWWWWWWWWWWWWWWW#",
		"#P,,,,,,,,,,,,,,,,,,,,,,,,,P#.....................V#",
		"#,,,,,,,,,,,DDD,,,,,,,,,,,,,#..======.K............#",
		"#,,,,,,,,,,,,,,,,,,,,,,,,,,,#......................#",
		"#,,,,,,,,,,,,,,,,,,,,,,,,,,,#......................#",
		"#,,DDD,,DDD,,,,,,DDD,,DDD,,,#...DD...DD...DD...DD..#",
		"#,,,,,,,,,,,,,,,,,,,,,,,,,,,#......................#",
		"#,,,,,,,,,,,,,,,,,,,,,,,,,,,#......................#",
		"#,,DDD,,DCD,,,,,,DDD,,DDD,,,#...DD...DD...DD...DD..#",
		"#,,,,,,,,,,,,,,,,,,,,,,,,,,,#......................#",
		"#P,,,,,,,,,,,,,,,,,,,,,,,,,P#......................#",
		"#############..########################..###########",
		"#..................................................#",
		"#P...............................P.................#",
		"#.................................#aaaaaaaaaaaaaaaa#",
		"#.................................#aaaaaaaaaaaaaaaa#",
		"#.................................#aaa|aaa|aaa|aaaa#",
		"#............=====................#aaa|aaa|aaa|aaaa#",
		"#.................................#aaa|aaa|aaa|aaaa#",
		"M.................................#aaa|aaa|aaa|aaaa#",
		"#.................................#aaa|aaa|aaa|aaaa#",
		"#.................................#aaa|aaa|aaa|aaaa#",
		"#.................................#aaaaaaaaaaaaaaaa#",
		"#.................................#aaaaaaaaaaaaaaaa#",
		"#.................................#aaaaaaaaaaaaaaaa#",
		"#.................................#aaaaaaaaaaaaaaaa#",
		"#.................................#gggggggggggggggg#",
		"#P.............EEE...............P#gggggggggggggggg#",
		"####################################################",
]


func map_id() -> String:
	return "office"


func layout() -> PackedStringArray:
	return PackedStringArray(LAYOUT)


func spawns() -> Dictionary:
	return {
		"default": Vector2i(16, 27),
		"entrance": Vector2i(16, 27),
		"parking": Vector2i(40, 24),
		"office_door": Vector2i(13, 13),
	}


func npcs() -> Array:
	var list: Array = [
		{"id": "dari", "cell": Vector2i(18, 26)},
		{"id": "narumi", "cell": Vector2i(12, 10)},
		{"id": "team_leader", "cell": Vector2i(13, 4)},
	]
	# P1 NPCs: placed now so the map is ready; their dialogue is a stub in Story.
	list.append({"id": "senior", "cell": Vector2i(20, 7)})
	list.append({"id": "vendor", "cell": Vector2i(25, 20)})
	list.append({"id": "cafeteria", "cell": Vector2i(34, 4)})
	return list


func objects() -> Array:
	return [
		{
			"id": "delivery_car", "cell": Vector2i(40, 20), "radius": 22.0,
			"texture": "res://assets/sprites/placeholder/car_player.png", "solid": true,
		},
	]


func on_map_ready() -> void:
	if not GameState.has_flag("intro_done"):
		await get_tree().create_timer(0.6).timeout
		await Story.play_intro()
