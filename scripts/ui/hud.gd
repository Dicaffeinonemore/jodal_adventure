class_name Hud
extends CanvasLayer
## Top-of-screen status: rank/name/day, fatigue bar + condition (left),
## money/budget/reputation (right), current objective (center).
## Esc / touch B opens the menu (items, save, title).

var _root: Control
var _name_label: Label
var _day_label: Label
var _fatigue_bar: ProgressBar
var _fatigue_label: Label
var _condition_label: Label
var _money_label: Label
var _budget_label: Label
var _rep_label: Label
var _objective: Label
var _fill: StyleBoxFlat


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UiTheme.apply(_root)
	var m := UiTheme.edge_margin()

	# left: who / when / fatigue
	var left := PanelContainer.new()
	left.position = Vector2(m, 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_stylebox_override("panel", UiTheme.panel_box(0.75))
	_root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	left.add_child(lv)
	var top_row := HBoxContainer.new()
	lv.add_child(top_row)
	_name_label = UiTheme.make_label("", UiTheme.SIZE, UiTheme.COLOR_TEXT, true)
	top_row.add_child(_name_label)
	_day_label = UiTheme.make_label("", UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM)
	top_row.add_child(_day_label)
	var fat_row := HBoxContainer.new()
	lv.add_child(fat_row)
	fat_row.add_child(UiTheme.make_label("피로", UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))
	_fatigue_bar = ProgressBar.new()
	_fatigue_bar.custom_minimum_size = Vector2(70, 8)
	_fatigue_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fatigue_bar.max_value = GameState.FATIGUE_MAX
	_fatigue_bar.show_percentage = false
	_fill = (UiTheme.theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat).duplicate()
	_fatigue_bar.add_theme_stylebox_override("fill", _fill)
	fat_row.add_child(_fatigue_bar)
	_fatigue_label = UiTheme.make_label("", UiTheme.SIZE_SMALL)
	fat_row.add_child(_fatigue_label)
	_condition_label = UiTheme.make_label("", UiTheme.SIZE_SMALL)
	lv.add_child(_condition_label)

	# right: money / budget / reputation
	var right := PanelContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_right = -m
	right.offset_top = 6
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_stylebox_override("panel", UiTheme.panel_box(0.75))
	_root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	right.add_child(rv)
	_money_label = UiTheme.make_label("", UiTheme.SIZE_SMALL)
	_budget_label = UiTheme.make_label("", UiTheme.SIZE_SMALL)
	_rep_label = UiTheme.make_label("", UiTheme.SIZE_SMALL)
	for l in [_money_label, _budget_label, _rep_label]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rv.add_child(l)

	# center: objective
	_objective = UiTheme.make_label("", UiTheme.SIZE, UiTheme.COLOR_BORDER)
	_objective.anchor_left = 0.5
	_objective.anchor_right = 0.5
	_objective.offset_top = 8
	_objective.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_objective.add_theme_constant_override("outline_size", 4)
	_root.add_child(_objective)

	GameState.stats_changed.connect(_refresh)
	GameState.task_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_name_label.text = "%s %s " % [GameState.rank_name(), GameState.player_name]
	_day_label.text = "%d일차" % GameState.day
	_fatigue_bar.value = GameState.fatigue
	_fatigue_label.text = " %d" % GameState.fatigue
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
	_money_label.text = "지갑 %s원" % Korean.comma(GameState.money)
	_budget_label.text = "팀 예산 %s만원" % Korean.comma(GameState.budget)
	_rep_label.text = "평판 %d" % GameState.reputation
	_objective.text = Story.objective_text()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_input_locked():
		return
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		Story.open_menu()
