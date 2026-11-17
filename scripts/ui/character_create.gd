extends Control
## 출입증 발급 (also the wardrobe): name + look (gender, skin, hair, outfit and colors).
## Left: animated preview (3x). Right: form. Option names live in Story.LOOK_NAMES.
##
## Mobile browsers don't reliably open the on-screen keyboard for a Godot
## LineEdit, so on touch web builds tapping the name field opens the browser's
## own prompt() instead.

const MAX_NAME := 8
const PREVIEW_SCALE := 3.0

var _name_edit: LineEdit
var _preview: CharacterVisual
const COLOR_KEYS := ["skin", "hair_color", "outfit_color"]

var _look: Dictionary = {}
var _value_labels: Dictionary = {}  # key -> Label (named options)
var _swatches: Dictionary = {}  # key -> ColorRect (color options)
var _turn_t := 0.0
var _turn_index := 0


func _ready() -> void:
	GameState.reset_input_locks()
	UiTheme.apply(self)
	var bg := ColorRect.new()
	bg.color = Color("232c4a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	if GameState.editing_look:
		_look = GameState.get_look()
	else:
		_look = {"gender": 0, "skin": 0, "hair_style": 0, "hair_color": 0, "outfit_style": 0, "outfit_color": 0}
	var title_text := "옷장" if GameState.editing_look else "출입증 발급"
	var title := UiTheme.make_label(title_text, UiTheme.SIZE_LARGE, UiTheme.COLOR_BORDER, true)
	title.position = Vector2(24, 14)
	add_child(title)

	# preview card
	var card := PanelContainer.new()
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = 40
	card.offset_top = -90
	card.custom_minimum_size = Vector2(150, 180)
	add_child(card)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(140, 170)
	card.add_child(holder)
	_preview = CharacterVisual.new()
	_preview.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	_preview.position = Vector2(70, 130)
	holder.add_child(_preview)
	var card_label := UiTheme.make_label("조달청", UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM)
	card_label.position = Vector2(8, 4)
	holder.add_child(card_label)

	# form
	var form := VBoxContainer.new()
	form.anchor_left = 0.5
	form.anchor_right = 1.0
	form.anchor_top = 0.5
	form.anchor_bottom = 0.5
	form.offset_left = -60
	form.offset_right = -32
	form.offset_top = -112
	form.add_theme_constant_override("separation", 5)
	add_child(form)

	form.add_child(UiTheme.make_label("이름 (최대 %d자)" % MAX_NAME, UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))
	_name_edit = LineEdit.new()
	_name_edit.max_length = MAX_NAME
	_name_edit.placeholder_text = "이름을 입력하세요"
	if GameState.editing_look:
		_name_edit.text = GameState.player_name
	_name_edit.custom_minimum_size = Vector2(0, 22)
	if _use_browser_prompt():
		_name_edit.editable = false
		_name_edit.gui_input.connect(_on_name_tapped)
	form.add_child(_name_edit)

	for key in GameState.LOOK_KEYS:
		form.add_child(_option_row(str(Story.LOOK_LABELS[key]), key))

	var go := Button.new()
	go.text = "이대로 할게요" if GameState.editing_look else "출근 준비 끝!"
	go.custom_minimum_size = Vector2(0, 26)
	go.pressed.connect(_on_confirm)
	form.add_child(go)

	_apply_look()


func _process(delta: float) -> void:
	# Turn the preview around every 1.2 s so all directions are visible.
	_turn_t += delta
	if _turn_t > 1.2:
		_turn_t = 0.0
		_turn_index = (_turn_index + 1) % 4
	var dirs := ["down", "left", "up", "right"]
	_preview.face(dirs[_turn_index], true)


func _option_row(label: String, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := UiTheme.make_label(label)
	l.custom_minimum_size = Vector2(56, 0)
	row.add_child(l)
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(26, 20)
	prev.pressed.connect(_change.bind(key, -1))
	row.add_child(prev)
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(76, 0)
	row.add_child(slot)
	if key in COLOR_KEYS:
		var frame := ColorRect.new()  # dark border around the swatch
		frame.color = Color("141a30")
		frame.custom_minimum_size = Vector2(42, 14)
		slot.add_child(frame)
		var swatch := ColorRect.new()
		swatch.position = Vector2(1, 1)
		swatch.size = Vector2(40, 12)
		frame.add_child(swatch)
		_swatches[key] = swatch
	else:
		var value := UiTheme.make_label("")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(value)
		_value_labels[key] = value
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(26, 20)
	next.pressed.connect(_change.bind(key, 1))
	row.add_child(next)
	return row


func _change(key: String, delta: int) -> void:
	var count := GameState.look_option_count(key)
	_look[key] = posmod(int(_look.get(key, 0)) + delta, count)
	if key == "gender":  # a fresh start that fits: hair and outfit follow the gender
		var defaults: Array = GameState.GENDER_DEFAULTS[int(_look["gender"])]
		_look["hair_style"] = int(defaults[0])
		_look["outfit_style"] = int(defaults[1])
	_apply_look()


func _apply_look() -> void:
	_preview.set_look(_look)
	for key: String in _value_labels:
		var names: Array = Story.LOOK_NAMES[key]
		(_value_labels[key] as Label).text = str(names[int(_look[key])])
	(_swatches["skin"] as ColorRect).color = GameState.SKIN_TONES[int(_look["skin"])]
	(_swatches["hair_color"] as ColorRect).color = GameState.HAIR_COLORS[int(_look["hair_color"])]
	(_swatches["outfit_color"] as ColorRect).color = GameState.OUTFIT_COLORS[int(_look["outfit_color"])]


func _use_browser_prompt() -> bool:
	return OS.has_feature("web") and GameState.is_touch_device()


func _on_name_tapped(event: InputEvent) -> void:
	var tapped := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if not tapped:
		return
	var current := _name_edit.text.replace("'", "").replace("\\", "")
	var result: Variant = JavaScriptBridge.eval(
			"window.prompt('이름을 입력하세요 (최대 %d자)', '%s') || ''" % [MAX_NAME, current], true)
	if typeof(result) == TYPE_STRING:
		_name_edit.text = _clean_name(str(result))


func _clean_name(raw: String) -> String:
	return raw.strip_edges().substr(0, MAX_NAME)


func _on_confirm() -> void:
	var player_name := _clean_name(_name_edit.text)
	if player_name.is_empty():
		Dialogue.toast("이름을 입력해 주세요.", UiTheme.COLOR_WARN)
		return
	if GameState.editing_look:
		GameState.editing_look = false
		GameState.player_name = player_name
		GameState.set_look(_look)
		GameState.save_game()
		SceneRouter.goto(SceneRouter.HOME, "wardrobe")
		return
	GameState.new_game(player_name, _look)
	GameState.save_game()
	SceneRouter.goto(SceneRouter.HOME, "bed")
