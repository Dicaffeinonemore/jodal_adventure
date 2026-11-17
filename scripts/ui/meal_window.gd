class_name MealWindow
extends CanvasLayer
## Cafeteria meal window: a small pixel scene of the player eating at a table,
## then the result (fatigue, condition). Story builds every string:
##     var w := MealWindow.new()
##     get_tree().root.add_child(w)
##     await w.run(data)
## data keys: title, food (texture path, 3 frames: full / half / empty), eating ("식사 중..."),
##   bite ("냠냠!"), result ([[text, Color], ...]), ok ("확인").
## Interact or a tap skips the eating part (after a moment) and closes the result.

signal _closed

const SPRITES := "res://assets/sprites/placeholder/"
const INK := Color("261e2c")
const CREAM := Color("fbf3dc")
const TEXT := Color("2e2636")
const SCALE := 2.0
const STAGE := Vector2(160, 90)
const DURATION := 3.6
const BITE_EVERY := 0.9
const SKIP_AFTER := 0.8
const FEET := Vector2(80, 66)
const FOOD_POS := Vector2(80, 77)  # bottom center of the dish on the table
const MOUTH := Vector2(85, 51)

enum Phase { EATING, RESULT, DONE }

var _data: Dictionary = {}
var _phase := Phase.EATING
var _t := 0.0
var _last_bite := -1
var _stage: Node2D
var _visual: CharacterVisual
var _food: Sprite2D
var _spoon: Sprite2D
var _steam: Steam
var _bubble: PanelContainer
var _bubble_t := 0.0
var _progress: ProgressBar
var _eating_row: Control
var _result_box: VBoxContainer
var _frame_w := 0


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

	# the pixel scene, drawn at 2x
	var holder := Control.new()
	holder.custom_minimum_size = STAGE * SCALE
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(holder)
	var frame := ReferenceRect.new()  # dark outline around the scene
	frame.border_color = INK
	frame.border_width = 2.0
	frame.editor_only = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage = Node2D.new()
	_stage.scale = Vector2(SCALE, SCALE)
	holder.add_child(_stage)
	_stage.add_child(_sprite("meal_bg.png", Vector2.ZERO))
	_visual = CharacterVisual.new()
	_visual.position = FEET
	_visual.set_look(GameState.get_look())
	_visual.play("idle_down", false)
	_stage.add_child(_visual)
	_stage.add_child(_sprite("meal_table.png", Vector2(0, 56)))
	var food_tex := load(str(_data.get("food", ""))) as Texture2D
	_food = Sprite2D.new()
	_food.centered = false
	if food_tex != null:
		_frame_w = int(food_tex.get_width() / 3.0)
		_food.texture = food_tex
		_food.region_enabled = true
		_food.position = (FOOD_POS - Vector2(_frame_w / 2.0, food_tex.get_height())).round()
	_stage.add_child(_food)
	_set_food_frame(0)
	_steam = Steam.new()
	_steam.position = FOOD_POS + Vector2(0, -16)
	_stage.add_child(_steam)
	_spoon = _sprite("spoon.png", Vector2.ZERO)
	_stage.add_child(_spoon)
	holder.add_child(frame)

	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", _box(Color.WHITE, INK, 2, 6, 3))
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(UiTheme.make_label(str(_data.get("bite", "")), UiTheme.SIZE, TEXT, true))
	_bubble.position = (MOUTH + Vector2(10, -26)) * SCALE
	_bubble.hide()
	holder.add_child(_bubble)

	# bottom: progress while eating, then the result
	_eating_row = HBoxContainer.new()
	_eating_row.add_theme_constant_override("separation", 6)
	vb.add_child(_eating_row)
	_eating_row.add_child(UiTheme.make_label(str(_data.get("eating", "")), UiTheme.SIZE, TEXT, true))
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = DURATION
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.custom_minimum_size = Vector2(0, 8)
	_progress.add_theme_stylebox_override("background", _box(Color("e6dcc2"), INK, 1, 2, 0))
	_progress.add_theme_stylebox_override("fill", _box(Color("f0a040"), INK, 0, 2, 0))
	_eating_row.add_child(_progress)

	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 2)
	_result_box.hide()
	vb.add_child(_result_box)
	for entry: Array in _data.get("result", []):
		var l := UiTheme.make_label(str(entry[0]), UiTheme.SIZE, entry[1] if entry.size() > 1 else TEXT, true)
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
	ok.add_theme_color_override("font_color", CREAM)
	ok.add_theme_color_override("font_hover_color", CREAM)
	ok.add_theme_color_override("font_pressed_color", CREAM)
	ok.pressed.connect(_advance)
	_result_box.add_child(ok)


# ---------------------------------------------------------------- animation
func _process(delta: float) -> void:
	if _phase != Phase.EATING:
		return
	_t += delta
	_progress.value = _t
	var cycle := fmod(_t, BITE_EVERY) / BITE_EVERY
	var dish := FOOD_POS + Vector2(4, -10)
	var pos := dish
	if cycle < 0.4:
		pos = dish + Vector2(0, sin(cycle * 40.0))  # stirring
	elif cycle < 0.65:
		pos = dish.lerp(MOUTH, (cycle - 0.4) / 0.25)
	elif cycle < 0.8:
		pos = MOUTH
	else:
		pos = MOUTH.lerp(dish, (cycle - 0.8) / 0.2)
	_spoon.position = (pos - Vector2(2, 6)).round()
	var bite := int(_t / BITE_EVERY)
	if cycle >= 0.65 and bite != _last_bite:
		_last_bite = bite
		Sound.play("nom", 0.08)
		_bubble.show()
		_bubble_t = 0.35
		_visual.position = FEET + Vector2(0, 1)
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.hide()
			_visual.position = FEET
	_set_food_frame(0 if _t < DURATION * 0.45 else 1)
	if _t >= DURATION:
		_show_result()


func _show_result() -> void:
	_phase = Phase.RESULT
	Sound.play("jingle_good")
	_set_food_frame(2)
	_steam.hide()
	_bubble.hide()
	_visual.position = FEET
	_spoon.position = FOOD_POS + Vector2(14, -14)
	_spoon.rotation = 0.6
	_eating_row.hide()
	_result_box.show()


func _set_food_frame(f: int) -> void:
	if _food.texture == null:
		return
	_food.region_rect = Rect2(f * _frame_w, 0, _frame_w, _food.texture.get_height())


func _advance() -> void:
	match _phase:
		Phase.EATING:
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
func _sprite(file: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(SPRITES + file) as Texture2D
	s.centered = false
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


## Three wisps of steam rising from the dish.
class Steam:
	extends Node2D
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in 3:
			var x0 := -6.0 + i * 6.0
			for k in 4:
				var rise := fmod(_t * 10.0 + k * 3.0 + i * 2.0, 12.0)
				var x := x0 + roundf(sin((rise + i) * 0.7) * 1.5)
				var a := 0.75 * (1.0 - rise / 12.0)
				draw_rect(Rect2(x, -rise, 1, 1), Color(1, 1, 1, a))
