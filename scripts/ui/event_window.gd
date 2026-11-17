class_name EventWindow
extends CanvasLayer
## A short pixel "event scene" in a window, then its result. Same look and controls
## as MealWindow. Story builds every string:
##     var w := EventWindow.new()
##     get_tree().root.add_child(w)
##     await w.run(data)
## data keys:
##   title, bg (texture path, 160x90), mode ("carry" | "inspect"), npc (sprite path),
##   caption (shown with the progress bar), bubbles ([text, ...] said during the scene),
##   result ([[text, Color], ...]), ok (button text)
##   carry:   prop (texture carried, e.g. box_carry.png)
##   inspect: item (product texture), defects (int, marks the inspector circles),
##            stamp (text, e.g. "합격"), stamp_color (Color)
## Interact or a tap skips the scene (after a moment) and closes the result.

signal _closed

const SPRITES := "res://assets/sprites/placeholder/"
const INK := Color("261e2c")
const CREAM := Color("fbf3dc")
const TEXT := Color("2e2636")
const SCALE := 2.0
const STAGE := Vector2(160, 90)
const DURATION := 3.8
const SKIP_AFTER := 0.8
const FLOOR_Y := 80.0  # feet line in the stage
const BUBBLE_EVERY := 1.1

enum Phase { PLAYING, RESULT, DONE }

var _data: Dictionary = {}
var _phase := Phase.PLAYING
var _t := 0.0
var _stage: Node2D
var _holder: Control
var _player: CharacterVisual
var _npc: AnimatedSprite2D
var _prop: Sprite2D
var _stack: Array[Sprite2D] = []
var _item: Sprite2D
var _marks: Marks
var _lens: Sprite2D
var _stamp: PanelContainer
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_t := 0.0
var _bubble_i := 0
var _trips := 0
var _progress: ProgressBar
var _play_row: Control
var _result_box: VBoxContainer


func run(data: Dictionary) -> void:
	_data = data
	_build()
	Dialogue.set_overlay(true)
	await _closed
	Dialogue.set_overlay(false)


