extends Control
## Title: "화면을 터치해서 출근하기". The first tap/key is also the user gesture the
## browser needs before it allows fullscreen and audio, so the music starts here.

## Background: one illustration (assets/title/opening.png, 1672x941) with the title and
## "Press Start" drawn in: 나르미, the rookie and 달이 in front of the 조달청. It is shown
## whole (at most MAX_CROP cut off); a blurred copy (opening_blur.png) fills any spare
## space on screens that are not 16:9. Prompt and buttons sit in the empty bottom-right.

const ART := "res://assets/title/"
const MAX_CROP := 1.05

var _prompt: Label
var _buttons: VBoxContainer
var _started := false
var _t := 0.0
var _blur: Sprite2D
var _art: Sprite2D
var _sound_btn: Button


func _ready() -> void:
	GameState.reset_input_locks()
	UiTheme.apply(self)
	if Sound.unlocked:  # back from the game: the browser already allows audio
		Sound.play_bgm("home")
	_blur = _picture("opening_blur.png", CanvasItem.TEXTURE_FILTER_LINEAR)
	_art = _picture("opening.png", CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)  # painted art, not a pixel grid

	var sub := UiTheme.make_label("2026 조달청 AI 게임·콘텐츠 공모전", UiTheme.SIZE_SMALL, Color("fbf3dc"))
	sub.add_theme_color_override("font_outline_color", Color("261e2c"))
	sub.add_theme_constant_override("outline_size", 4)
	sub.anchor_top = 1.0
	sub.anchor_bottom = 1.0
	sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sub.offset_left = UiTheme.edge_margin() + 4.0
	sub.offset_bottom = -6
	add_child(sub)

	var bottom := VBoxContainer.new()
	bottom.anchor_left = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_right = -UiTheme.edge_margin() - 4.0
	bottom.offset_bottom = -10
	bottom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	_prompt = UiTheme.make_label("화면을 터치해서 출근하기", UiTheme.SIZE, UiTheme.COLOR_TEXT, true)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Color("261e2c"))
	_prompt.add_theme_constant_override("outline_size", 5)
	bottom.add_child(_prompt)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	bottom.add_child(_buttons)
	var new_btn := _make_button("새로 출근하기")
	new_btn.pressed.connect(_on_new)
	if GameState.has_save():
		var cont := _make_button("이어서 출근하기")
		cont.pressed.connect(_on_continue)
	_sound_btn = _make_button("소리 설정")
	_sound_btn.pressed.connect(_on_sound)
	_buttons.hide()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _picture(file: String, filter: CanvasItem.TextureFilter) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(ART + file) as Texture2D
	s.centered = false
	s.texture_filter = filter
	add_child(s)
	return s


## The illustration as large as possible with at most MAX_CROP cut off (more from the
## right and bottom: the title is top-left); the blurred copy covers the screen.
func _layout() -> void:
	var view := get_viewport_rect().size
	var art := _art.texture.get_size()
	var s := minf(maxf(view.x / art.x, view.y / art.y), minf(view.x / art.x, view.y / art.y) * MAX_CROP)
	_art.scale = Vector2(s, s)
	var spare := view - art * s
	_art.position = Vector2(spare.x * (0.5 if spare.x > 0.0 else 0.25),
			spare.y * (0.5 if spare.y > 0.0 else 0.3)).round()
	var bt := _blur.texture.get_size()
	var bs := maxf(view.x / bt.x, view.y / bt.y)
	_blur.scale = Vector2(bs, bs)
	_blur.position = ((view - bt * bs) / 2.0).round()


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
	Sound.unlocked = true
	Sound.play("confirm")
	Sound.play_bgm("home")
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
	GameState.editing_look = false
	SceneRouter.goto(SceneRouter.CHARACTER_CREATE)


func _on_sound() -> void:
	await Story.volume_settings()
	_sound_btn.grab_focus()


func _on_continue() -> void:
	if GameState.load_game():
		var spawn := {"home": "bed", "office": "entrance", "school": "arrival", "fire": "arrival",
				"clinic": "arrival", "center": "arrival", "lab": "default"}
		SceneRouter.goto_map(GameState.map_id, str(spawn.get(GameState.map_id, "default")))
	else:
		Dialogue.toast("저장 데이터를 불러오지 못했어요.", UiTheme.COLOR_BAD)
