class_name VolumeWindow
extends CanvasLayer
## Volume settings: music and effects, each 0..Sound.VOLUME_STEPS (0 = off).
## Opened from the title screen and the phone's 소리 app. Story builds every string:
##     var w := VolumeWindow.new()
##     get_tree().root.add_child(w)
##     await w.run(data)
## data keys: title, rows ([label for music, label for effects]), off ("끔"),
##   btn_close, hint.
## Keys: up/down pick a row, left/right change it, interact / cancel close.
## Mouse / touch: the - + buttons, or tap the bar at the level you want.
## Changes apply (and save) right away; the effects row plays a sample sound.

signal _done

const ROW_W := 300.0
const PICK := Color(1, 1, 1, 0.08)

var _data: Dictionary = {}
var _selected := 0
var _rows: Array[PanelContainer] = []
var _bars: Array[LevelBar] = []
var _values: Array[Label] = []
var _finished := false


func run(data: Dictionary) -> void:
	_data = data
	_build()
	_select(0)
	get_viewport().gui_release_focus()  # arrows must reach _unhandled_input, not a focused button
	Dialogue.set_overlay(true)
	await _done
	Dialogue.set_overlay(false)


func _build() -> void:
	layer = 45
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	UiTheme.apply(root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_outside_input)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	var sb := UiTheme.panel_box(0.97)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var title := UiTheme.make_label(str(_data.get("title", "")), UiTheme.SIZE, UiTheme.COLOR_BORDER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var labels: Array = _data.get("rows", ["", ""])
	for i in 2:
		vb.add_child(_row(str(labels[i]), i))

	var close := Button.new()
	close.text = str(_data.get("btn_close", ""))
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(96, 24)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_finish)
	vb.add_child(close)

	var hint := UiTheme.make_label(str(_data.get("hint", "")), UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)


func _row(label: String, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(ROW_W, 0)
	row.gui_input.connect(_on_row_input.bind(index))
	_rows.append(row)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	row.add_child(hb)
	var caption := UiTheme.make_label(label, UiTheme.SIZE, UiTheme.COLOR_TEXT, true)
	caption.custom_minimum_size = Vector2(64, 0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(caption)
	hb.add_child(_step_button("-", index, -1))
	var bar := LevelBar.new()
	bar.custom_minimum_size = Vector2(120, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.picked.connect(func(level: int) -> void:
		_select(index)
		_set_level(index, level))
	hb.add_child(bar)
	_bars.append(bar)
	hb.add_child(_step_button("+", index, 1))
	var value := UiTheme.make_label("", UiTheme.SIZE, UiTheme.COLOR_WARN, true)
	value.custom_minimum_size = Vector2(40, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(value)
	_values.append(value)
	_show_level(index)
	return row


func _step_button(text: String, index: int, delta: int) -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta("sfx_off", true)  # the window plays its own sound
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(24, 22)
	b.pressed.connect(func() -> void:
		_select(index)
		_change(index, delta))
	return b


# ---------------------------------------------------------------- behaviour
func _level(index: int) -> int:
	return Sound.music_volume if index == 0 else Sound.sfx_volume


func _change(index: int, delta: int) -> void:
	_set_level(index, _level(index) + delta)


func _set_level(index: int, level: int) -> void:
	level = clampi(level, 0, Sound.VOLUME_STEPS)
	if index == 0:
		Sound.set_music_volume(level)
	else:
		Sound.set_sfx_volume(level)
	_show_level(index)
	Sound.play("select")  # at the new effects level: a sample of how loud it is


func _show_level(index: int) -> void:
	var level := _level(index)
	_bars[index].level = level
	_bars[index].queue_redraw()
	_values[index].text = str(_data.get("off", "")) if level == 0 else "%d%%" % (level * 100 / Sound.VOLUME_STEPS)


func _select(index: int) -> void:
	_selected = clampi(index, 0, _rows.size() - 1)
	for i in _rows.size():
		var on := i == _selected
		var sb := StyleBoxFlat.new()
		sb.bg_color = PICK if on else Color(0, 0, 0, 0)
		sb.border_color = UiTheme.COLOR_ACCENT if on else Color(0, 0, 0, 0)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		sb.set_content_margin_all(4)
		_rows[i].add_theme_stylebox_override("panel", sb)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	Sound.play("cancel")
	hide()
	_done.emit()


func _on_row_input(event: InputEvent, index: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_select(index)


func _on_outside_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("move_up"):
		_select(_selected - 1)
	elif event.is_action_pressed("move_down"):
		_select(_selected + 1)
	elif event.is_action_pressed("move_left", true):
		_change(_selected, -1)
	elif event.is_action_pressed("move_right", true):
		_change(_selected, 1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("cancel"):
		_finish()
	elif event is InputEventKey or event is InputEventAction:
		pass  # swallow other keys while the window is up
	else:
		return
	get_viewport().set_input_as_handled()


## VOLUME_STEPS blocks, filled up to the level; tap or drag to set it.
class LevelBar:
	extends Control
	signal picked(level: int)
	var level := 0

	func _draw() -> void:
		var n := Sound.VOLUME_STEPS
		var w := size.x / n
		for i in n:
			var r := Rect2(i * w + 1.0, 0.0, w - 2.0, size.y)
			draw_rect(r, UiTheme.COLOR_ACCENT if i < level else Color(1, 1, 1, 0.12))
			draw_rect(r, Color(0, 0, 0, 0.5), false, 1.0)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		var mm := event as InputEventMouseMotion
		var x := -1.0
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			x = mb.position.x
		elif mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			x = mm.position.x
		if x < 0.0:
			return
		var lv := clampi(ceili(x / size.x * Sound.VOLUME_STEPS), 0, Sound.VOLUME_STEPS)
		if x < size.x / Sound.VOLUME_STEPS * 0.35:
			lv = 0  # the left edge of the first block turns it off
		if lv != level:
			picked.emit(lv)
		accept_event()
