class_name QcGame
extends CanvasLayer
## 품질 검사 미니게임 (window over the lab map): goods ride a conveyor through the
## inspection zone; reject the defective ones (scratch, stain, crack, missing piece).
## Story builds every string:
##     var qc := QcGame.new()
##     get_tree().root.add_child(qc)
##     var r: Dictionary = await qc.run(data)   # {defects, caught, missed, wrong}
## data keys: title, item (product texture), kind (TaskData "kind"), items (count), defects (count),
##   zone ("검사 구역"), reject ("불합격!"), hint, found ("찾은 불량 %d/%d"), wrong ("오판 %d"),
##   left ("남은 물품 %d"), hit, miss, false_alarm (flash texts), go ("시작!")
## Controls: interact (Space / Enter / touch A) or a tap rejects the item in the zone.
## Before it, Story shows the paged tutorial (TutorialPages, pictures: paint_tutorial()).

signal _done(result: Dictionary)

## Tests set this: rejects every defective item in the zone, at double speed.
static var autoplay := false

const INK := Color("261e2c")
const CREAM := Color("fbf3dc")
const TEXT := Color("2e2636")
const GOOD := Color("2f8f4e")
const BAD := Color("c0392b")
const BELT_SIZE := Vector2(560, 132)
const ITEM_SCALE := 3.0
const SPEED := 100.0
const SPACING := 105.0
const ZONE_W := 84.0
const COUNTDOWN := 2.0
## Where defects go on each product picture (offset from its center, in pixels of the
## 24x24 image) and how far they may wander: the desk is only a thin top on legs.
const DEFECT_AREA := {
	"furniture": [Vector2(0, -3.5), Vector2(6, 1)], "device": [Vector2(0, 0), Vector2(4, 2)],
	"soft": [Vector2(0, 0), Vector2(5, 4)], "metal": [Vector2(0, -0.5), Vector2(5, 2)],
}

var _data: Dictionary = {}
var _items: Array[Dictionary] = []
var _belt: Belt
var _found_label: Label
var _wrong_label: Label
var _left_label: Label
var _flash: Label
var _flash_t := 0.0
var _t := -COUNTDOWN
var _caught := 0
var _missed := 0
var _wrong := 0
var _finished := false
var _rng := RandomNumberGenerator.new()


func run(data: Dictionary) -> Dictionary:
	_data = data
	_rng.randomize()
	_make_items()
	_build()
	Dialogue.set_overlay(true)
	var result: Dictionary = await _done
	Dialogue.set_overlay(false)
	return result


func _make_items() -> void:
	var n := int(_data.get("items", 10))
	var defects := clampi(int(_data.get("defects", 2)), 0, n)
	var order: Array[int] = []
	for i in n:
		order.append(i)
	order.shuffle()
	var bad := order.slice(0, defects)
	var area: Array = DEFECT_AREA.get(str(_data.get("kind", "device")), DEFECT_AREA["device"])
	var center: Vector2 = area[0]
	var spread: Vector2 = area[1]
	for i in n:
		_items.append({
			"x": -60.0 - i * SPACING, "defect": _rng.randi_range(0, 3) if bad.has(i) else -1,
			"dx": center.x + _rng.randf_range(-spread.x, spread.x), "dy": center.y + _rng.randf_range(-spread.y, spread.y),
			"state": "belt", "fall": 0.0,
		})


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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var win := PanelContainer.new()
	win.add_theme_stylebox_override("panel", _box(CREAM, INK, 2, 6, 8))
	center.add_child(win)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	win.add_child(vb)

	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", _box(INK, INK, 0, 3, 2))
	var tl := UiTheme.make_label(str(_data.get("title", "")), UiTheme.SIZE, CREAM, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(tl)
	vb.add_child(title)

	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	vb.add_child(info)
	var hint := UiTheme.make_label(str(_data.get("hint", "")), UiTheme.SIZE_SMALL, TEXT)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(hint)
	_found_label = UiTheme.make_label("", UiTheme.SIZE, GOOD, true)
	info.add_child(_found_label)
	_wrong_label = UiTheme.make_label("", UiTheme.SIZE, BAD, true)
	info.add_child(_wrong_label)

	_belt = Belt.new()
	_belt.game = self
	_belt.custom_minimum_size = BELT_SIZE
	_belt.mouse_filter = Control.MOUSE_FILTER_STOP
	_belt.gui_input.connect(_on_belt_input)
	vb.add_child(_belt)
	_flash = UiTheme.make_label("", UiTheme.SIZE_LARGE, GOOD, true)
	_flash.add_theme_color_override("font_outline_color", Color.WHITE)
	_flash.add_theme_constant_override("outline_size", 6)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.offset_left = -200
	_flash.offset_right = 200
	_flash.offset_top = 4
	_belt.add_child(_flash)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	vb.add_child(bottom)
	_left_label = UiTheme.make_label("", UiTheme.SIZE, TEXT, true)
	_left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_left_label)
	var reject := Button.new()
	reject.text = str(_data.get("reject", ""))
	reject.set_meta("sfx_off", true)
	reject.focus_mode = Control.FOCUS_NONE
	reject.custom_minimum_size = Vector2(150, 30)
	reject.add_theme_stylebox_override("normal", _box(BAD, INK, 2, 4, 4))
	reject.add_theme_stylebox_override("hover", _box(BAD.lightened(0.1), INK, 2, 4, 4))
	reject.add_theme_stylebox_override("pressed", _box(BAD.darkened(0.2), INK, 2, 4, 4))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		reject.add_theme_color_override(key, Color.WHITE)
	reject.pressed.connect(_reject)
	bottom.add_child(reject)
	_refresh_labels()


