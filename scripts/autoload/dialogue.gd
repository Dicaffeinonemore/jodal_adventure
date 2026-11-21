extends CanvasLayer
## Dialogue box, choices and toasts. Built in code so there is no scene to keep
## in sync. Usage from any script:
##     await Dialogue.say("나르미", ["첫 줄", "둘째 줄"])
##     var i: int = await Dialogue.choose("김 팀장", "어떻게 할까?", ["예", "아니요"])
##     Dialogue.toast("피로도 -15")
##     await Dialogue.say("나르미", lines, [{"texture": tex, "title": "계약보증금"}, {}])
## The optional third argument puts a picture window in the middle of the screen,
## one entry per line ({} = no picture for that line). Used for 조달 상식 (Story._tip).
## Advance with the interact action (Space/Enter/Z, touch A) or by tapping the box.
## Look: a cream speech bubble with a dark outline and a dark name tag.
##
## Full-screen windows (나라장터 PC, cafeteria meal) call set_overlay(true/false) so
## touch controls, the HUD menu bar and the objective arrow step aside.

signal opened
signal closed
signal _advanced
signal _chosen(index: int)
signal _typed
signal overlay_changed(open: bool)

const CHARS_PER_SEC := 45.0
const DEFAULT_NAME_COLOR := Color("e8d9a8")
const BUBBLE := Color("fbf3dc")
const BUBBLE_TEXT := Color("2e2636")
const INK := Color("261e2c")

## Set by Story so speakers get their own name color.
var name_colors: Dictionary = {}
var is_open := false
var overlay_open := false

var _root: Control
var _panel: PanelContainer
var _name_label: Label
var _name_tag: PanelContainer
var _text: Label
var _hint: Label
var _choices: VBoxContainer
var _toast_box: VBoxContainer
var _pic_root: Control
var _pic_frame: PanelContainer
var _pic_title: Label
var _pic_rect: TextureRect
var _pic_tween: Tween

var _typing := false
var _blip_at := 0  # next character that makes a typing blip
var _choice_ready := false  # skip the select sound for the first, automatic focus
var _waiting := false
var _shown := 0.0
var _total := 0
var _rate := 1.0  # text length / visible length (UiTheme.keep_words adds invisible joiners)
var _blink := 0.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UiTheme.apply(_root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 16
	_panel.offset_right = -16
	_panel.offset_top = -86
	_panel.offset_bottom = -8
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = BUBBLE
	bubble.border_color = INK
	bubble.set_border_width_all(2)
	bubble.set_corner_radius_all(6)
	bubble.content_margin_left = 10
	bubble.content_margin_right = 10
	bubble.content_margin_top = 4
	bubble.content_margin_bottom = 4
	bubble.shadow_color = Color(0, 0, 0, 0.25)
	bubble.shadow_offset = Vector2(0, 2)
	bubble.shadow_size = 1
	_panel.add_theme_stylebox_override("panel", bubble)
	_root.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_panel.add_child(vb)
	_name_tag = PanelContainer.new()
	_name_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tag := StyleBoxFlat.new()
	tag.bg_color = INK
	tag.set_corner_radius_all(3)
	tag.content_margin_left = 5
	tag.content_margin_right = 5
	tag.content_margin_top = 0
	tag.content_margin_bottom = 1
	_name_tag.add_theme_stylebox_override("panel", tag)
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_name_tag)
	_name_label = UiTheme.make_label("", UiTheme.SIZE, DEFAULT_NAME_COLOR, true)
	_name_tag.add_child(_name_label)
	_text = UiTheme.make_label("", UiTheme.SIZE, BUBBLE_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_text)

	_hint = UiTheme.make_label("▼", UiTheme.SIZE_SMALL, INK)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -30
	_hint.offset_top = -24
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)

	_choices = VBoxContainer.new()
	_choices.anchor_left = 1.0
	_choices.anchor_right = 1.0
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices.offset_right = -24
	_choices.offset_bottom = -94
	_choices.add_theme_constant_override("separation", 4)
	_root.add_child(_choices)

	_toast_box = VBoxContainer.new()
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.offset_top = 50  # below the HUD top bar and objective
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_toast_box)

	_build_picture()

	_panel.hide()
	_hint.hide()
	_choices.hide()


