extends Node2D
## 운송 미니게임: the truck drives up a 3-lane road automatically; the player
## only changes lanes. Hitting obstacles lowers cargo condition, which becomes
## the delivery quality at inspection.
##
## Controls: move_left / move_right (keys, touch joystick) or tap the left /
## right half of the screen. Quick item (Q / touch) uses an energy bar.
## Bad condition (fatigue >= 70 or too much coffee) makes the truck drift.

const DURATION := 45.0
const LANES := 3
const LANE_W := 44.0
const BASE_SPEED := 120.0
const MAX_SPEED := 190.0
const SPAWN_MIN := 0.8
const SPAWN_MAX := 1.4
const LANE_SWITCH_TIME := 0.12
const INVULN_TIME := 0.8
const DROWSY_MIN := 3.0
const DROWSY_MAX := 5.5

## kind -> texture, cargo damage, own speed (fraction of road speed it moves *with* us)
const OBSTACLES := {
	"car": {"tex": "res://assets/sprites/placeholder/car_npc.png", "damage": 20, "drift": 0.45},
	"cone": {"tex": "res://assets/sprites/placeholder/cone.png", "damage": 10, "drift": 0.0},
	"bump": {"tex": "res://assets/sprites/placeholder/speed_bump.png", "damage": 8, "drift": 0.0},
}

enum State { COUNTDOWN, DRIVING, FINISHED }

var cargo := 100
var _state := State.COUNTDOWN
var _elapsed := 0.0
var _speed := BASE_SPEED
var _scroll := 0.0
var _lane := 1
var _spawn_timer := 1.0
var _invuln := 0.0
var _drowsy_timer := 0.0
var _drowsy_block := 0.0  # seconds without drowsiness after an energy bar
var _countdown := 3.0
var _rng := RandomNumberGenerator.new()

var _road_x := 0.0
var _view := Vector2.ZERO
var _truck: Sprite2D
var _obstacles: Array[Dictionary] = []  # {"node": Sprite2D, "kind": String, "lane": int}
var _ui: CanvasLayer
var _progress: ProgressBar
var _cargo_label: Label
var _center_label: Label


func _ready() -> void:
	GameState.reset_input_locks()
	_rng.randomize()
	_truck = Sprite2D.new()
	_truck.texture = load("res://assets/sprites/placeholder/car_player.png") as Texture2D
	_truck.z_index = 5
	add_child(_truck)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_truck.position.x = _lane_x(_lane)
	_drowsy_timer = _rng.randf_range(DROWSY_MIN, DROWSY_MAX)


func _layout() -> void:
	_view = get_viewport_rect().size
	_road_x = (_view.x - LANES * LANE_W) / 2.0
	_truck.position = Vector2(_lane_x(_lane), _view.y - 48)
	queue_redraw()


func _lane_x(lane: int) -> float:
	return _road_x + LANE_W * (lane + 0.5)


# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			_countdown -= delta
			_center_label.text = str(ceili(_countdown)) if _countdown > 0.0 else "출발!"
			if _countdown <= -0.5:
				_center_label.text = ""
				_state = State.DRIVING
		State.DRIVING:
			_drive(delta)
	queue_redraw()


func _drive(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / DURATION, 0.0, 1.0)
	_speed = lerpf(BASE_SPEED, MAX_SPEED, t)
	_scroll = fmod(_scroll + _speed * delta, 32.0)
	_progress.value = t * 100.0
	_invuln = maxf(0.0, _invuln - delta)
	_truck.modulate.a = 0.4 if _invuln > 0.0 and fmod(_invuln, 0.2) < 0.1 else 1.0

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _elapsed < DURATION - 2.0:
		_spawn_obstacle()
		_spawn_timer = _rng.randf_range(SPAWN_MIN, SPAWN_MAX) * lerpf(1.0, 0.7, t)

	_update_drowsiness(delta)

	var truck_rect := _rect_of(_truck).grow(-2)
	for i in range(_obstacles.size() - 1, -1, -1):
		var ob: Dictionary = _obstacles[i]
		var node: Sprite2D = ob["node"]
		var info: Dictionary = OBSTACLES[ob["kind"]]
		node.position.y += _speed * (1.0 - float(info["drift"])) * delta
		if node.position.y > _view.y + 40:
			node.queue_free()
			_obstacles.remove_at(i)
			continue
		if _invuln <= 0.0 and truck_rect.intersects(_rect_of(node).grow(-1)):
			_hit(int(info["damage"]), str(ob["kind"]))
			node.queue_free()
			_obstacles.remove_at(i)

	if _elapsed >= DURATION:
		_finish()


func _update_drowsiness(delta: float) -> void:
	_drowsy_block = maxf(0.0, _drowsy_block - delta)
	if GameState.condition() != GameState.Condition.BAD or _drowsy_block > 0.0:
		return
	_drowsy_timer -= delta
	if _drowsy_timer <= 0.0:
		_drowsy_timer = _rng.randf_range(DROWSY_MIN, DROWSY_MAX)
		var dir := -1 if _rng.randf() < 0.5 else 1
		if _lane + dir < 0 or _lane + dir >= LANES:
			dir = -dir
		_flash_text("졸음! 핸들이 흔들려요", UiTheme.COLOR_WARN)
		_change_lane(dir)