# ---------------------------------------------------------------- play
func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.text = ""
	if _finished:
		return
	var dt := delta * (2.0 if autoplay else 1.0)
	_t += dt
	if _t < 0.0:
		_flash.text = str(ceili(-_t))
		_flash.add_theme_color_override("font_color", TEXT)
		_belt.queue_redraw()
		return
	if _t - dt < 0.0:
		_show_flash(str(_data.get("go", "")), TEXT)
	var all_done := true
	for it: Dictionary in _items:
		match str(it["state"]):
			"belt":
				it["x"] = float(it["x"]) + SPEED * dt
				if autoplay and int(it["defect"]) >= 0 and absf(float(it["x"]) - _zone_x()) < 6.0:
					_reject()
				if float(it["x"]) > BELT_SIZE.x + 40.0:
					it["state"] = "passed"
					if int(it["defect"]) >= 0:
						_missed += 1
						_show_flash(str(_data.get("miss", "")), BAD)
						Sound.play("bad")
					_refresh_labels()
				all_done = false
			"rejected":
				it["fall"] = float(it["fall"]) + dt
				if float(it["fall"]) < 0.6:
					all_done = false
	_belt.queue_redraw()
	if all_done:
		_finish()


func _zone_x() -> float:
	return BELT_SIZE.x / 2.0


func _reject() -> void:
	if _finished or _t < 0.0:
		return
	var best: Dictionary = {}
	var best_d := INF
	for it: Dictionary in _items:
		if str(it["state"]) != "belt":
			continue
		var d := absf(float(it["x"]) - _zone_x())
		if d < ZONE_W / 2.0 + 10.0 and d < best_d:
			best = it
			best_d = d
	if best.is_empty():
		Sound.play("select")  # nothing in the zone
		return
	best["state"] = "rejected"
	if int(best["defect"]) >= 0:
		_caught += 1
		_show_flash(str(_data.get("hit", "")), GOOD)
		Sound.play("stamp")
	else:
		_wrong += 1
		_show_flash(str(_data.get("false_alarm", "")), BAD)
		Sound.play("warn")
	_refresh_labels()


func _finish() -> void:
	_finished = true
	var defects := 0
	for it: Dictionary in _items:
		if int(it["defect"]) >= 0:
			defects += 1
	await get_tree().create_timer(0.4).timeout
	hide()
	_done.emit({"defects": defects, "caught": _caught, "missed": _missed, "wrong": _wrong})


func _refresh_labels() -> void:
	var defects := 0
	var left := 0
	for it: Dictionary in _items:
		if int(it["defect"]) >= 0:
			defects += 1
		if str(it["state"]) == "belt":
			left += 1
	_found_label.text = str(_data.get("found", "%d/%d")) % [_caught, defects]
	_wrong_label.text = str(_data.get("wrong", "%d")) % _wrong
	_left_label.text = str(_data.get("left", "%d")) % left


func _show_flash(text: String, color: Color) -> void:
	_flash.text = text
	_flash.add_theme_color_override("font_color", color)
	_flash_t = 0.7


func _on_belt_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_reject()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_reject()


