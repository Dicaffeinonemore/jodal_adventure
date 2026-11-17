extends Control
## 출입증 발급: name + look. Left: animated preview (3x). Right: form.
##
## Mobile browsers don't reliably open the on-screen keyboard for a Godot
## LineEdit, so on touch web builds tapping the name field opens the browser's
## own prompt() instead.

const MAX_NAME := 8
const PREVIEW_SCALE := 3.0

var _name_edit: LineEdit
var _preview: CharacterVisual
var _hair_style := 0
var _hair_color := 0
var _outfit_color := 0
var _value_labels: Dictionary = {}
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
		_hair_style = GameState.hair_style
		_hair_color = GameState.hair_color
		_outfit_color = GameState.outfit_color
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
	form.offset_top = -90
	form.add_theme_constant_override("separation", 8)
	add_child(form)

	form.add_child(UiTheme.make_label("이름 (최대 %d자)" % MAX_NAME, UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))
	_name_edit = LineEdit.new()
	_name_edit.max_length = MAX_NAME
	_name_edit.placeholder_text = "이름을 입력하세요"
	if GameState.editing_look:
		_name_edit.text = GameState.player_name
	_name_edit.custom_minimum_size = Vector2(0, 24)
	if _use_browser_prompt():
		_name_edit.editable = false
		_name_edit.gui_input.connect(_on_name_tapped)
	form.add_child(_name_edit)

	form.add_child(_option_row("헤어", "hair_style"))
	form.add_child(_option_row("머리색", "hair_color"))
	form.add_child(_option_row("옷 색", "outfit_color"))

	var go := Button.new()
	go.text = "이대로 할게요" if GameState.editing_look else "출근 준비 끝!"
	go.custom_minimum_size = Vector2(0, 28)
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
	prev.custom_minimum_size = Vector2(28, 22)
	prev.pressed.connect(_change.bind(key, -1))
	row.add_child(prev)
	var value := UiTheme.make_label("")
	value.custom_minimum_size = Vector2(48, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	_value_labels[key] = value
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(28, 22)
	next.pressed.connect(_change.bind(key, 1))
	row.add_child(next)
	return row


func _change(key: String, delta: int) -> void:
	match key:
		"hair_style":
			_hair_style = posmod(_hair_style + delta, GameState.HAIR_STYLE_COUNT)
		"hair_color":
			_hair_color = posmod(_hair_color + delta, GameState.HAIR_COLORS.size())
		"outfit_color":
			_outfit_color = posmod(_outfit_color + delta, GameState.OUTFIT_COLORS.size())
	_apply_look()


func _apply_look() -> void:
	_preview.set_look(_hair_style, _hair_color, _outfit_color)
	(_value_labels["hair_style"] as Label).text = "%d / %d" % [_hair_style + 1, GameState.HAIR_STYLE_COUNT]
	(_value_labels["hair_color"] as Label).text = "%d / %d" % [_hair_color + 1, GameState.HAIR_COLORS.size()]
	(_value_labels["outfit_color"] as Label).text = "%d / %d" % [_outfit_color + 1, GameState.OUTFIT_COLORS.size()]


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
		GameState.hair_style = _hair_style
		GameState.hair_color = _hair_color
		GameState.outfit_color = _outfit_color
		GameState.save_game()
		SceneRouter.goto(SceneRouter.HOME, "wardrobe")
		return
	GameState.new_game(player_name, _hair_style, _hair_color, _outfit_color)
	GameState.save_game()
	SceneRouter.goto(SceneRouter.HOME, "bed")
