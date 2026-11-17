class_name MapBase
extends Node2D
## Base for every walkable map. A map script extends this and overrides the
## data functions below; MapBase paints the tiles, places NPCs, objects, exits,
## the player, the camera, the HUD and the touch controls.
##
## Layout: one string per row, characters from Tiles.LEGEND. Every row must be
## the same length. Cells are Vector2i(column, row).

## Screen space the HUD covers (top bar + objective, bottom menu bar).
const HUD_TOP := 52.0
const HUD_BOTTOM := 30.0

var player: Player
var ground: TileMapLayer
var entities: Node2D
var hud: Hud
var touch: TouchControls
var map_size_px := Vector2.ZERO
var _exit_centers: Dictionary = {}  # "exit:<to>" -> world position
var _marker: Label
var _marker_t := 0.0


# ---------------------------------------------------------------- override these
func map_id() -> String:
	return ""


func layout() -> PackedStringArray:
	return PackedStringArray()


## spawn id -> cell. Must contain "default".
func spawns() -> Dictionary:
	return {"default": Vector2i(1, 1)}


## [{"id": "narumi", "cell": Vector2i(3, 4)}, ...]
## Optional per entry: "reach" (interact radius, for staff behind a counter) and
## "from" (cell the player talks from; used by tests/smoke_loop.gd).
func npcs() -> Array:
	return []


## Building name boards on the facade: [{"text": "한빛소방서", "cell": Vector2i(7, 8)}].
## The board is centered on the cell. Put it beside the door, not over it.
func signs() -> Array:
	return []


## Extra objects not covered by Tiles.OBJECT_CHARS:
## [{"id": "delivery_car", "cell": Vector2i(..), "texture": "res://...", "radius": 20.0}]
func objects() -> Array:
	return []


## [{"rect": Rect2i(col, row, w, h), "to": "office", "spawn": "parking"}]
func exits() -> Array:
	return []


## Runs after everything is placed. May use await (cutscenes).
## Default: let Story run this map's intro / arrival logic.
func on_map_ready() -> void:
	await Story.on_map_ready(map_id())


# ---------------------------------------------------------------- build
func _ready() -> void:
	# Drop locks leaked by an interrupted dialogue; SceneRouter re-locks during fades.
	GameState.reset_input_locks()
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = Tiles.get_tileset()
	add_child(ground)
	_paint()
	for entry: Dictionary in signs():
		_add_sign(str(entry["text"]), entry["cell"])

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)

	for entry: Dictionary in npcs():
		var npc := Npc.new().setup(str(entry["id"]))
		npc.position = Tiles.cell_center(entry["cell"])
		if entry.has("reach"):
			npc.interact_radius = float(entry["reach"])
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

	# Bouncing arrow over whatever Story.objective_target() names.
	_marker = UiTheme.make_label("▼", UiTheme.SIZE, UiTheme.COLOR_WARN, true)
	_marker.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.15))
	_marker.add_theme_constant_override("outline_size", 4)
	_marker.z_index = 50
	_marker.hide()
	add_child(_marker)

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


## Wooden name board with cream lettering and a dark outline.
func _add_sign(text: String, cell: Vector2i) -> void:
	var board := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("8a5a36")
	sb.border_color = Color("261e2c")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	board.add_theme_stylebox_override("panel", sb)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.make_label(text, UiTheme.SIZE, Color("fbf3dc"), true)
	board.add_child(l)
	add_child(board)
	board.reset_size()
	board.position = (Tiles.cell_center(cell) - board.size / 2.0).round()


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
	_exit_centers["exit:" + to] = area.position
	area.body_entered.connect(_on_exit_entered.bind(to, spawn))
	add_child(area)


func _on_exit_entered(body: Node2D, to: String, spawn: String) -> void:
	if body is Player and not SceneRouter.busy:
		Story.on_exit(map_id(), to, spawn)


# ---------------------------------------------------------------- camera
func _process(delta: float) -> void:
	_update_camera()
	_update_marker(delta)


func _update_marker(delta: float) -> void:
	var target := Story.objective_target()
	var pos := _target_position(target)
	var cam := get_node_or_null("Camera") as Camera2D
	if target == "" or pos == Vector2.INF or Dialogue.is_open or Dialogue.overlay_open or cam == null:
		_marker.hide()
		return
	_marker_t += delta
	_marker.show()
	var bob := sin(_marker_t * 6.0) * 2.0
	# Visible world rect (minus the HUD) - off-screen targets get an edge arrow.
	var view := get_viewport_rect().size / cam.zoom
	var top := HUD_TOP / cam.zoom.y
	var bottom := HUD_BOTTOM / cam.zoom.y
	var rect := Rect2(cam.position - view / 2.0 + Vector2(0, top), view - Vector2(0, top + bottom)).grow(-14)
	if rect.has_point(pos):
		_marker.text = "▼"
		_marker.position = (pos + Vector2(-6, -12 + bob)).round()
		return
	var d := pos - rect.get_center()
	var edge := Vector2(clampf(pos.x, rect.position.x, rect.end.x), clampf(pos.y, rect.position.y, rect.end.y))
	if absf(d.x) * rect.size.y > absf(d.y) * rect.size.x:
		_marker.text = "▶" if d.x > 0 else "◀"
		edge.x += bob if d.x > 0 else -bob
	else:
		_marker.text = "▼" if d.y > 0 else "▲"
		edge.y += bob if d.y > 0 else -bob
	_marker.position = (edge + Vector2(-6, -8)).round()


## World position the objective arrow should sit above, or Vector2.INF if the
## target is not on this map.
func _target_position(target: String) -> Vector2:
	if target == "":
		return Vector2.INF
	if _exit_centers.has(target):
		return _exit_centers[target] + Vector2(0, -12)
	for n: Node in get_tree().get_nodes_in_group("interactable"):
		var n2 := n as Node2D
		if n2 == null:
			continue
		if n2.get("npc_id") == target:
			return n2.global_position + Vector2(0, -54)
		if n2.get("object_id") == target:
			return n2.global_position + Vector2(0, -20)
	return Vector2.INF


## Follows the player, clamped to the map. The HUD covers the top bar and the
## bottom menu bar, so the map may scroll past the screen edge by those insets.
## On an axis where the map is smaller than the visible area, it is centered.
## Small rooms (the home) are shown at 2x when they fit.
func _update_camera() -> void:
	var cam := get_node_or_null("Camera") as Camera2D
	if cam == null or player == null:
		return
	var screen := get_viewport_rect().size
	var z := 2.0 if map_size_px.x * 2.0 <= screen.x - 16.0 and map_size_px.y * 2.0 <= screen.y - HUD_TOP - HUD_BOTTOM else 1.0
	cam.zoom = Vector2(z, z)
	var view := screen / z
	var insets := [Vector2(0, 0), Vector2(HUD_TOP, HUD_BOTTOM) / z]  # per axis: (before, after)
	var target := player.position
	for axis in 2:
		var before: float = (insets[axis] as Vector2).x
		var after: float = (insets[axis] as Vector2).y
		var lo := view[axis] / 2.0 - before
		var hi := map_size_px[axis] - view[axis] / 2.0 + after
		if lo >= hi:
			target[axis] = (lo + hi) / 2.0
		else:
			target[axis] = clampf(target[axis], lo, hi)
	cam.position = target.round()
