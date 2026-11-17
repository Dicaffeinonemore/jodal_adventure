extends Control
## Title: "화면을 터치해서 출근하기". The first tap/key is also the user gesture the
## browser needs before it allows fullscreen and audio, so start BGM here (P1).

var _prompt: Label
var _buttons: VBoxContainer
var _started := false
var _t := 0.0


func _ready() -> void:
	GameState.reset_input_locks()
	UiTheme.apply(self)
	var bg := ColorRect.new()
	bg.color = Color("1b2440")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 10)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var sub := UiTheme.make_label("2026 조달청 AI 게임·콘텐츠 공모전", UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)
	var title := UiTheme.make_label("출근! 조달청 신입", UiTheme.SIZE_LARGE, UiTheme.COLOR_BORDER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("0d1226"))
	title.add_theme_constant_override("outline_size", 6)
	center.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	center.add_child(spacer)

	_prompt = UiTheme.make_label("화면을 터치해서 출근하기", UiTheme.SIZE, UiTheme.COLOR_TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_prompt)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	center.add_child(_buttons)
	var new_btn := _make_button("새로 출근하기")
	new_btn.pressed.connect(_on_new)
	if GameState.has_save():
		var cont := _make_button("이어서 출근하기")
		cont.pressed.connect(_on_continue)
	_buttons.hide()


func _process(delta: float) -> void:
	_t += delta
	if not _started:
		_prompt.modulate.a = 0.35 + 0.65 * absf(sin(_t * 2.5))


func _input(event: InputEvent) -> void:
	if _started:
		return
	# Pointers start on release: a touch is followed by an emulated mouse click,
	# and reacting on press would let that click hit the button that just appeared
	# under the finger ("새로 출근하기" sits where the prompt was).
	# touchend / mouseup still count as a user gesture for fullscreen.
	var started := (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed) \
		or (event is InputEventKey and (event as InputEventKey).pressed and not event.is_echo())
	if not started:
		return
	_started = true
	get_viewport().set_input_as_handled()
	# Browsers only allow fullscreen inside an input event; do it on phones only.
	if GameState.is_touch_device():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_prompt.hide()
	_buttons.show()
	(_buttons.get_child(0) as Button).grab_focus()


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 26)
	_buttons.add_child(b)
	return b


func _on_new() -> void:
	SceneRouter.goto(SceneRouter.CHARACTER_CREATE)


func _on_continue() -> void:
	if GameState.load_game():
		SceneRouter.goto(SceneRouter.OFFICE, "entrance")
	else:
		Dialogue.toast("저장 데이터를 불러오지 못했어요.", UiTheme.COLOR_BAD)
