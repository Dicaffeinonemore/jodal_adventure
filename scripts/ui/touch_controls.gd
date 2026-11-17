class_name TouchControls
extends CanvasLayer
## Mobile controls: a floating 4-direction joystick on the left half of the
## screen (push it all the way to run) and A (interact) / B (menu) / item buttons on the right.
## They press the same input actions as the keyboard (see InputSetup), so the
## rest of the game never checks for touch.
##
## Shown on touch devices only. Press F2 on PC to toggle them for testing
## (mouse clicks are emulated as touches, see project.godot).
## Hidden while a dialogue is open: tap the dialogue box to advance instead.

const TEX_DIR := "res://assets/sprites/placeholder/"
const JOY_RADIUS := 28.0
const JOY_DEADZONE := 8.0
const JOY_ZONE_WIDTH := 0.45  # left part of the screen that starts the joystick
const JOY_RUN := 0.9  # pushing the knob this far out (of JOY_RADIUS) presses "run"

var _joy_base: Sprite2D
var _joy_knob: Sprite2D
var _joy_rest := Vector2.ZERO
var _joy_center := Vector2.ZERO
var _joy_touch := -1
var _joy_dir := Vector2.ZERO
var _joy_run := false
var _btn_a: TouchScreenButton
var _btn_b: TouchScreenButton
var _btn_item: TouchScreenButton
var _item_icon: Sprite2D
var _active := false


func _ready() -> void:
	layer = 20
	_joy_base = _sprite("joy_base.png")
	_joy_knob = _sprite("joy_knob.png")
	_btn_a = _button("touch_a.png", "interact", 26.0)
	_btn_b = _button("touch_b.png", "cancel", 22.0)
	_btn_item = _button("touch_item.png", "quick_item", 20.0)
	_item_icon = Sprite2D.new()
	_btn_item.add_child(_item_icon)
	_item_icon.position = Vector2(16, 16)

	get_viewport().size_changed.connect(_layout)
	Dialogue.opened.connect(_refresh_visibility)
	Dialogue.closed.connect(_refresh_visibility)
	GameState.inventory_changed.connect(_refresh_item_icon)
	_layout()
	_refresh_item_icon()
	_refresh_visibility()


func _exit_tree() -> void:
	_set_dir(Vector2.ZERO)
	_set_run(false)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var m := UiTheme.edge_margin()
	_joy_rest = Vector2(m + 48, view.y - 56)
	if _joy_touch == -1:
		_joy_center = _joy_rest
		_joy_base.position = _joy_rest
		_joy_knob.position = _joy_rest
	# TouchScreenButton positions are their top-left corner.
	_btn_a.position = Vector2(view.x - m - 44 - 8, view.y - 44 - 30)
	_btn_b.position = Vector2(view.x - m - 36 - 64, view.y - 36 - 12)
	_btn_item.position = Vector2(view.x - m - 32 - 16, view.y - 32 - 96)


func _refresh_visibility() -> void:
	_active = GameState.is_touch_device() and not Dialogue.is_open
	visible = _active
	if not _active:
		_release_joystick()


func _refresh_item_icon() -> void:
	var id := Story.quick_item_id(false)
	_item_icon.texture = ItemDB.icon(id) if id != "" else null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_touch_ui"):
		GameState.force_touch_ui = not GameState.force_touch_ui
		_refresh_visibility()
		return
	if not _active:
		return
	var view := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _joy_touch == -1 and st.position.x < view.x * JOY_ZONE_WIDTH and st.position.y > view.y * 0.25 				and not _on_menu_bar(st.position):
			_joy_touch = st.index
			_joy_center = st.position
			_joy_base.position = st.position
			_update_joystick(st.position)
		elif not st.pressed and st.index == _joy_touch:
			_release_joystick()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _joy_touch:
			_update_joystick(sd.position)


## Taps on the HUD's bottom menu bar must not start the joystick.
func _on_menu_bar(pos: Vector2) -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	return hud != null and (hud.call("menu_bar_rect") as Rect2).grow(4).has_point(pos)


func _update_joystick(pos: Vector2) -> void:
	var v := (pos - _joy_center).limit_length(JOY_RADIUS)
	_joy_knob.position = _joy_center + v
	var dir := Vector2.ZERO
	if v.length() > JOY_DEADZONE:
		if absf(v.x) > absf(v.y):
			dir = Vector2(signf(v.x), 0)
		else:
			dir = Vector2(0, signf(v.y))
	_set_dir(dir)
	_set_run(dir != Vector2.ZERO and v.length() >= JOY_RADIUS * JOY_RUN)


func _release_joystick() -> void:
	_joy_touch = -1
	_joy_center = _joy_rest
	if _joy_base != null:
		_joy_base.position = _joy_rest
		_joy_knob.position = _joy_rest
	_set_dir(Vector2.ZERO)
	_set_run(false)


func _set_run(on: bool) -> void:
	if on == _joy_run:
		return
	_joy_run = on
	_toggle("run", on)


## Presses exactly one move action (or none), so movement stays 4-directional.
func _set_dir(dir: Vector2) -> void:
	if dir == _joy_dir:
		return
	_joy_dir = dir
	_toggle("move_left", dir.x < 0)
	_toggle("move_right", dir.x > 0)
	_toggle("move_up", dir.y < 0)
	_toggle("move_down", dir.y > 0)


func _toggle(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _sprite(file: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(TEX_DIR + file) as Texture2D
	add_child(s)
	return s


## TouchScreenButton sends a real InputEventAction, so _unhandled_input
## handlers (Player, Hud, Dialogue) receive it like a key press.
func _button(file: String, action: String, radius: float) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = load(TEX_DIR + file) as Texture2D
	b.action = action
	var circle := CircleShape2D.new()
	circle.radius = radius
	b.shape = circle
	b.shape_centered = true
	b.passby_press = false
	add_child(b)
	return b
