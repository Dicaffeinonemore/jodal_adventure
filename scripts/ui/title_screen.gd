extends Control
## Title: "화면을 터치해서 출근하기". The first tap/key is also the user gesture the
## browser needs before it allows fullscreen and audio, so the music starts here.

## The town at 2x (assets title_town.png, 320x180): destinations on both sides and the
## 조달청 in the middle, with the title as a banner on its roof. Clouds and a delivery
## truck move; the cast stands at the entrance. Image coordinates go through _stage.

const SPRITES := "res://assets/sprites/placeholder/"
const TOWN := Vector2(320, 180)
const SIGN_CENTER := Vector2(160, 104)  # sign plate on the 조달청 building
const ROOF_Y := 58.0

var _prompt: Label
var _buttons: VBoxContainer
var _started := false
var _t := 0.0
var _cast: Array[AnimatedSprite2D] = []
var _stage: Node2D
var _clouds: Array[Sprite2D] = []
var _truck: Sprite2D
var _banner: VBoxContainer
var _sign: Label
var _sound_btn: Button


func _ready() -> void:
	GameState.reset_input_locks()
	UiTheme.apply(self)
	if Sound.unlocked:  # back from the game: the browser already allows audio
		Sound.play_bgm("home")
	var sky := ColorRect.new()
	sky.color = Color("78bef8")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	_stage = Node2D.new()
	add_child(_stage)
	for i in 4:
		var c := Sprite2D.new()
		c.texture = load(SPRITES + "cloud.png") as Texture2D
		c.centered = false
		c.position = Vector2(i * 90.0 + 10.0, 8.0 + (i % 2) * 14.0)
		_stage.add_child(c)
		_clouds.append(c)
	var town := Sprite2D.new()
	town.texture = load(SPRITES + "title_town.png") as Texture2D
	town.centered = false
	_stage.add_child(town)
	_truck = Sprite2D.new()
	_truck.texture = load(SPRITES + "car_player.png") as Texture2D
	_truck.rotation = PI / 2.0
	_truck.position = Vector2(-20, 160)
	_stage.add_child(_truck)
	for i in 3:  # the cast at the entrance
		var id: String = ["narumi", "team_leader", "dari"][i]
		var a := AnimatedSprite2D.new()
		a.sprite_frames = SpriteUtil.idle_frames(load(Story.npc_sprite(id)) as Texture2D)
		a.offset = CharacterVisual.FEET_OFFSET
		a.position = Vector2(140 + i * 20, 150)
		a.play("idle")
		a.frame = i % 2
		_stage.add_child(a)
		_cast.append(a)

	_sign = UiTheme.make_label("조달청", UiTheme.SIZE, Color.WHITE, true)
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_sign)

	# title banner on the roof
	_banner = VBoxContainer.new()
	_banner.add_theme_constant_override("separation", 0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var sub := UiTheme.make_label("2026 조달청 AI 게임·콘텐츠 공모전", UiTheme.SIZE_SMALL, Color("fbf3dc"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color("261e2c"))
	sub.add_theme_constant_override("outline_size", 4)
	_banner.add_child(sub)
	var board := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fbf3dc")
	sb.border_color = Color("261e2c")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_offset = Vector2(0, 3)
	sb.shadow_size = 1
	board.add_theme_stylebox_override("panel", sb)
	_banner.add_child(board)
	var title := UiTheme.make_label("출근! 조달청 신입", UiTheme.SIZE_LARGE, Color("23489a"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(title)

	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_bottom = -10
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
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


## Covers the screen with the town (scale >= 2) and lines the labels up with it.
func _layout() -> void:
	var view := get_viewport_rect().size
	var s := maxf(view.x / TOWN.x, view.y / TOWN.y)
	_stage.scale = Vector2(s, s)
	_stage.position = ((view - TOWN * s) / 2.0).round()
	_sign.reset_size()
	_sign.position = (_to_screen(SIGN_CENTER) - _sign.size / 2.0).round()
	_banner.reset_size()
	_banner.position = (Vector2(_to_screen(Vector2(160, 0)).x, _to_screen(Vector2(0, ROOF_Y)).y) 			- Vector2(_banner.size.x / 2.0, _banner.size.y)).round()


func _to_screen(p: Vector2) -> Vector2:
	return _stage.position + p * _stage.scale


func _process(delta: float) -> void:
	_t += delta
	for i in _clouds.size():
		var c := _clouds[i]
		c.position.x += delta * (4.0 + i * 1.5)
		if c.position.x > TOWN.x + 10.0:
			c.position.x = -40.0
	_truck.position.x += delta * 45.0
	if _truck.position.x > TOWN.x + 30.0:
		_truck.position.x = -30.0
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