func _process(delta: float) -> void:
	if _typing:
		_shown += delta * CHARS_PER_SEC * _rate
		_text.visible_characters = int(_shown)
		if int(_shown) >= _blip_at:
			_blip_at = int(_shown) + roundi(3 * _rate)
			Sound.play("blip", 0.05)
		if int(_shown) >= _total:
			_finish_typing()
	if _waiting:
		_blink += delta
		_hint.visible = fmod(_blink, 0.8) < 0.5


# ------------------------------------------------------------------ public API
func say(speaker: String, lines: Array, pictures: Array = []) -> void:
	_open()
	for i in lines.size():
		_set_speaker(speaker)
		var pic: Dictionary = {}
		if i < pictures.size() and pictures[i] is Dictionary:
			pic = pictures[i]
		_show_picture(pic)
		await _type(str(lines[i]))
		_waiting = true
		_blink = 0.0
		await _advanced
		_waiting = false
		_hint.hide()
	_close()


func choose(speaker: String, prompt: String, options: Array) -> int:
	_open()
	_set_speaker(speaker)
	await _type(prompt)
	for child in _choices.get_children():
		child.queue_free()
	for i in options.size():
		var b := Button.new()
		b.text = str(options[i])
		b.custom_minimum_size = Vector2(120, 22)
		b.pressed.connect(_on_choice.bind(i))
		b.focus_entered.connect(_on_choice_focus)
		_choices.add_child(b)
	_choices.show()
	_choice_ready = false
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()
	_choice_ready = true
	var index: int = await _chosen
	_choices.hide()
	for child in _choices.get_children():
		child.queue_free()
	_close()
	return index


## Full-screen windows report themselves here (see the header).
func set_overlay(open: bool) -> void:
	if overlay_open == open:
		return
	overlay_open = open
	if open:
		GameState.lock_input()
	else:
		GameState.unlock_input()
	overlay_changed.emit(open)


## Short non-blocking message at the top of the screen.
func toast(text: String, color: Color = Color("f4f1e8")) -> void:
	if color == UiTheme.COLOR_BAD:
		Sound.play("bad")
	elif color == UiTheme.COLOR_WARN:
		Sound.play("warn")
	elif color != UiTheme.COLOR_DIM:
		Sound.play("pop")
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.85))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.make_label(text, UiTheme.SIZE, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_toast_box.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ internals
func _open() -> void:
	if is_open:
		return
	is_open = true
	GameState.lock_input()
	_panel.show()
	opened.emit()


func _close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.hide()
	_hint.hide()
	_hide_picture()
	GameState.unlock_input()
	closed.emit()


# Picture window: dims the screen and shows a framed picture with a title bar,
# centered in the space above the dialogue box. Sits under the box (same layer),
# and a tap anywhere on it advances the dialogue like a tap on the box.
func _build_picture() -> void:
	_pic_root = Control.new()
	_pic_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pic_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_pic_root.gui_input.connect(_on_panel_input)
	_root.add_child(_pic_root)
	_root.move_child(_pic_root, 0)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic_root.add_child(dim)

	_pic_frame = PanelContainer.new()
	_pic_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centered on the free space above the box (box top = bottom - 86).
	_pic_frame.anchor_left = 0.5
	_pic_frame.anchor_right = 0.5
	_pic_frame.anchor_top = 0.5
	_pic_frame.anchor_bottom = 0.5
	_pic_frame.offset_top = -43
	_pic_frame.offset_bottom = -43
	_pic_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pic_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := StyleBoxFlat.new()
	box.bg_color = INK
	box.border_color = BUBBLE
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(4)
	box.content_margin_top = 2
	box.shadow_color = Color(0, 0, 0, 0.4)
	box.shadow_offset = Vector2(0, 3)
	box.shadow_size = 2
	_pic_frame.add_theme_stylebox_override("panel", box)
	_pic_root.add_child(_pic_frame)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic_frame.add_child(vb)
	_pic_title = UiTheme.make_label("", UiTheme.SIZE, Color("ffd866"), true)
	_pic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_pic_title)
	_pic_rect = TextureRect.new()
	_pic_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_pic_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # painted art, not a pixel grid
	_pic_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_pic_rect)
	_root.resized.connect(_fit_picture)
	_pic_root.hide()