# ---------------------------------------------------------------- build
func _build() -> void:
	layer = 40
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	UiTheme.apply(root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.08, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_tap)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var win := PanelContainer.new()
	win.add_theme_stylebox_override("panel", _box(CREAM, INK, 2, 6, 6))
	win.gui_input.connect(_on_tap)
	center.add_child(win)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	win.add_child(vb)

	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", _box(INK, INK, 0, 3, 2))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := UiTheme.make_label(str(_data.get("title", "")), UiTheme.SIZE, CREAM, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(tl)
	vb.add_child(title)

	_holder = Control.new()
	_holder.custom_minimum_size = STAGE * SCALE
	_holder.clip_contents = true
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_holder)
	_stage = Node2D.new()
	_stage.scale = Vector2(SCALE, SCALE)
	_holder.add_child(_stage)
	_stage.add_child(_sprite(str(_data.get("bg", "")), Vector2.ZERO, false))
	if str(_data.get("mode", "carry")) == "inspect":
		_build_inspect()
	else:
		_build_carry()
	var frame := ReferenceRect.new()
	frame.border_color = INK
	frame.border_width = 2.0
	frame.editor_only = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(frame)

	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", _box(Color.WHITE, INK, 2, 6, 3))
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label = UiTheme.make_label("", UiTheme.SIZE, TEXT, true)
	_bubble.add_child(_bubble_label)
	_bubble.hide()
	_holder.add_child(_bubble)

	_play_row = HBoxContainer.new()
	_play_row.add_theme_constant_override("separation", 6)
	vb.add_child(_play_row)
	_play_row.add_child(UiTheme.make_label(str(_data.get("caption", "")), UiTheme.SIZE, TEXT, true))
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = DURATION
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.custom_minimum_size = Vector2(0, 8)
	_progress.add_theme_stylebox_override("background", _box(Color("e6dcc2"), INK, 1, 2, 0))
	_progress.add_theme_stylebox_override("fill", _box(Color("6fb6ff"), INK, 0, 2, 0))
	_play_row.add_child(_progress)

	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 2)
	_result_box.hide()
	vb.add_child(_result_box)
	for entry: Array in _data.get("result", []):
		var color: Color = entry[1] if entry.size() > 1 else TEXT
		var l := UiTheme.make_label(str(entry[0]), UiTheme.SIZE, color, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_result_box.add_child(l)
	var ok := Button.new()
	ok.text = str(_data.get("ok", ""))
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(80, 22)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.add_theme_stylebox_override("normal", _box(INK, INK, 1, 3, 3))
	ok.add_theme_stylebox_override("hover", _box(INK.lightened(0.15), INK, 1, 3, 3))
	ok.add_theme_stylebox_override("pressed", _box(INK.lightened(0.25), INK, 1, 3, 3))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		ok.add_theme_color_override(key, CREAM)
	ok.pressed.connect(_advance)
	_result_box.add_child(ok)


## Carry: the player walks boxes from the left pile to the NPC, who stacks them.
func _build_carry() -> void:
	for k in 3:  # the pile to move
		_stage.add_child(_sprite(str(_data.get("prop", SPRITES + "box_carry.png")), Vector2(10, FLOOR_Y - 10 - k * 9), false))
	_npc = _npc_sprite(Vector2(132, FLOOR_Y))
	_player = CharacterVisual.new()
	_player.position = Vector2(30, FLOOR_Y)
	_player.set_look(GameState.get_look())
	_stage.add_child(_player)
	_prop = _sprite(str(_data.get("prop", SPRITES + "box_carry.png")), Vector2.ZERO, true)
	_stage.add_child(_prop)


## Inspect: the inspector looks the item over with a magnifier, circles the defects, stamps.
func _build_inspect() -> void:
	_npc = _npc_sprite(Vector2(80, 58))
	_item = _sprite(str(_data.get("item", "")), Vector2(80, 54), true)
	_stage.add_child(_item)
	_marks = Marks.new()
	_marks.position = _item.position
	_marks.count = int(_data.get("defects", 0))
	_stage.add_child(_marks)
	_lens = _sprite(SPRITES + "magnifier.png", _item.position, true)
	_stage.add_child(_lens)
	_stamp = PanelContainer.new()
	var color: Color = _data.get("stamp_color", Color("c0392b"))
	var sb := _box(Color(1, 1, 1, 0.85), color, 3, 8, 6)
	_stamp.add_theme_stylebox_override("panel", sb)
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sl := UiTheme.make_label(str(_data.get("stamp", "")), UiTheme.SIZE_LARGE, color, true)
	_stamp.add_child(sl)
	_stamp.hide()
	_holder.add_child(_stamp)


# ---------------------------------------------------------------- animation
func _process(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.hide()
	if _phase != Phase.PLAYING:
		return
	_t += delta
	_progress.value = _t
	if str(_data.get("mode", "carry")) == "inspect":
		_animate_inspect()
	else:
		_animate_carry()
	var bubbles: Array = _data.get("bubbles", [])
	if not bubbles.is_empty() and _t >= _bubble_i * BUBBLE_EVERY + 0.4:
		var anchor := _player.position if _player != null else _npc.position
		_say(str(bubbles[_bubble_i % bubbles.size()]), anchor)
		_bubble_i += 1
	if _t >= DURATION:
		_show_result()


func _animate_carry() -> void:
	var trip := 1.25  # seconds there and back
	var c := fmod(_t, trip) / trip
	var going := c < 0.5
	var x := lerpf(30.0, 112.0, c * 2.0) if going else lerpf(112.0, 30.0, (c - 0.5) * 2.0)
	_player.position = Vector2(roundf(x), FLOOR_Y)
	_player.face("right" if going else "left", true)
	_prop.visible = going
	_prop.position = _player.position + Vector2(6 if going else -6, -17)
	var trips := int(_t / trip)
	if trips != _trips:  # one more box on the NPC's stack
		_trips = trips
		var box := _sprite(str(_data.get("prop", SPRITES + "box_carry.png")),
				Vector2(142, FLOOR_Y - 10 - _stack.size() * 9), false)
		_stage.add_child(box)
		_stack.append(box)
		Sound.play("pop")


func _animate_inspect() -> void:
	var a := _t * 2.6
	_lens.position = _item.position + Vector2(cos(a) * 9.0, sin(a * 2.0) * 5.0) + Vector2(4, -2)
	_marks.shown = clampi(int((_t / DURATION) * (_marks.count + 1)), 0, _marks.count)
	_marks.queue_redraw()


func _show_result() -> void:
	_phase = Phase.RESULT
	_play_row.hide()
	_result_box.show()
	if _player != null:
		_player.face("down", false)
		_prop.hide()
	if _stamp != null:
		_marks.shown = _marks.count
		_marks.queue_redraw()
		_lens.hide()
		_stamp.show()
		_stamp.reset_size()
		_stamp.pivot_offset = _stamp.size / 2.0
		_stamp.position = (_item.position * SCALE - _stamp.size / 2.0 + Vector2(0, -6)).round()
		_stamp.rotation = -0.2
		_stamp.scale = Vector2(1.8, 1.8)
		create_tween().tween_property(_stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
		Sound.play("stamp")
	else:
		Sound.play("jingle_good")


func _say(text: String, anchor: Vector2) -> void:
	_bubble_label.text = text
	_bubble.show()
	_bubble.reset_size()
	var pos := anchor * SCALE + Vector2(-_bubble.size.x / 2.0, -78)
	pos.x = clampf(pos.x, 4.0, STAGE.x * SCALE - _bubble.size.x - 4.0)
	_bubble.position = pos.round()
	_bubble_t = 0.7


func _advance() -> void:
	match _phase:
		Phase.PLAYING:
			if _t >= SKIP_AFTER:
				_show_result()
		Phase.RESULT:
			_phase = Phase.DONE
			hide()
			_closed.emit()


func _on_tap(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.DONE:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_advance()


# ---------------------------------------------------------------- helpers
func _npc_sprite(feet: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	var tex := load(str(_data.get("npc", ""))) as Texture2D
	if tex != null:
		s.sprite_frames = SpriteUtil.idle_frames(tex)
		s.play("idle")
	s.offset = CharacterVisual.FEET_OFFSET
	s.position = feet
	_stage.add_child(s)
	return s


func _sprite(path: String, pos: Vector2, centered: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path) as Texture2D
	s.centered = centered
	s.position = pos
	return s


func _box(bg: Color, border: Color, width: int, radius: int, pad: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


## Red circles the inspector draws around the defects found, one at a time.
class Marks:
	extends Node2D
	var count := 0
	var shown := 0
	const SPOTS := [Vector2(-6, -3), Vector2(6, 2), Vector2(-2, 6), Vector2(7, -5), Vector2(-8, 4)]

	func _draw() -> void:
		for i in mini(shown, SPOTS.size()):
			draw_arc(SPOTS[i], 4.0, 0.0, TAU, 12, Color("e0483c"), 1.0)
