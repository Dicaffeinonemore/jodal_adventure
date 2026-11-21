extends Control
## Title: "화면을 터치해서 출근하기". The first tap/key is also the user gesture the
## browser needs before it allows fullscreen and audio, so the music starts here.

## Background: one still (tools/ref/opening-screen.png, title and "Press Start" drawn in)
## cut into layers by tools/make_title_anim.py: assets/title/*.png, positions and
## animation numbers in title_art.gd. The three characters hop in turn, the "!" marks pop,
## the title words wave, "Press Start" blinks and a shine sweeps the windows.
## docs/title_anim.gif is the same animation; _process() mirrors animate() in the tool.

const TitleArt := preload("res://scripts/ui/title_art.gd")
const ART := "res://assets/title/"
const SHINE_SHADER := """
shader_type canvas_item;
uniform vec2 tex_size;
uniform float band = -100000.0;
uniform float width = 55.0;
uniform float slope = 0.5;
uniform float strength = 0.55;
void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 p = UV * tex_size;
	float d = (p.x + slope * p.y - band) / width;
	COLOR = vec4(1.0, 1.0, 1.0, a * strength * exp(-d * d));
}
"""

var _prompt: Label
var _buttons: VBoxContainer
var _started := false
var _t := 0.0
var _blur: Sprite2D
var _stage: Node2D
var _chars: Array[Sprite2D] = []
var _marks: Array[Sprite2D] = []
var _glyphs: Array[Sprite2D] = []
var _press: Sprite2D
var _shine: ShaderMaterial
var _sound_btn: Button


func _ready() -> void:
	GameState.reset_input_locks()
	UiTheme.apply(self)
	if Sound.unlocked:  # back from the game: the browser already allows audio
		Sound.play_bgm("home")
	_blur = Sprite2D.new()
	_blur.texture = _tex("bg_blur")
	_blur.centered = false
	_blur.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_blur)

	_stage = Node2D.new()
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # painted art, not a pixel grid
	add_child(_stage)
	_layer("bg", Vector2.ZERO)
	var glass := _layer(str(TitleArt.GLASS["file"]), TitleArt.GLASS["pos"])
	var sh := Shader.new()
	sh.code = SHINE_SHADER
	_shine = ShaderMaterial.new()
	_shine.shader = sh
	_shine.set_shader_parameter("tex_size", TitleArt.GLASS["size"])
	_shine.set_shader_parameter("width", TitleArt.SHINE_WIDTH)
	_shine.set_shader_parameter("slope", TitleArt.SHINE_SLOPE)
	_shine.set_shader_parameter("strength", TitleArt.SHINE_ALPHA)
	glass.material = _shine
	for c: Dictionary in TitleArt.CHARACTERS:
		var s := _layer(str(c["file"]), c["foot"])
		var tsize := s.texture.get_size()
		s.offset = Vector2(-tsize.x / 2.0, -tsize.y)  # origin at the feet: hop and squash from there
		_chars.append(s)
	for m: Dictionary in TitleArt.MARKS:
		var s := _layer(str(m["file"]), m["center"])
		s.centered = true
		_marks.append(s)
	for g: Dictionary in TitleArt.GLYPHS:
		_glyphs.append(_layer(str(g["file"]), g["pos"]))
	_press = _layer(str(TitleArt.PRESS["file"]), TitleArt.PRESS["pos"])

	var sub := UiTheme.make_label("2026 조달청 AI 게임·콘텐츠 공모전", UiTheme.SIZE_SMALL, Color("fbf3dc"))
	sub.add_theme_color_override("font_outline_color", Color("261e2c"))
	sub.add_theme_constant_override("outline_size", 4)
	sub.anchor_top = 1.0
	sub.anchor_bottom = 1.0
	sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sub.offset_left = 8
	sub.offset_bottom = -6
	add_child(sub)

	# Prompt and buttons in the bottom-right corner: the plaza there is empty.
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
	_process(0.0)


func _tex(file: String) -> Texture2D:
	return load(ART + file + ".png") as Texture2D


func _layer(file: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(file)
	s.centered = false
	s.position = pos
	_stage.add_child(s)
	return s


## Keep the entire illustration visible; the blurred backdrop fills any spare space.
func _layout() -> void:
	var view := get_viewport_rect().size
	var art: Vector2 = TitleArt.SIZE
	var s := minf(view.x / art.x, view.y / art.y)
	_stage.scale = Vector2(s, s)
	_stage.position = ((view - art * s) / 2.0).round()
	var bt := _blur.texture.get_size()
	var bs := maxf(view.x / bt.x, view.y / bt.y)
	_blur.scale = Vector2(bs, bs)
	_blur.position = ((view - bt * bs) / 2.0).round()


## 0 on the ground .. 1 at the top, two hops per PERIOD (hop() in the tool).
func _hop(phase: float) -> float:
	return absf(sin(PI * (2.0 * _t / TitleArt.PERIOD + phase)))


func _process(delta: float) -> void:
	_t += delta
	for i in _chars.size():
		var c: Dictionary = TitleArt.CHARACTERS[i]
		var h := _hop(float(c["phase"]))
		var squash: float = TitleArt.SQUASH * pow(1.0 - h, 4.0)
		_chars[i].position = (c["foot"] as Vector2) + Vector2(0.0, -float(c["amp"]) * h)
		_chars[i].scale = Vector2(1.0 + squash, 1.0 - squash)
	for i in _marks.size():
		var who: int = TitleArt.MARKS[i]["owner"]
		var ms := 1.0 + 0.25 * _hop(float(TitleArt.CHARACTERS[who]["phase"]))
		_marks[i].scale = Vector2(ms, ms)
	for k in _glyphs.size():
		var base: Vector2 = TitleArt.GLYPHS[k]["pos"]
		_glyphs[k].position.y = base.y - TitleArt.TITLE_WAVE * sin(TAU * _t / TitleArt.PERIOD - k * TitleArt.TITLE_STAGGER)
	var blink_on := fmod(_t, TitleArt.PRESS_CYCLE) < TitleArt.PRESS_ON
	_press.visible = not _started and blink_on
	if not _started:
		_prompt.modulate.a = 1.0 if blink_on else 0.4
	# Shine: sweeps for SHINE_TIME of every PERIOD (shine_band() in the tool).
	var p := fmod(_t, TitleArt.PERIOD) / (TitleArt.PERIOD * TitleArt.SHINE_TIME)
	var gsize: Vector2 = TitleArt.GLASS["size"]
	var w: float = TitleArt.SHINE_WIDTH
	var band := -w * 2.0 + p * (gsize.x + TitleArt.SHINE_SLOPE * gsize.y + w * 4.0) if p <= 1.0 else -100000.0
	_shine.set_shader_parameter("band", band)


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
