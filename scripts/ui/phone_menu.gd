class_name PhoneMenu
extends CanvasLayer
## Esc menu as the player's smartphone: a home screen with app icons.
## Story builds every string (all player-facing text stays in story.gd):
##     var phone := PhoneMenu.new()
##     get_tree().root.add_child(phone)
##     var id: String = await phone.run(data)   # app id, or "" when closed
## data keys: clock (big clock text), date (line under it), status (top-left text),
##   battery (0-100, shown top right), battery_label, apps ([{id, label}], icon = id in
##   APP_ICONS), note_title + note (notification card under the apps, e.g. the objective),
##   hint (shown under the phone).
## Keys: arrows move, interact opens, cancel closes. Mouse / touch: tap an app to open it,
## tap the home button or outside the phone to close.

signal _done(id: String)

const APP_ICONS := ["task", "bag", "growth", "save", "sound", "title"]  # = tools/gen_placeholders.py PHONE_APPS
const ICON_SHEET := "res://assets/sprites/placeholder/phone_apps.png"
const ICON := 24
const COLS := 3
const BODY := Color("23202c")
const INK := Color("261e2c")
const PICK := Color(1, 1, 1, 0.35)
const PHONE_SIZE := Vector2(156, 300)
const SCREEN_INSET := Vector2(8, 22)  # left/right, top/bottom bezel

var _data: Dictionary = {}
var _apps: Array = []
var _cells: Array[Control] = []
var _selected := 0
var _finished := false
var _phone: Control


