class_name TutorialPages
extends CanvasLayer
## Paged how-to-play window shown before a minigame (11/20): a heading, an animated
## picture, a few lines per page, ◀ 이전 / 다음 ▶ (시작! on the last page), 건너뛰기.
## Keys: move_left / move_right flip pages, interact = next (start on the last page),
## cancel = skip. Touch / mouse use the buttons.
##     var tp := TutorialPages.new()
##     add_child(tp)   # or get_tree().root.add_child(tp)
##     await tp.run(Story.tutorial("drive"), painter)
##     tp.queue_free()
## data (Story.tutorial()): title, pages [{head, pic, lines, labels}], start (page index),
##   prev, next, go, skip, count ("%d / %d"), overlay (true: lock the map input while open).
## painter: func(ci: Control, pic: String, labels: Array, t: float) draws the page picture
##   inside a PIC_SIZE control (RaceGame.paint_tutorial, QcGame.paint_tutorial).

signal _closed

const PIC_SIZE := Vector2(320, 112)
const WIDTH := 452.0

static var _textures := {}

var _data: Dictionary = {}
var _pages: Array = []
var _page := 0
var _painter := Callable()
var _open := false
var _count: Label
var _head: Label
var _pic: Picture
var _lines: VBoxContainer
var _prev: Button
var _next: Button
var _dots: Dots


func run(data: Dictionary, painter: Callable) -> void:
	_data = data
	_pages = data.get("pages", [])
	_painter = painter
	if _pages.is_empty():
		return
	_page = clampi(int(data.get("start", 0)), 0, _pages.size() - 1)
	_build()
	_show_page()
	var overlay := bool(data.get("overlay", false))
	if overlay:
		Dialogue.set_overlay(true)
	_open = true
	await _closed
	if overlay:
		Dialogue.set_overlay(false)


func _build() -> void:
	layer = 50
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(root)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.08, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	var sb := UiTheme.panel_box(0.97)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.custom_minimum_size = Vector2(WIDTH, 0)
	panel.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vb.add_child(top)
	var title := UiTheme.make_label(str(_data.get("title", "")), UiTheme.SIZE, UiTheme.COLOR_BORDER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_count = UiTheme.make_label("", UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_count)
	var skip := _button(str(_data.get("skip", "")), Vector2(64, 18))
	skip.pressed.connect(_close)
	top.add_child(skip)

	_head = UiTheme.make_label("", UiTheme.SIZE_LARGE, UiTheme.COLOR_WARN, true)
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_head)
	_pic = Picture.new()
	_pic.painter = _painter
	_pic.custom_minimum_size = PIC_SIZE
	_pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(_pic)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 1)
	vb.add_child(_lines)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	vb.add_child(bottom)
	_prev = _button(str(_data.get("prev", "")), Vector2(84, 24))
	_prev.pressed.connect(_flip.bind(-1))
	bottom.add_child(_prev)
	_dots = Dots.new()
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.custom_minimum_size = Vector2(0, 24)
	bottom.add_child(_dots)
	_next = _button("", Vector2(96, 24))
	_next.pressed.connect(_flip.bind(1))
	bottom.add_child(_next)


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE  # keys are handled in _unhandled_input (no double press)
	return b


func _show_page() -> void:
	var p: Dictionary = _pages[_page]
	_head.text = str(p.get("head", ""))
	_pic.pic = str(p.get("pic", ""))
	_pic.labels = p.get("labels", [])
	_pic.reset()
	for c in _lines.get_children():
		c.queue_free()
	for line: Variant in p.get("lines", []):
		var l := UiTheme.make_label(UiTheme.keep_words(str(line)), UiTheme.SIZE, UiTheme.COLOR_TEXT)
		l.custom_minimum_size = Vector2(WIDTH, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lines.add_child(l)
	_count.text = str(_data.get("count", "%d / %d")) % [_page + 1, _pages.size()]
	_prev.disabled = _page == 0
	var last := _page == _pages.size() - 1
	_next.text = str(_data.get("go" if last else "next", ""))
	_dots.count = _pages.size()
	_dots.current = _page
	_dots.queue_redraw()


func _flip(dir: int) -> void:
	if not _open:
		return
	var to := _page + dir
	if to >= _pages.size():
		_close()
		return
	if to < 0:
		return
	_page = to
	_show_page()


func _close() -> void:
	if not _open:
		return
	_open = false
	hide()
	_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("interact"):
		Sound.play("confirm")
		_flip(1)
	elif event.is_action_pressed("move_right"):
		if _page < _pages.size() - 1:
			Sound.play("select")
			_flip(1)
	elif event.is_action_pressed("move_left"):
		if _page > 0:
			Sound.play("select")
			_flip(-1)
	elif event.is_action_pressed("cancel"):
		_close()
	else:
		return
	get_viewport().set_input_as_handled()


## A texture for painters, kept alive here: a texture loaded inside _draw and dropped
## right after is freed, and the queued draw then shows a plain white box.
static func tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path]


## Text centered at `at` (baseline), for painters. On a Picture the text is queued and
## drawn by its overlay child, above everything the painter drew.
static func text(ci: CanvasItem, at: Vector2, s: String, color: Color, size: int = UiTheme.SIZE_SMALL, outline: bool = true) -> void:
	if ci is Picture:
		(ci as Picture).texts.append([at, s, color, size, outline])
		return
	_draw_text(ci, at, s, color, size, outline)


static func _draw_text(ci: CanvasItem, at: Vector2, s: String, color: Color, size: int, outline: bool) -> void:
	var font: Font = UiTheme.FONT_BOLD
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(at.x - w / 2.0, at.y)
	if outline:
		ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color("261e2c"))
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## The page picture: a framed box the minigame's painter draws into (animated).
class Picture:
	extends Control
	var painter := Callable()
	var pic := ""
	var labels: Array = []
	var texts: Array = []  # [at, text, color, size, outline] queued by TutorialPages.text()
	var _t := 0.0
	var _overlay: Overlay

	func _ready() -> void:
		clip_contents = true
		_overlay = Overlay.new()
		_overlay.picture = self
		_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_overlay)

	func reset() -> void:
		_t = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		texts.clear()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.14, 0.21))
		if painter.is_valid():
			painter.call(self, pic, labels, _t)
		if _overlay != null:
			_overlay.queue_redraw()

	class Overlay:
		extends Control
		var picture: Picture

		func _draw() -> void:
			for e: Array in picture.texts:
				TutorialPages._draw_text(self, e[0], str(e[1]), e[2], int(e[3]), bool(e[4]))
			draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_BORDER, false, 1.0)


## Page dots: the current one lit.
class Dots:
	extends Control
	var count := 1
	var current := 0

	func _draw() -> void:
		var gap := 12.0
		var x0 := size.x / 2.0 - (count - 1) * gap / 2.0
		for i in count:
			var c := Vector2(x0 + i * gap, size.y / 2.0)
			draw_circle(c, 3.5 if i == current else 2.5, UiTheme.COLOR_WARN if i == current else Color(1, 1, 1, 0.35))
