class_name ProcurementPC
extends CanvasLayer
## 나라장터 PC: a monitor window over the map where the player picks a vendor.
## Story builds every string (all player-facing text stays in story.gd):
##     var pc := ProcurementPC.new()
##     get_tree().root.add_child(pc)
##     var index: int = await pc.run(data)   # vendor index, or -1 for "later"
## data keys: title, subtitle, crumb, info_title, info ([[label, value], ...]), tags ([text, ...]),
##   formula, list_title, vendors ([{name, price, sale: bool, sale_label, quality: int, desc, note}]),
##   required (int, marks the bar), quality_label ("품질 %d"), footer, btn_ok, btn_later,
##   confirm ([text per vendor]), btn_yes, btn_no.
## Keys: up/down pick, interact = contract (asks to confirm), cancel = back / close.
## Mouse / touch: tap a row to pick it, tap it again (or the button) to contract.

signal _done(index: int)

const INK := Color("261e2c")
const SCREEN := Color("eef3f8")
const TEXT := Color("2a2a38")
const TEXT_DIM := Color("6a6f80")
const NAVY := Color("23489a")
const CARD := Color("ffffff")
const CARD_LINE := Color("c3cddb")
const PICK := Color("2f7be6")
const PICK_BG := Color("e3eeff")
const SALE := Color("e0483c")
const GOOD := Color("3aa45c")
const MONITOR_SIZE := Vector2(588, 318)

var _data: Dictionary = {}
var _rows: Array[PanelContainer] = []
var _selected := 0
var _confirm: Control
var _confirm_text: Label
var _finished := false


func run(data: Dictionary) -> int:
	_data = data
	_build()
	_select(0)
	Dialogue.set_overlay(true)
	var index: int = await _done
	Dialogue.set_overlay(false)
	return index


# ---------------------------------------------------------------- build
func _build() -> void:
	layer = 40
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	UiTheme.apply(root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	# monitor: bezel, screen, stand
	var monitor := Control.new()
	monitor.anchor_left = 0.5
	monitor.anchor_right = 0.5
	monitor.anchor_top = 0.5
	monitor.anchor_bottom = 0.5
	monitor.offset_left = -MONITOR_SIZE.x / 2.0
	monitor.offset_right = MONITOR_SIZE.x / 2.0
	monitor.offset_top = -MONITOR_SIZE.y / 2.0 - 10
	monitor.offset_bottom = MONITOR_SIZE.y / 2.0 - 10
	root.add_child(monitor)
	var neck := ColorRect.new()
	neck.color = Color("3a3d4e")
	neck.position = Vector2(MONITOR_SIZE.x / 2.0 - 18, MONITOR_SIZE.y - 2)
	neck.size = Vector2(36, 12)
	monitor.add_child(neck)
	var foot := Panel.new()
	foot.add_theme_stylebox_override("panel", _box(Color("4a4e62"), INK, 1, 3))
	foot.position = Vector2(MONITOR_SIZE.x / 2.0 - 56, MONITOR_SIZE.y + 8)
	foot.size = Vector2(112, 8)
	monitor.add_child(foot)
	var bezel := PanelContainer.new()
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bezel.add_theme_stylebox_override("panel", _box(Color("2e3142"), INK, 2, 6, 9))
	monitor.add_child(bezel)

	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", _box(SCREEN, Color("14161e"), 1, 1, 0))
	bezel.add_child(screen)
	var stack := Control.new()  # screen content + confirm popup on top
	screen.add_child(stack)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 4)
	stack.add_child(vb)

	# title bar
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(NAVY, NAVY, 0, 0, 3))
	vb.add_child(bar)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	bar.add_child(bar_row)
	bar_row.add_child(_label(str(_data.get("title", "")), UiTheme.SIZE, Color.WHITE, true))
	var sub := _label(str(_data.get("subtitle", "")), UiTheme.SIZE_SMALL, Color("c8d6f4"))
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(sub)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(gap)
	for c: Color in [Color("f2c14e"), Color("7ed37e"), Color("ef6b5b")]:
		var dot := _label("●", UiTheme.SIZE_SMALL, c)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar_row.add_child(dot)

	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 6)
	vb.add_child(body)
	var body_vb := VBoxContainer.new()
	body_vb.add_theme_constant_override("separation", 4)
	body.add_child(body_vb)
	body_vb.add_child(_label(str(_data.get("crumb", "")), UiTheme.SIZE_SMALL, TEXT_DIM))

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	body_vb.add_child(content)
	content.add_child(_info_card())
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	content.add_child(list)
	list.add_child(_label(str(_data.get("list_title", "")), UiTheme.SIZE, NAVY, true))
	var vendors: Array = _data.get("vendors", [])
	for i in vendors.size():
		var row := _vendor_row(vendors[i], i)
		_rows.append(row)
		list.add_child(row)

	# footer: tip + buttons
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 6)
	body_vb.add_child(foot_row)
	var tip := _label(str(_data.get("footer", "")), UiTheme.SIZE_SMALL, TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_row.add_child(tip)
	var later := _button(str(_data.get("btn_later", "")), false)
	later.pressed.connect(_finish.bind(-1))
	foot_row.add_child(later)
	var ok := _button(str(_data.get("btn_ok", "")), true)
	ok.pressed.connect(_ask_confirm)
	foot_row.add_child(ok)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 2)
	body_vb.add_child(pad)

	_confirm = _confirm_popup()
	stack.add_child(_confirm)