func _spawn_obstacle() -> void:
	var kinds := ["car", "car", "cone", "bump"]
	var kind: String = kinds[_rng.randi() % kinds.size()]
	var lane := _rng.randi() % LANES
	var node := Sprite2D.new()
	node.texture = load(str(OBSTACLES[kind]["tex"])) as Texture2D
	node.position = Vector2(_lane_x(lane), -30)
	add_child(node)
	_obstacles.append({"node": node, "kind": kind, "lane": lane})


func _hit(damage: int, kind: String) -> void:
	if GameState.condition() == GameState.Condition.GOOD:
		damage = roundi(damage * 0.8)
	cargo = maxi(0, cargo - damage)
	_invuln = INVULN_TIME
	_cargo_label.text = "화물 상태 %d%%" % cargo
	var msg := "쿵! 화물 -%d" % damage
	if kind == "bump":
		msg = "덜컹! 화물 -%d" % damage
	_flash_text(msg, UiTheme.COLOR_BAD)
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(3, 0), 0.04)
	tw.tween_property(self, "position", Vector2(-3, 0), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


func _change_lane(dir: int) -> void:
	var target := clampi(_lane + dir, 0, LANES - 1)
	if target == _lane:
		return
	_lane = target
	var tw := create_tween()
	tw.tween_property(_truck, "position:x", _lane_x(_lane), LANE_SWITCH_TIME)


func _finish() -> void:
	_state = State.FINISHED
	_center_label.text = "도착! 화물 상태 %d%%" % cargo
	await get_tree().create_timer(1.5).timeout
	Story.on_drive_finished(cargo)


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.DRIVING:
		return
	if event.is_action_pressed("move_left"):
		_change_lane(-1)
	elif event.is_action_pressed("move_right"):
		_change_lane(1)
	elif event.is_action_pressed("quick_item"):
		_use_item()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var pos := (event as InputEventScreenTouch).position
		if pos.y < 60 and pos.x > _view.x - 80:
			_use_item()
		else:
			_change_lane(-1 if pos.x < _view.x / 2.0 else 1)


func _use_item() -> void:
	if Story.use_quick_item(true) != "":
		_drowsy_block = 8.0


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _view), Color("6aa84f"))
	var road := Rect2(_road_x - 6, 0, LANES * LANE_W + 12, _view.y)
	draw_rect(road, Color("55555c"))
	draw_rect(Rect2(_road_x - 6, 0, 3, _view.y), Color("e8e8e8"))
	draw_rect(Rect2(_road_x + LANES * LANE_W + 3, 0, 3, _view.y), Color("e8e8e8"))
	for i in range(1, LANES):
		var x := _road_x + LANE_W * i - 1
		var y := -32.0 + _scroll
		while y < _view.y:
			draw_rect(Rect2(x, y, 2, 14), Color("f0d060"))
			y += 32.0
	# roadside trees for a sense of speed
	var tree_y := fmod(_scroll * 2.0, 64.0) - 64.0
	while tree_y < _view.y:
		draw_circle(Vector2(_road_x - 24, tree_y), 8, Color("3f7f3a"))
		draw_circle(Vector2(_road_x + LANES * LANE_W + 24, tree_y + 32), 8, Color("3f7f3a"))
		tree_y += 64.0


func _rect_of(s: Sprite2D) -> Rect2:
	var size := s.texture.get_size()
	return Rect2(s.position - size / 2.0, size)


# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply(root)
	_ui.add_child(root)
	var m := UiTheme.edge_margin()

	var panel := PanelContainer.new()
	panel.position = Vector2(m, 6)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8))
	root.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	vb.add_child(UiTheme.make_label("%s 납품 중" % Korean.ro(Story.destination_name()), UiTheme.SIZE, UiTheme.COLOR_BORDER, true))
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(120, 8)
	_progress.show_percentage = false
	vb.add_child(_progress)
	_cargo_label = UiTheme.make_label("화물 상태 100%", UiTheme.SIZE_SMALL)
	vb.add_child(_cargo_label)
	vb.add_child(UiTheme.make_label("컨디션 " + GameState.condition_label(), UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))

	var hint_text := "← → 차선 변경 / Q 에너지바"
	if GameState.is_touch_device():
		hint_text = "화면 왼쪽·오른쪽 터치로 차선 변경 / 오른쪽 위 터치: 에너지바"
	var hint := UiTheme.make_label(hint_text, UiTheme.SIZE_SMALL, UiTheme.COLOR_TEXT)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.offset_top = -18
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint.add_theme_constant_override("outline_size", 4)
	root.add_child(hint)

	_center_label = UiTheme.make_label("3", UiTheme.SIZE_LARGE, UiTheme.COLOR_TEXT, true)
	_center_label.set_anchors_preset(Control.PRESET_CENTER)
	_center_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_center_label.add_theme_constant_override("outline_size", 6)
	root.add_child(_center_label)


func _flash_text(text: String, color: Color) -> void:
	Dialogue.toast(text, color)
