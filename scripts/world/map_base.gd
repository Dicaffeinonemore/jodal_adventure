class_name MapBase
extends Node2D
## Base for every walkable map. A map script extends this and overrides the
## data functions below; MapBase paints the tiles, places NPCs, objects, exits,
## the player, the camera, the HUD and the touch controls.
##
## Layout: one string per row, characters from Tiles.LEGEND. Every row must be
## the same length. Cells are Vector2i(column, row).

var player: Player
var ground: TileMapLayer
var entities: Node2D
var hud: Hud
var touch: TouchControls
var map_size_px := Vector2.ZERO


# ---------------------------------------------------------------- override these
func map_id() -> String:
	return ""


func layout() -> PackedStringArray:
	return PackedStringArray()


## spawn id -> cell. Must contain "default".
func spawns() -> Dictionary:
	return {"default": Vector2i(1, 1)}


## [{"id": "narumi", "cell": Vector2i(3, 4)}, ...]
func npcs() -> Array:
	return []


## Extra objects not covered by Tiles.OBJECT_CHARS:
## [{"id": "delivery_car", "cell": Vector2i(..), "texture": "res://...", "radius": 20.0}]
func objects() -> Array:
	return []


## [{"rect": Rect2i(col, row, w, h), "to": "office", "spawn": "parking"}]
func exits() -> Array:
	return []


## Runs after everything is placed. May use await (cutscenes).
func on_map_ready() -> void:
	pass


# ---------------------------------------------------------------- build
func _ready() -> void:
	# Drop locks leaked by an interrupted dialogue; SceneRouter re-locks during fades.
	GameState.reset_input_locks()
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = Tiles.get_tileset()
	add_child(ground)
	_paint()

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)

	for entry: Dictionary in npcs():
		var npc := Npc.new().setup(str(entry["id"]))
		npc.position = Tiles.cell_center(entry["cell"])
		entities.add_child(npc)

	for entry: Dictionary in objects():
		var tex: Texture2D = null
		if entry.has("texture"):
			tex = load(str(entry["texture"])) as Texture2D
		var obj := Interactable.new().setup(
				str(entry["id"]), tex, float(entry.get("radius", 14.0)), bool(entry.get("solid", false)))
		obj.position = Tiles.cell_center(entry["cell"])
		entities.add_child(obj)

	for entry: Dictionary in exits():
		_add_exit(entry)

	player = Player.new()
	player.name = "Player"
	entities.add_child(player)
	var spawn_map := spawns()
	var spawn_id := SceneRouter.next_spawn
	if not spawn_map.has(spawn_id):
		spawn_id = "default"
	player.position = Tiles.cell_center(spawn_map[spawn_id])

	hud = Hud.new()
	add_child(hud)
	touch = TouchControls.new()
	add_child(touch)

	var cam := Camera2D.new()
	cam.name = "Camera"
	add_child(cam)
	cam.make_current()
	_update_camera()
	cam.reset_smoothing()

	on_map_ready()


func _paint() -> void:
	var rows := layout()
	var width := 0
	for y in rows.size():
		var row := rows[y]
		width = maxi(width, row.length())
		for x in row.length():
			var ch := row[x]
			ground.set_cell(Vector2i(x, y), 0, Vector2i(Tiles.tile_for(ch), 0))
			if Tiles.OBJECT_CHARS.has(ch):
				var obj := Interactable.new().setup(str(Tiles.OBJECT_CHARS[ch]))
				obj.position = Tiles.cell_center(Vector2i(x, y))
				add_child(obj)
	map_size_px = Vector2(width * Tiles.TILE, rows.size() * Tiles.TILE)


func _add_exit(entry: Dictionary) -> void:
	var r: Rect2i = entry["rect"]
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(r.size * Tiles.TILE)
	shape.shape = rect
	area.add_child(shape)
	area.position = Vector2(r.position * Tiles.TILE) + rect.size / 2.0
	var to := str(entry["to"])
	var spawn := str(entry.get("spawn", "default"))
	area.body_entered.connect(_on_exit_entered.bind(to, spawn))
	add_child(area)


func _on_exit_entered(body: Node2D, to: String, spawn: String) -> void:
	if body is Player and not SceneRouter.busy:
		Story.on_exit(map_id(), to, spawn)


# ---------------------------------------------------------------- camera
func _process(_delta: float) -> void:
	_update_camera()


## Follows the player, clamped to the map. On an axis where the map is smaller
## than the screen (small rooms, wide phones), the map is centered instead.
func _update_camera() -> void:
	var cam := get_node_or_null("Camera") as Camera2D
	if cam == null or player == null:
		return
	var view := get_viewport_rect().size
	var target := player.position
	for axis in 2:
		if map_size_px[axis] <= view[axis]:
			target[axis] = map_size_px[axis] / 2.0
		else:
			target[axis] = clampf(target[axis], view[axis] / 2.0, map_size_px[axis] - view[axis] / 2.0)
	cam.position = target.round()
