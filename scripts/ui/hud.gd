class_name Hud
extends CanvasLayer
## Tycoon-style HUD.
##   top bar:    day + clock | rank name | fatigue bar | condition ...... wallet | team budget | reputation
##   below it:   promotion gauge (left: exp toward the next rank), current objective (center)
##   bottom bar: 업무 / 가방 / 성장 / 저장 buttons (Story.open_panel)
## Rewards float up from the player (GameState.popup) and numbers count up.
## Esc / touch B opens the full menu.

const BAR_BUTTONS := [["업무", "task"], ["가방", "bag"], ["성장", "growth"], ["저장", "save"]]
const COUNT_TIME := 0.6

var _root: Control
var _day_label: Label
var _name_label: Label
var _fatigue_bar: ProgressBar
var _fatigue_label: Label
var _condition_label: Label
var _money_label: Label
var _budget_label: Label
var _rep_label: Label
var _objective: Label
var _exp_caption: Label
var _exp_bar: ProgressBar
var _exp_label: Label
var _exp_tween: Tween
var _bar: HBoxContainer
var _fill: StyleBoxFlat
var _popups: Control
var _popup_count := 0

# displayed (animated) values
var _shown := {"money": 0.0, "budget": 0.0, "rep": 0.0}
var _tweens: Dictionary = {}


func _ready() -> void:
	layer = 10
	add_to_group("hud")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UiTheme.apply(_root)
	var m := UiTheme.edge_margin()

	# ---- top bar
	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = m
	top.offset_right = -m
	top.offset_top = 4
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", UiTheme.panel_box(0.85))
	_root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	top.add_child(row)

	_day_label = _chip(row, UiTheme.COLOR_BORDER)
	_name_label = UiTheme.make_label("", UiTheme.SIZE, UiTheme.COLOR_TEXT, true)
	row.add_child(_name_label)
	var fat := HBoxContainer.new()
	fat.add_theme_constant_override("separation", 3)
	row.add_child(fat)
	fat.add_child(UiTheme.make_label("피로", UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))
	_fatigue_bar = ProgressBar.new()
	_fatigue_bar.custom_minimum_size = Vector2(56, 8)
	_fatigue_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fatigue_bar.max_value = GameState.FATIGUE_MAX
	_fatigue_bar.show_percentage = false
	_fill = (UiTheme.theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat).duplicate()
	_fatigue_bar.add_theme_stylebox_override("fill", _fill)
	fat.add_child(_fatigue_bar)
	_fatigue_label = UiTheme.make_label("", UiTheme.SIZE_SMALL)
	fat.add_child(_fatigue_label)
	_condition_label = UiTheme.make_label("", UiTheme.SIZE_SMALL)
	row.add_child(_condition_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_money_label = UiTheme.make_label("", UiTheme.SIZE_SMALL, Color("ffe08a"))
	row.add_child(_money_label)
	_budget_label = UiTheme.make_label("", UiTheme.SIZE_SMALL, Color("9fe0a8"))
	row.add_child(_budget_label)
	_rep_label = UiTheme.make_label("", UiTheme.SIZE_SMALL, Color("9fd3ff"))
	row.add_child(_rep_label)

	# ---- promotion gauge
	var exp_panel := PanelContainer.new()
	exp_panel.position = Vector2(m, 28)
	exp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8))
	_root.add_child(exp_panel)
	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 4)
	exp_panel.add_child(exp_row)
	_exp_caption = UiTheme.make_label("", UiTheme.SIZE_SMALL, UiTheme.COLOR_WARN)
	exp_row.add_child(_exp_caption)
	_exp_bar = ProgressBar.new()
	_exp_bar.custom_minimum_size = Vector2(64, 6)
	_exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_exp_bar.show_percentage = false
	var exp_fill := (UiTheme.theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat).duplicate() as StyleBoxFlat
	exp_fill.bg_color = UiTheme.COLOR_WARN
	_exp_bar.add_theme_stylebox_override("fill", exp_fill)
	exp_row.add_child(_exp_bar)
	_exp_label = UiTheme.make_label("", UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM)
	exp_row.add_child(_exp_label)

	# ---- objective
	_objective = UiTheme.make_label("", UiTheme.SIZE, UiTheme.COLOR_WARN)
	_objective.anchor_left = 0.5
	_objective.anchor_right = 0.5
	_objective.offset_top = 30
	_objective.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_objective.add_theme_constant_override("outline_size", 4)
	_root.add_child(_objective)

	# ---- bottom menu bar
	_bar = HBoxContainer.new()
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -28
	_bar.offset_bottom = -4
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.add_theme_constant_override("separation", 4)
	_root.add_child(_bar)
	for entry: Array in BAR_BUTTONS:
		var b := Button.new()
		b.text = str(entry[0])
		b.custom_minimum_size = Vector2(56, 24)
		b.focus_mode = Control.FOCUS_NONE  # Space/Enter stay with the game
		b.pressed.connect(_on_bar_pressed.bind(str(entry[1])))
		_bar.add_child(b)

	_popups = Control.new()
	_popups.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_popups)

	_shown["money"] = float(GameState.money)
	_shown["budget"] = float(GameState.budget)
	_shown["rep"] = float(GameState.reputation)
	GameState.stats_changed.connect(_refresh)
	GameState.task_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh)
	GameState.popup.connect(_on_popup)
	Dialogue.opened.connect(_refresh_bar)
	Dialogue.closed.connect(_refresh_bar)
	Dialogue.overlay_changed.connect(_refresh_bar.unbind(1))
	_refresh()
	_refresh_bar()


