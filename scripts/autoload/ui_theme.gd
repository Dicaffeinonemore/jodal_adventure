extends Node
## Fonts, colors and the shared Theme.
##
## Web builds have no system fonts, so Hangul only renders if every Control uses
## the bundled LevelUp font (레벨업, SIL OFL 1.1, assets/fonts/OFL-LevelUp.md).
## 11/18: replaced the Galmuri pixel font for readability. LevelUp is an outline
## font, so the project stretches in canvas_items mode: text is drawn at the real
## screen resolution (sharp), while pixel art keeps Nearest filtering. In viewport
## mode the 12 px text would be drawn at 640x360 and blown up = blurry.

const FONT_REGULAR: FontFile = preload("res://assets/fonts/LevelUp-Regular.ttf")
const FONT_BOLD: FontFile = preload("res://assets/fonts/LevelUp-Bold.ttf")
const FONT_SMALL: FontFile = preload("res://assets/fonts/LevelUp-Regular.ttf")
const SIZE := 12
const SIZE_SMALL := 12
const SIZE_LARGE := 24
const WORD_JOINER := "⁠"  # the invisible U+2060 character, see keep_words()

const COLOR_TEXT := Color("f4f1e8")
const COLOR_DIM := Color("d2cdc0")
const COLOR_PANEL := Color(0.1, 0.11, 0.17, 0.92)
const COLOR_BORDER := Color("e8d9a8")
const COLOR_ACCENT := Color("6fb6ff")
const COLOR_GOOD := Color("7ed37e")
const COLOR_WARN := Color("f2c14e")
const COLOR_BAD := Color("ef6b5b")

var theme: Theme


func _enter_tree() -> void:
	for f: FontFile in [FONT_REGULAR, FONT_BOLD, FONT_SMALL]:  # smooth outlines, rendered at screen size
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	ThemeDB.fallback_font = FONT_REGULAR
	ThemeDB.fallback_font_size = SIZE
	theme = _build_theme()


func _ready() -> void:
	get_tree().root.theme = theme


## Give a UI root the shared theme (call on the top Control of each UI you build).
func apply(control: Control) -> void:
	control.theme = theme


## Distance to keep UI away from the screen edge. Phones in landscape have a
## notch on one side, so touch devices get a wider margin.
## TODO(P1): read DisplayServer.get_display_safe_area() for exact insets.
func edge_margin() -> float:
	return 20.0 if GameState.is_touch_device() else 8.0


## Text for autowrapped labels: puts an invisible WORD JOINER (U+2060) between Hangul
## syllables so lines break only at spaces. Godot's line breaker treats every Hangul
## syllable as a break point and splits words mid-word. It is a default-ignorable character: nothing is drawn.
func keep_words(text: String) -> String:
	var out := PackedStringArray()
	var prev_hangul := false
	for i in text.length():
		var c := text.unicode_at(i)
		var hangul := c >= 0xAC00 and c <= 0xD7A3
		if hangul and prev_hangul:
			out.append(WORD_JOINER)
		out.append(text[i])
		prev_hangul = hangul
	return "".join(out)


func panel_box(alpha: float = 0.92) -> StyleBoxFlat:
	return _box(Color(COLOR_PANEL, alpha), COLOR_BORDER)


func make_label(text: String, size: int = SIZE, color: Color = COLOR_TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", FONT_BOLD)
	elif size == SIZE_SMALL:
		l.add_theme_font_override("font", FONT_SMALL)
	return l


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT_REGULAR
	t.default_font_size = SIZE

	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())

	var normal := _box(Color(0.18, 0.2, 0.3, 0.95), COLOR_BORDER.darkened(0.35))
	var hover := _box(Color(0.24, 0.28, 0.42, 0.95), COLOR_BORDER)
	var pressed := _box(Color(0.12, 0.14, 0.22, 0.95), COLOR_BORDER)
	var focus := _box(Color(0, 0, 0, 0), COLOR_ACCENT, 2)
	focus.draw_center = false
	var disabled := _box(Color(0.15, 0.15, 0.18, 0.8), Color(0.4, 0.4, 0.45))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", COLOR_TEXT)
	t.set_color("font_hover_color", "Button", COLOR_TEXT)
	t.set_color("font_focus_color", "Button", COLOR_TEXT)
	t.set_color("font_pressed_color", "Button", COLOR_BORDER)
	t.set_color("font_disabled_color", "Button", COLOR_DIM)

	t.set_color("font_color", "Label", COLOR_TEXT)

	t.set_stylebox("normal", "LineEdit", normal)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_stylebox("read_only", "LineEdit", normal)
	t.set_color("font_color", "LineEdit", COLOR_TEXT)
	t.set_color("font_uneditable_color", "LineEdit", COLOR_TEXT)

	t.set_stylebox("background", "ProgressBar", _box(Color(0, 0, 0, 0.55), COLOR_BORDER.darkened(0.4), 1, 0))
	t.set_stylebox("fill", "ProgressBar", _box(COLOR_ACCENT, Color(0, 0, 0, 0), 0, 0))
	return t


func _box(bg: Color, border: Color, border_w: int = 1, pad: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(pad)
	return sb