func _box(bg: Color, border: Color, width: int, radius: int, pad: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


## The conveyor, the inspection zone and the goods (with their defects).
class Belt:
	extends Control
	var game: QcGame
	var _tex: Texture2D

	func _draw() -> void:
		if _tex == null:
			_tex = load(str(game._data.get("item", ""))) as Texture2D
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color("dfe5ee"))
		var belt := Rect2(0, h - 62, w, 40)
		draw_rect(belt, Color("464a58"))
		var shift := fmod(maxf(game._t, 0.0) * SPEED, 24.0)
		var x := -24.0 + shift
		while x < w:
			draw_rect(Rect2(x, belt.position.y + 2, 3, belt.size.y - 4), Color("5c6072"))
			x += 24.0
		draw_rect(Rect2(0, belt.position.y - 3, w, 3), Color("9aa0b0"))
		draw_rect(Rect2(0, belt.end.y, w, 4), Color("7a8090"))
		# inspection zone
		var zx := game._zone_x()
		var zone := Rect2(zx - ZONE_W / 2.0, 22, ZONE_W, h - 30)
		draw_rect(zone, Color(1.0, 0.85, 0.3, 0.22))
		draw_rect(zone, Color("e0a020"), false, 2.0)
		var font := UiTheme.FONT_BOLD
		var label := str(game._data.get("zone", ""))
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
		draw_string(font, Vector2(zx - lw / 2.0, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, Color("8a5a10"))
		if _tex == null:
			return
		var s := _tex.get_size() * ITEM_SCALE
		for it: Dictionary in game._items:
			var st := str(it["state"])
			if st == "passed":
				continue
			var fall := float(it["fall"])
			if st == "rejected" and fall >= 0.6:
				continue
			var pos := Vector2(float(it["x"]) - s.x / 2.0, belt.position.y - s.y + 14 + fall * 120.0)
			var alpha := 1.0 - fall / 0.6
			draw_texture_rect(_tex, Rect2(pos, s), false, Color(1, 1, 1, alpha))
			if int(it["defect"]) >= 0:
				QcGame.draw_defect(self, int(it["defect"]), pos + s / 2.0 + Vector2(float(it["dx"]), float(it["dy"])) * ITEM_SCALE, alpha, ITEM_SCALE)
			if st == "rejected":
				draw_line(pos + Vector2(10, 10), pos + s - Vector2(10, 10), Color(0.8, 0.1, 0.1, alpha), 4.0)
				draw_line(pos + Vector2(s.x - 10, 10), pos + Vector2(10, s.y - 10), Color(0.8, 0.1, 0.1, alpha), 4.0)


## A defect on a product picture at c (k = picture scale). 0 crack, 1 stain, 2 missing
## piece, 3 scratches. Also used by the tutorial pictures.
static func draw_defect(ci: CanvasItem, kind: int, c: Vector2, alpha: float, k: float) -> void:
	match kind:
		0:  # crack
			var pts := PackedVector2Array([c + Vector2(-4, -3) * k, c + Vector2(-1, -1) * k, c + Vector2(-2, 1) * k,
					c + Vector2(1, 2) * k, c + Vector2(0, 4) * k])
			ci.draw_polyline(pts, Color(0.12, 0.1, 0.14, alpha), 3.0)
		1:  # stain
			ci.draw_circle(c, 2.6 * k, Color(0.48, 0.32, 0.16, alpha * 0.85))
			ci.draw_circle(c + Vector2(2.5, 1.5) * k, 1.4 * k, Color(0.48, 0.32, 0.16, alpha * 0.85))
		2:  # missing piece: a chunk of belt shows through
			var r := Rect2(c - Vector2(2.5, 2.5) * k, Vector2(5, 5) * k)
			ci.draw_rect(r, Color(0.87, 0.9, 0.93, alpha))
			ci.draw_rect(r, Color(0.15, 0.12, 0.18, alpha), false, 2.0)
		_:  # scratches
			for i in 2:
				var o := Vector2(i * 2.0, i * 1.5) * k
				ci.draw_line(c - Vector2(4, 2) * k + o, c + Vector2(3, -4) * k + o, Color(0.22, 0.2, 0.26, alpha * 0.8), 2.0)


# ================================================================ tutorial pictures
## TutorialPages painter for Story.TUTORIALS["qc"]: product = the task's product picture,
## kind = TaskData "kind" (where defects go on it).
static func paint_tutorial(ci: Control, pic: String, labels: Array, t: float, product: String, kind: String) -> void:
	var sz := ci.size
	var tex := TutorialPages.tex(product)
	var lab := func(i: int) -> String: return str(labels[i]) if i < labels.size() else ""
	var area: Array = DEFECT_AREA.get(kind, DEFECT_AREA["device"])
	var spot: Vector2 = area[0]
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("dfe5ee"))
	match pic:
		"belt", "reject":
			var k := 2.0
			var belt := Rect2(0, sz.y - 34, sz.x, 24)
			ci.draw_rect(belt, Color("464a58"))
			var shift := fmod(t * 60.0, 20.0) if pic == "belt" else 0.0
			var x := -20.0 + shift
			while x < sz.x:
				ci.draw_rect(Rect2(x, belt.position.y + 2, 3, belt.size.y - 4), Color("5c6072"))
				x += 20.0
			var zx := sz.x / 2.0 if pic == "belt" else sz.x * 0.36
			var zone := Rect2(zx - 34.0, 18.0, 68.0, sz.y - 22.0)
			ci.draw_rect(zone, Color(1.0, 0.85, 0.3, 0.25))
			ci.draw_rect(zone, Color("e0a020"), false, 2.0)
			TutorialPages.text(ci, Vector2(zx, 14.0), lab.call(0) if pic == "belt" else "", Color("f2c14e"))
			if tex == null:
				return
			var s := tex.get_size() * k
			if pic == "belt":
				for i in 5:
					var ix := fmod(t * 60.0 + i * 80.0, 400.0) - 40.0
					var pos := Vector2(ix - s.x / 2.0, belt.position.y - s.y + 10.0)
					ci.draw_texture_rect(tex, Rect2(pos, s), false)
					if i == 2:
						QcGame.draw_defect(ci, 1, pos + s / 2.0 + spot * k, 1.0, k)
			else:
				var pos := Vector2(zx - s.x / 2.0, belt.position.y - s.y + 10.0)
				ci.draw_texture_rect(tex, Rect2(pos, s), false)
				QcGame.draw_defect(ci, 0, pos + s / 2.0 + spot * k, 1.0, k)
				if fmod(t, 1.6) > 0.8:  # the reject mark blinks on
					ci.draw_line(pos + Vector2(8, 8), pos + s - Vector2(8, 8), Color(0.8, 0.1, 0.1), 4.0)
					ci.draw_line(pos + Vector2(s.x - 8, 8), pos + Vector2(8, s.y - 8), Color(0.8, 0.1, 0.1), 4.0)
				var btn := Rect2(sz.x * 0.62, 22.0, 100.0, 28.0)
				var pressed := fmod(t, 1.6) > 0.8 and fmod(t, 1.6) < 1.0
				ci.draw_rect(btn, BAD.darkened(0.2) if pressed else BAD)
				ci.draw_rect(btn, INK, false, 2.0)
				TutorialPages.text(ci, btn.get_center() + Vector2(0, 5), lab.call(0), Color.WHITE, UiTheme.SIZE)
				var key := Rect2(btn.get_center().x - 30.0, 58.0, 60.0, 22.0)
				ci.draw_rect(key, Color("f2c14e") if pressed else Color("e8d9a8"))
				ci.draw_rect(key, INK, false, 1.5)
				TutorialPages.text(ci, Vector2(key.get_center().x, key.position.y + 16.0), lab.call(1), INK, UiTheme.SIZE_SMALL, false)
		"defects":
			if tex == null:
				return
			var k := 2.5
			var s := tex.get_size() * k
			var kinds := [3, 1, 0, 2]  # scratch, stain, crack, missing: the caption order
			var step := sz.x / kinds.size()
			for i in kinds.size():
				var c := Vector2(step * (i + 0.5), sz.y / 2.0 - 10.0)
				var pos := c - s / 2.0
				ci.draw_texture_rect(tex, Rect2(pos, s), false)
				QcGame.draw_defect(ci, int(kinds[i]), c + spot * k, 1.0, k)
				var ring := 0.5 + 0.5 * sin(t * 5.0 + i)
				ci.draw_arc(c + spot * k, 4.0 * k + ring * 2.0, 0, TAU, 20, Color(0.9, 0.2, 0.2, 0.8), 2.0)
				TutorialPages.text(ci, Vector2(c.x, sz.y - 10.0), lab.call(i), BAD, UiTheme.SIZE_SMALL, false)
		"result":
			var grow := clampf(fmod(t, 3.0) / 1.5, 0.0, 1.0)
			var x0 := 92.0
			var full := sz.x - x0 - 24.0
			var need := 0.7
			for i in 2:
				var y := 26.0 + i * 36.0
				TutorialPages.text(ci, Vector2(48.0, y + 12.0), lab.call(i), TEXT if i == 0 else GOOD, UiTheme.SIZE, false)
				var v := 0.6 if i == 0 else lerpf(0.6, 0.85, grow)
				ci.draw_rect(Rect2(x0, y, full, 16.0), Color(0, 0, 0, 0.12))
				ci.draw_rect(Rect2(x0, y, full * v, 16.0), Color("a0a4b4") if i == 0 else GOOD)
				ci.draw_rect(Rect2(x0, y, full, 16.0), INK, false, 1.0)
			var nx := x0 + full * need
			ci.draw_line(Vector2(nx, 18.0), Vector2(nx, 86.0), BAD, 2.0)
			TutorialPages.text(ci, Vector2(nx, sz.y - 8.0), lab.call(2), BAD, UiTheme.SIZE_SMALL, false)