func _chip(parent: Control, color: Color) -> Label:
	var l := UiTheme.make_label("", UiTheme.SIZE, color, true)
	parent.add_child(l)
	return l


## Screen rect of the bottom bar, so the touch joystick can ignore taps on it.
func menu_bar_rect() -> Rect2:
	return _bar.get_global_rect() if _bar.visible else Rect2()


func _refresh_bar() -> void:
	_bar.visible = not Dialogue.is_open and not Dialogue.overlay_open


func _on_bar_pressed(panel: String) -> void:
	if GameState.is_input_locked() or Story.is_busy():
		return
	Story.open_panel(panel)


func _refresh() -> void:
	_day_label.text = "%d일차 %s" % [GameState.day, GameState.clock_text()]
	_name_label.text = "%s %s" % [GameState.rank_name(), GameState.player_name]
	_refresh_exp()
	_fatigue_bar.value = GameState.fatigue
	_fatigue_label.text = str(GameState.fatigue)
	if GameState.fatigue >= GameState.FATIGUE_BAD_AT:
		_fill.bg_color = UiTheme.COLOR_BAD
	elif GameState.fatigue >= 40:
		_fill.bg_color = UiTheme.COLOR_WARN
	else:
		_fill.bg_color = UiTheme.COLOR_GOOD
	var cond := GameState.condition()
	var cond_color := UiTheme.COLOR_TEXT
	if cond == GameState.Condition.GOOD:
		cond_color = UiTheme.COLOR_GOOD
	elif cond == GameState.Condition.BAD:
		cond_color = UiTheme.COLOR_BAD
	_condition_label.text = "컨디션 " + GameState.condition_label()
	_condition_label.add_theme_color_override("font_color", cond_color)
	_count_to("money", GameState.money)
	_count_to("budget", GameState.budget)
	_count_to("rep", GameState.reputation)
	var obj := Story.objective_text()
	_objective.text = ("▶ " + obj.replace("목표: ", "")) if obj != "" else ""


func _refresh_exp() -> void:
	var p := GameState.rank_progress()
	if p.y <= 0:
		_exp_caption.text = "최고 직급"
		_exp_bar.max_value = 1
		_exp_bar.value = 1
		_exp_label.text = "경험치 %d" % GameState.experience
		return
	_exp_caption.text = "%s까지" % GameState.RANKS[GameState.rank + 1]
	_exp_label.text = "%d/%d" % [p.x, p.y]
	if not is_equal_approx(_exp_bar.max_value, p.y):  # new rank: start the bar over
		_exp_bar.max_value = p.y
		_exp_bar.value = 0
	if _exp_tween != null and _exp_tween.is_valid():
		_exp_tween.kill()
	_exp_tween = create_tween()
	_exp_tween.tween_property(_exp_bar, "value", float(p.x), COUNT_TIME)


## Animates a number label from what it shows now to the new value.
func _count_to(key: String, value: int) -> void:
	if is_equal_approx(float(_shown[key]), float(value)):
		_write(float(value), key)
		return
	if _tweens.has(key) and (_tweens[key] as Tween).is_valid():
		(_tweens[key] as Tween).kill()
	var tw := create_tween()
	tw.tween_method(_write.bind(key), float(_shown[key]), float(value), COUNT_TIME)
	_tweens[key] = tw


func _write(v: float, key: String) -> void:
	_shown[key] = v
	var n := roundi(v)
	match key:
		"money":
			_money_label.text = "지갑 %s원" % Korean.comma(n)
		"budget":
			_budget_label.text = "예산 %s만" % Korean.comma(n)
		"rep":
			_rep_label.text = "평판 %d" % n


func _on_popup(text: String, color: Color) -> void:
	var l := UiTheme.make_label(text, UiTheme.SIZE, color, true)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.12))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pp := _player_screen_pos()
	# Above the head, or below the feet when the player is near the top (HUD, toasts).
	var dy := -48.0 - 14 * (_popup_count % 3) if pp.y > 130.0 else 8.0 + 14 * (_popup_count % 3)
	var start := pp + Vector2(-60, dy)
	l.position = start
	l.custom_minimum_size = Vector2(120, 0)
	_popups.add_child(l)
	_popup_count += 1
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", start.y - 26, 1.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.chain().tween_callback(l.queue_free)
	tw.chain().tween_callback(func() -> void: _popup_count = maxi(0, _popup_count - 1))


func _player_screen_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return get_viewport().get_visible_rect().size / 2.0
	return p.get_global_transform_with_canvas().origin


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_input_locked():
		return
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		Story.open_menu()
