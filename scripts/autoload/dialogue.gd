extends CanvasLayer
## Dialogue box, choices and toasts. Built in code so there is no scene to keep
## in sync. Usage from any script:
##     await Dialogue.say("나르미", ["첫 줄", "둘째 줄"])
##     var i: int = await Dialogue.choose("김 팀장", "어떻게 할까?", ["예", "아니요"])
##     Dialogue.toast("피로도 -15")
## Advance with the interact action (Space/Enter/Z, touch A) or by tapping the box.

signal opened
signal closed
signal _advanced
signal _chosen(index: int)
signal _typed

const CHARS_PER_SEC := 45.0
const DEFAULT_NAME_COLOR := Color("e8d9a8")

## Set by Story so speakers get their own name color.
var name_colors: Dictionary = {}
var is_open := false

var _root: Control
var _panel: PanelContainer
var _name_label: Label
var _text: Label
var _hint: Label
var _choices: VBoxContainer
var _toast_box: VBoxContainer

var _typing := false
var _waiting := false
var _shown := 0.0
var _total := 0
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
	_root.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)
	_name_label = UiTheme.make_label("", UiTheme.SIZE, DEFAULT_NAME_COLOR, true)
	vb.add_child(_name_label)
	_text = UiTheme.make_label("")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_text)

	_hint = UiTheme.make_label("▼", UiTheme.SIZE_SMALL, UiTheme.COLOR_BORDER)
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
	_toast_box.offset_top = 44
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_toast_box)

	_panel.hide()
	_hint.hide()
	_choices.hide()


func _process(delta: float) -> void:
	if _typing:
		_shown += delta * CHARS_PER_SEC
		_text.visible_characters = int(_shown)
		if int(_shown) >= _total:
			_finish_typing()
	if _waiting:
		_blink += delta
		_hint.visible = fmod(_blink, 0.8) < 0.5


# ------------------------------------------------------------------ public API
func say(speaker: String, lines: Array) -> void:
	_open()
	for line: Variant in lines:
		_set_speaker(speaker)
		await _type(str(line))
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
		_choices.add_child(b)
	_choices.show()
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()
	var index: int = await _chosen
	_choices.hide()
	for child in _choices.get_children():
		child.queue_free()
	_close()
	return index


## Short non-blocking message at the top of the screen.
func toast(text: String, color: Color = Color("f4f1e8")) -> void:
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
	GameState.unlock_input()
	closed.emit()


func _set_speaker(speaker: String) -> void:
	_name_label.text = speaker
	_name_label.visible = speaker != ""
	var c: Color = name_colors.get(speaker, DEFAULT_NAME_COLOR)
	_name_label.add_theme_color_override("font_color", c)


func _type(text: String) -> void:
	_text.text = text
	_total = text.length()
	_shown = 0.0
	_text.visible_characters = 0
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


func _on_choice(index: int) -> void:
	_chosen.emit(index)