func _show_picture(pic: Dictionary) -> void:
	var tex: Texture2D = pic.get("texture")
	if tex == null:
		_hide_picture()
		return
	var first := not _pic_root.visible
	if not first and tex == _pic_rect.texture:
		return
	_pic_rect.texture = tex
	_pic_title.text = str(pic.get("title", ""))
	_pic_title.visible = _pic_title.text != ""
	_fit_picture()
	_pic_root.show()
	if _pic_tween:
		_pic_tween.kill()
	_pic_tween = create_tween()
	if first:
		_pic_root.modulate.a = 0.0
		_pic_frame.modulate.a = 1.0
		_pic_tween.tween_property(_pic_root, "modulate:a", 1.0, 0.18)
		Sound.play("pop")
	else:
		_pic_frame.modulate.a = 0.0
		_pic_tween.tween_property(_pic_frame, "modulate:a", 1.0, 0.18)


func _hide_picture() -> void:
	if _pic_tween:
		_pic_tween.kill()
		_pic_tween = null
	_pic_root.hide()
	_pic_rect.texture = null


## Largest size that keeps the picture's aspect, fits above the box with a margin
## and leaves room for the title bar. Called again when the window is resized.
func _fit_picture() -> void:
	var tex := _pic_rect.texture
	if tex == null:
		return
	var view := _root.size
	var aspect := float(tex.get_width()) / float(maxi(tex.get_height(), 1))
	var title_h := _pic_title.get_combined_minimum_size().y + 2.0 if _pic_title.visible else 0.0
	var max_h := view.y - 86.0 - 14.0 - title_h - 10.0  # box, gaps, title, frame
	var max_w := view.x - 48.0
	var h := maxf(minf(max_h, max_w / aspect), 40.0)
	_pic_rect.custom_minimum_size = Vector2(roundf(h * aspect), roundf(h))
	var fs := _pic_frame.get_combined_minimum_size()
	_pic_frame.offset_left = -roundf(fs.x / 2.0)
	_pic_frame.offset_right = _pic_frame.offset_left + fs.x
	_pic_frame.offset_top = -43.0 - roundf(fs.y / 2.0)
	_pic_frame.offset_bottom = _pic_frame.offset_top + fs.y


func _set_speaker(speaker: String) -> void:
	_name_label.text = speaker
	_name_tag.visible = speaker != ""
	var c: Color = name_colors.get(speaker, DEFAULT_NAME_COLOR)
	_name_label.add_theme_color_override("font_color", c)


func _type(text: String) -> void:
	var plain := text.length()
	text = UiTheme.keep_words(text)  # wrap at spaces only
	_rate = float(text.length()) / maxf(plain, 1.0)  # joiners are invisible: type them faster
	_text.text = text
	_total = text.length()
	_shown = 0.0
	_text.visible_characters = 0
	_blip_at = 0
	_typing = true
	await _typed


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_typed.emit()


func _advance() -> void:
	if _choices.visible:
		var f := get_viewport().gui_get_focus_owner()
		if f is Button:
			(f as Button).pressed.emit()
		return
	if _typing:
		_finish_typing()
	elif _waiting:
		_advanced.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_advance()


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_panel.accept_event()
			if not _choices.visible:  # with choices up, tap a choice button instead
				_advance()


func _on_choice_focus() -> void:
	if _choice_ready:
		Sound.play("select")


func _on_choice(index: int) -> void:
	_chosen.emit(index)