func run(data: Dictionary) -> String:
	_data = data
	_apps = data.get("apps", [])
	_build()
	_select(0, false)
	Dialogue.set_overlay(true)
	Sound.play("confirm")
	var id: String = await _done
	Dialogue.set_overlay(false)
	return id


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
	dim.gui_input.connect(_on_outside_input)
	root.add_child(dim)

	var view := root.get_viewport().get_visible_rect().size
	var size := PHONE_SIZE
	if size.y > view.y - 24:  # very wide screens: keep the phone inside
		size = PHONE_SIZE * ((view.y - 24) / PHONE_SIZE.y)
	_phone = Control.new()
	_phone.size = size
	_phone.position = ((view - size) / 2.0).round()
	_phone.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_phone)

	var body := Panel.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", _box(BODY, INK, 2, 18))
	_phone.add_child(body)
	var speaker := ColorRect.new()  # earpiece
	speaker.color = Color("4a4658")
	speaker.size = Vector2(28, 3)
	speaker.position = Vector2((size.x - 28) / 2.0, 9).round()
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.add_child(speaker)

	var screen := Wallpaper.new()
	screen.position = Vector2(SCREEN_INSET.x, SCREEN_INSET.y)
	screen.size = size - Vector2(SCREEN_INSET.x * 2, SCREEN_INSET.y * 2)
	screen.clip_contents = true
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.add_child(screen)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6
	vb.offset_right = -6
	vb.offset_top = 3
	vb.offset_bottom = -4
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(vb)

	# status bar: text left, battery right
	var status := HBoxContainer.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(status)
	status.add_child(_label(str(_data.get("status", "")), UiTheme.SIZE_SMALL, Color.WHITE))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(sp)
	status.add_child(_label(str(_data.get("battery_label", "")), UiTheme.SIZE_SMALL, Color.WHITE))
	var bat := Battery.new()
	bat.level = clampf(float(_data.get("battery", 100)) / 100.0, 0.0, 1.0)
	bat.custom_minimum_size = Vector2(16, 8)
	bat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(bat)

	# clock widget
	var clock := _label(str(_data.get("clock", "")), UiTheme.SIZE_LARGE, Color.WHITE, true)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2, 0.6))
	clock.add_theme_constant_override("outline_size", 3)
	vb.add_child(clock)
	var date := _label(str(_data.get("date", "")), UiTheme.SIZE_SMALL, Color.WHITE)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2, 0.6))
	date.add_theme_constant_override("outline_size", 3)
	vb.add_child(date)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(gap)

	# app grid
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(grid)
	var sheet := load(ICON_SHEET) as Texture2D
	for i in _apps.size():
		var app: Dictionary = _apps[i]
		grid.add_child(_app_cell(app, i, sheet))

	# notification card (current objective)
	if str(_data.get("note", "")) != "":
		var gap2 := Control.new()
		gap2.custom_minimum_size = Vector2(0, 4)
		gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(gap2)
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := _box(Color(1, 1, 1, 0.82), INK, 1, 5)
		sb.set_content_margin_all(4)
		card.add_theme_stylebox_override("panel", sb)
		vb.add_child(card)
		var cvb := VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 0)
		cvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cvb)
		cvb.add_child(_label(str(_data.get("note_title", "")), UiTheme.SIZE_SMALL, Color("23489a"), true))
		var note := _label(UiTheme.keep_words(str(_data["note"])), UiTheme.SIZE_SMALL, Color("2e2636"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(size.x - SCREEN_INSET.x * 2 - 22, 0)
		cvb.add_child(note)

	# home button (closes)
	var home := Button.new()
	home.set_meta("sfx_off", true)
	home.focus_mode = Control.FOCUS_NONE
	home.size = Vector2(22, 12)
	home.position = Vector2((size.x - 22) / 2.0, size.y - SCREEN_INSET.y + 5).round()
	home.add_theme_stylebox_override("normal", _box(Color("3a3646"), Color("6a6680"), 1, 6))
	home.add_theme_stylebox_override("hover", _box(Color("4a4658"), Color("8a86a0"), 1, 6))
	home.add_theme_stylebox_override("pressed", _box(Color("2a2636"), Color("6a6680"), 1, 6))
	home.pressed.connect(func() -> void: _finish(""))
	_phone.add_child(home)

	var hint := _label(str(_data.get("hint", "")), UiTheme.SIZE_SMALL, UiTheme.COLOR_TEXT)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -14
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	# slide up from below
	var end_y := _phone.position.y
	_phone.position.y = view.y
	var tw := create_tween()
	tw.tween_property(_phone, "position:y", end_y, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _app_cell(app: Dictionary, index: int, sheet: Texture2D) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(42, 40)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.gui_input.connect(_on_cell_input.bind(index))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(vb)
	var icon := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = sheet
	var k := maxi(0, APP_ICONS.find(str(app.get("id", ""))))
	at.region = Rect2(k * ICON, 0, ICON, ICON)
	icon.texture = at
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon)
	var l := _label(str(app.get("label", "")), UiTheme.SIZE_SMALL, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	vb.add_child(l)
	_cells.append(cell)
	return cell


# ---------------------------------------------------------------- behaviour
func _select(index: int, sound: bool = true) -> void:
	if _cells.is_empty():
		return
	var before := _selected
	_selected = clampi(index, 0, _cells.size() - 1)
	if sound and _selected != before:
		Sound.play("select")
	for i in _cells.size():
		var on := i == _selected
		_cells[i].add_theme_stylebox_override("panel", _box(PICK if on else Color(0, 0, 0, 0),
				Color.WHITE if on else Color(0, 0, 0, 0), 1 if on else 0, 6))


func _move(dx: int, dy: int) -> void:
	var n := _cells.size()
	var col := _selected % COLS
	var row := floori(_selected / float(COLS))
	if dx != 0:
		var c := clampi(col + dx, 0, COLS - 1)
		_select(mini(row * COLS + c, n - 1))
	else:
		var r := row + dy
		if r < 0 or r * COLS >= n:
			return
		_select(mini(r * COLS + col, n - 1))


func _finish(id: String) -> void:
	if _finished:
		return
	_finished = true
	Sound.play("confirm" if id != "" else "cancel")
	hide()
	_done.emit(id)


func _open_selected() -> void:
	if _selected < _apps.size():
		_finish(str((_apps[_selected] as Dictionary).get("id", "")))


func _on_cell_input(event: InputEvent, index: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_select(index, false)
		_open_selected()


func _on_outside_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_finish("")


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("move_left"):
		_move(-1, 0)
	elif event.is_action_pressed("move_right"):
		_move(1, 0)
	elif event.is_action_pressed("move_up"):
		_move(0, -1)
	elif event.is_action_pressed("move_down"):
		_move(0, 1)
	elif event.is_action_pressed("interact"):
		_open_selected()
	elif event.is_action_pressed("cancel"):
		_finish("")
	elif event is InputEventKey or event is InputEventAction:
		pass  # swallow other keys (menu shortcuts) while the phone is up
	else:
		return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- helpers
func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := UiTheme.make_label(text, size, color, bold)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(2)
	return sb


## Home-screen wallpaper: a sky gradient with soft hills (drawn, no texture).
class Wallpaper:
	extends Control

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var steps := 12
		for i in steps:
			var t := float(i) / steps
			var c := Color("6fa8ff").lerp(Color("ffc9a8"), t)
			draw_rect(Rect2(0, h * t, w, h / steps + 1), c)
		draw_circle(Vector2(w * 0.78, h * 0.62), w * 0.55, Color("8fd06a"))
		draw_circle(Vector2(w * 0.15, h * 0.75), w * 0.5, Color("7cc35a"))
		draw_rect(Rect2(0, h * 0.82, w, h * 0.18), Color("6fb24f"))


## Battery icon; level 0-1 (Story passes 100 - fatigue).
class Battery:
	extends Control
	var level := 1.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size - Vector2(2, 0))
		draw_rect(r, Color.WHITE, false, 1.0)
		draw_rect(Rect2(r.end.x, size.y * 0.3, 2, size.y * 0.4), Color.WHITE)
		var fill := Color("7ed37e") if level > 0.5 else (Color("f2c14e") if level > 0.2 else Color("ef6b5b"))
		draw_rect(Rect2(2, 2, (r.size.x - 4) * level, r.size.y - 4), fill)