func _info_card() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(172, 0)
	card.add_theme_stylebox_override("panel", _box(CARD, CARD_LINE, 1, 3, 6))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	card.add_child(vb)
	vb.add_child(_label(str(_data.get("info_title", "")), UiTheme.SIZE, NAVY, true))
	for pair: Array in _data.get("info", []):
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(_label(str(pair[0]), UiTheme.SIZE_SMALL, TEXT_DIM))
		var v := _label(str(pair[1]), UiTheme.SIZE, TEXT, true)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(v)
		vb.add_child(cell)
	var tags: Array = _data.get("tags", [])
	if not tags.is_empty():
		var tag_row := HBoxContainer.new()
		tag_row.add_theme_constant_override("separation", 3)
		for t: Variant in tags:
			tag_row.add_child(_chip(str(t), SALE))
		vb.add_child(tag_row)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(gap)
	var f := _label(str(_data.get("formula", "")), UiTheme.SIZE_SMALL, TEXT_DIM)
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(f)
	return card


func _vendor_row(v: Dictionary, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 54)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_input.bind(index))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	row.add_child(hb)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 1)
	hb.add_child(left)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	name_row.add_child(_label(str(v.get("name", "")), UiTheme.SIZE, TEXT, true))
	if bool(v.get("sale", false)):
		name_row.add_child(_chip(str(v.get("sale_label", "")), SALE))
	left.add_child(name_row)
	var desc := _label(str(v.get("desc", "")), UiTheme.SIZE_SMALL, TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(desc)
	var note := str(v.get("note", ""))
	if note != "":
		left.add_child(_label(note, UiTheme.SIZE_SMALL, PICK))

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(104, 0)
	right.add_theme_constant_override("separation", 2)
	hb.add_child(right)
	var price := _label(str(v.get("price", "")), UiTheme.SIZE, SALE if bool(v.get("sale", false)) else TEXT, true)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(price)
	var quality := int(v.get("quality", 0))
	var bar := QualityBar.new()
	bar.quality = quality
	bar.required = int(_data.get("required", 0))
	bar.custom_minimum_size = Vector2(104, 7)
	right.add_child(bar)
	var q := _label(str(_data.get("quality_label", "%d")) % quality, UiTheme.SIZE_SMALL,
			GOOD if quality >= int(_data.get("required", 0)) else SALE)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(q)
	return row


func _confirm_popup() -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.12, 0.2, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.hide()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(260, 0)
	box.add_theme_stylebox_override("panel", _box(CARD, INK, 2, 4, 10))
	center.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	box.add_child(vb)
	_confirm_text = _label("", UiTheme.SIZE, TEXT, true)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_confirm_text)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)
	var no := _button(str(_data.get("btn_no", "")), false)
	no.pressed.connect(_close_confirm)
	hb.add_child(no)
	var yes := _button(str(_data.get("btn_yes", "")), true)
	yes.pressed.connect(func() -> void: _finish(_selected))
	hb.add_child(yes)
	return shade


# ---------------------------------------------------------------- behaviour
func _select(index: int) -> void:
	if _rows.is_empty():
		return
	var before := _selected
	_selected = posmod(index, _rows.size())
	if _selected != before:
		Sound.play("select")
	for i in _rows.size():
		var on := i == _selected
		_rows[i].add_theme_stylebox_override("panel",
				_box(PICK_BG if on else CARD, PICK if on else CARD_LINE, 2 if on else 1, 3, 5))


func _ask_confirm() -> void:
	if _rows.is_empty():
		return
	var texts: Array = _data.get("confirm", [])
	_confirm_text.text = str(texts[_selected]) if _selected < texts.size() else ""
	_confirm.show()
	Sound.play("confirm")


func _close_confirm() -> void:
	_confirm.hide()
	Sound.play("cancel")


func _finish(index: int) -> void:
	if _finished:
		return
	_finished = true
	Sound.play("stamp" if index >= 0 else "cancel")
	hide()
	_done.emit(index)


func _on_row_input(event: InputEvent, index: int) -> void:
	if _confirm.visible:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if index == _selected:
			_ask_confirm()
		else:
			_select(index)


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("move_up"):
		if not _confirm.visible:
			_select(_selected - 1)
	elif event.is_action_pressed("move_down"):
		if not _confirm.visible:
			_select(_selected + 1)
	elif event.is_action_pressed("interact"):
		if _confirm.visible:
			_finish(_selected)
		else:
			_ask_confirm()
	elif event.is_action_pressed("cancel"):
		if _confirm.visible:
			_close_confirm()
		else:
			_finish(-1)
	else:
		return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- helpers
func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	return UiTheme.make_label(text, size, color, bold)


func _chip(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(color, color, 0, 2, 0)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(_label(text, UiTheme.SIZE_SMALL, Color.WHITE))
	return p


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta("sfx_off", true)  # this window plays its own sounds
	b.focus_mode = Control.FOCUS_NONE  # keys go through _unhandled_input
	b.custom_minimum_size = Vector2(72, 22)
	var base := NAVY if primary else Color("dde3ec")
	var fg := Color.WHITE if primary else TEXT
	b.add_theme_stylebox_override("normal", _box(base, INK, 1, 3, 3))
	b.add_theme_stylebox_override("hover", _box(base.lightened(0.12), INK, 1, 3, 3))
	b.add_theme_stylebox_override("pressed", _box(base.darkened(0.15), INK, 1, 3, 3))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, fg)
	return b


func _box(bg: Color, border: Color, width: int, radius: int, pad: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


## Horizontal quality bar with a tick at the inspection standard.
class QualityBar:
	extends Control
	var quality := 0
	var required := 0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color("dfe5ee"))
		var fill := Color("3aa45c") if quality >= required else Color("e0483c")
		draw_rect(Rect2(0, 0, roundf(w * quality / 100.0), h), fill)
		var tx := roundf(w * required / 100.0)
		draw_rect(Rect2(tx - 1, -2, 2, h + 4), Color("261e2c"))
		draw_rect(Rect2(0, 0, w, h), Color("261e2c"), false, 1.0)
