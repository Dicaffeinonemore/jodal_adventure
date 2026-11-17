extends Node2D
## 운송 미니게임: the truck drives up a 3-lane road automatically; the player
## only changes lanes. Hitting obstacles lowers cargo condition, which becomes
## the delivery quality at inspection.
##
## Controls: move_left / move_right (keys, touch joystick) or tap the left /
## right half of the screen. Quick item (Q / touch) uses an energy bar.
## Bad condition (fatigue >= 70 or too much coffee) makes the truck drift.
## Pickups: stars pay a bonus (Story.STAR_BONUS), repair kits restore cargo.
## Urgent tasks are shorter but busier; fragile cargo and the truck upgrade
## scale damage (Story.cargo_damage_mult()).
## Fairness: a new obstacle never closes the last open lane near the top, and a "!"
## at the top of the lane warns before it scrolls in. A hit knocks the obstacle off
## the road; during the short safe time after a hit, anything the truck touches is
## pushed aside (no damage) instead of driving through the truck.

const DURATION := 25.0
const URGENT_DURATION := 20.0
const PICKUP_CHANCE := 0.35
const REPAIR_AMOUNT := 10
const LANES := 3
const LANE_W := 44.0
const BASE_SPEED := 100.0
const MAX_SPEED := 150.0
const SPAWN_MIN := 1.2
const SPAWN_MAX := 1.8
const SPAWN_END_FACTOR := 0.8  # spawn gaps shrink to this by the end of the trip
const SPAWN_Y := -70.0  # off screen; the lane warning shows until it scrolls in
const OPEN_WINDOW := 170.0  # obstacles above this y count as blocking their lane
const LANE_SWITCH_TIME := 0.1
const INVULN_TIME := 1.0
const DROWSY_MIN := 3.0
const DROWSY_MAX := 5.5

## kind -> texture, cargo damage, own speed (fraction of road speed it moves *with* us)
const OBSTACLES := {
	"car": {"tex": "res://assets/sprites/placeholder/car_npc.png", "damage": 12, "drift": 0.3},
	"cone": {"tex": "res://assets/sprites/placeholder/cone.png", "damage": 8, "drift": 0.0},
	"bump": {"tex": "res://assets/sprites/placeholder/speed_bump.png", "damage": 6, "drift": 0.0},
	"star": {"tex": "res://assets/sprites/placeholder/pickup_star.png", "damage": 0, "drift": 0.0},
	"repair": {"tex": "res://assets/sprites/placeholder/pickup_repair.png", "damage": 0, "drift": 0.0},
}

enum State { COUNTDOWN, DRIVING, FINISHED }

var cargo := 100
var stars := 0
var _duration := DURATION
var _density := 1.0
var _damage_mult := 1.0
var _state := State.COUNTDOWN
var _elapsed := 0.0
var _speed := BASE_SPEED
var _scroll := 0.0
var _lane := 1
var _spawn_timer := 1.0
var _invuln := 0.0
var _drowsy_timer := 0.0
var _drowsy_block := 0.0  # seconds without drowsiness after an energy bar
var _countdown := 3.0
var _rng := RandomNumberGenerator.new()

var _road_x := 0.0
var _view := Vector2.ZERO
var _truck: Sprite2D
var _obstacles: Array[Dictionary] = []  # {"node": Sprite2D, "kind": String, "lane": int}
var _ui: CanvasLayer
var _progress: ProgressBar
var _cargo_label: Label
var _star_label: Label
var _center_label: Label


func _ready() -> void:
	GameState.reset_input_locks()
	Sound.play_bgm("drive")
	Sound.play("engine")
	_rng.randomize()
	if Story.is_urgent():
		_duration = URGENT_DURATION
		_density = 0.85
	_damage_mult = Story.cargo_damage_mult()
	_truck = Sprite2D.new()
	_truck.texture = load("res://assets/sprites/placeholder/car_player.png") as Texture2D
	_truck.z_index = 5
	add_child(_truck)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_truck.position.x = _lane_x(_lane)
	_drowsy_timer = _rng.randf_range(DROWSY_MIN, DROWSY_MAX)


func _layout() -> void:
	_view = get_viewport_rect().size
	_road_x = (_view.x - LANES * LANE_W) / 2.0
	_truck.position = Vector2(_lane_x(_lane), _view.y - 48)
	queue_redraw()


func _lane_x(lane: int) -> float:
	return _road_x + LANE_W * (lane + 0.5)


# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			_countdown -= delta
			_center_label.text = str(ceili(_countdown)) if _countdown > 0.0 else "출발!"
			if _countdown <= -0.5:
				_center_label.text = ""
				_state = State.DRIVING
		State.DRIVING:
			_drive(delta)
	queue_redraw()


func _drive(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	_speed = lerpf(BASE_SPEED, MAX_SPEED, t)
	_scroll = fmod(_scroll + _speed * delta, 32.0)
	_progress.value = t * 100.0
	_invuln = maxf(0.0, _invuln - delta)
	_truck.modulate.a = 0.4 if _invuln > 0.0 and fmod(_invuln, 0.2) < 0.1 else 1.0

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _elapsed < _duration - 2.0:
		_spawn_obstacle()
		_spawn_timer = _rng.randf_range(SPAWN_MIN, SPAWN_MAX) * lerpf(1.0, SPAWN_END_FACTOR, t) * _density

	_update_drowsiness(delta)

	var truck_rect := _rect_of(_truck).grow(-3)
	for i in range(_obstacles.size() - 1, -1, -1):
		var ob: Dictionary = _obstacles[i]
		var node: Sprite2D = ob["node"]
		var info: Dictionary = OBSTACLES[ob["kind"]]
		node.position.y += _speed * (1.0 - float(info["drift"])) * delta
		if node.position.y > _view.y + 40:
			node.queue_free()
			_obstacles.remove_at(i)
			continue
		var kind := str(ob["kind"])
		var pickup := kind == "star" or kind == "repair"
		if truck_rect.intersects(_rect_of(node).grow(-3)):
			_obstacles.remove_at(i)
			if pickup:
				_collect(kind)
				node.queue_free()
				continue
			if _invuln <= 0.0:
				_hit(int(info["damage"]), kind)
			_knock_away(node)

	if _elapsed >= _duration:
		_finish()


func _update_drowsiness(delta: float) -> void:
	_drowsy_block = maxf(0.0, _drowsy_block - delta)
	if GameState.condition() != GameState.Condition.BAD or _drowsy_block > 0.0:
		return
	_drowsy_timer -= delta
	if _drowsy_timer <= 0.0:
		_drowsy_timer = _rng.randf_range(DROWSY_MIN, DROWSY_MAX)
		var dir := -1 if _rng.randf() < 0.5 else 1
		if _lane + dir < 0 or _lane + dir >= LANES:
			dir = -dir
		_flash_text("졸음! 핸들이 흔들려요", UiTheme.COLOR_WARN)
		_change_lane(dir)


func _spawn_obstacle() -> void:
	var kinds := ["car", "car", "cone", "bump"]
	var kind: String = kinds[_rng.randi() % kinds.size()]
	# Keep a lane open: lanes already holding an obstacle near the top are taken,
	# and a new one may only go where at least one other lane stays free.
	var blocked := {}
	for ob: Dictionary in _obstacles:
		var k := str(ob["kind"])
		if k != "star" and k != "repair" and (ob["node"] as Sprite2D).position.y < OPEN_WINDOW:
			blocked[int(ob["lane"])] = true
	var free: Array[int] = []
	for lane in LANES:
		if not blocked.has(lane):
			free.append(lane)
	if free.size() < 2:
		return  # placing one more would wall off the road; try again next time
	var lane: int = free[_rng.randi() % free.size()]
	_spawn(kind, lane)
	if _rng.randf() < PICKUP_CHANCE:
		var other := (lane + 1 + _rng.randi() % (LANES - 1)) % LANES
		_spawn("repair" if cargo < 100 and _rng.randf() < 0.25 else "star", other)


func _spawn(kind: String, lane: int) -> void:
	var node := Sprite2D.new()
	node.texture = load(str(OBSTACLES[kind]["tex"])) as Texture2D
	node.position = Vector2(_lane_x(lane), SPAWN_Y)
	add_child(node)
	_obstacles.append({"node": node, "kind": kind, "lane": lane})


func _collect(kind: String) -> void:
	Sound.play(kind, 0.06)  # "star" / "repair"
	if kind == "star":
		stars += 1
		GameState.add_money(Story.STAR_BONUS)
		GameState.log_add("money", Story.STAR_BONUS)
		_star_label.text = "별 %d개 (+%s원)" % [stars, Korean.comma(stars * Story.STAR_BONUS)]
		_flash_text("반짝! +%d원" % Story.STAR_BONUS, UiTheme.COLOR_WARN)
	else:
		cargo = mini(100, cargo + REPAIR_AMOUNT)
		_cargo_label.text = "화물 상태 %d%%" % cargo
		_flash_text("응급 수리! 화물 +%d" % REPAIR_AMOUNT, UiTheme.COLOR_GOOD)


func _hit(damage: int, kind: String) -> void:
	Sound.play("crash", 0.1)
	damage = roundi(damage * _damage_mult)
	if GameState.condition() == GameState.Condition.GOOD:
		damage = roundi(damage * 0.8)
	cargo = maxi(0, cargo - damage)
	_invuln = INVULN_TIME
	_cargo_label.text = "화물 상태 %d%%" % cargo
	var msg := "쿵! 화물 -%d" % damage
	if kind == "bump":
		msg = "덜컹! 화물 -%d" % damage
	_flash_text(msg, UiTheme.COLOR_BAD)
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(3, 0), 0.04)
	tw.tween_property(self, "position", Vector2(-3, 0), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)
	# the truck wobbles and flashes red
	var wob := create_tween()
	wob.tween_property(_truck, "rotation", 0.25, 0.06)
	wob.tween_property(_truck, "rotation", -0.18, 0.08)
	wob.tween_property(_truck, "rotation", 0.0, 0.08)
	_truck.self_modulate = Color(1, 0.5, 0.5)
	create_tween().tween_property(_truck, "self_modulate", Color.WHITE, 0.35)


## The obstacle flies off the road, spinning, instead of passing through the truck.
func _knock_away(node: Sprite2D) -> void:
	var side := -1.0 if node.position.x < _truck.position.x else 1.0
	if is_equal_approx(node.position.x, _truck.position.x):
		side = -1.0 if _lane == LANES - 1 else 1.0
	node.z_index = 6
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "position", node.position + Vector2(side * 70.0, -36.0), 0.45) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", side * TAU, 0.45)
	tw.tween_property(node, "modulate:a", 0.0, 0.45).set_delay(0.15)
	tw.chain().tween_callback(node.queue_free)


func _change_lane(dir: int) -> void:
	var target := clampi(_lane + dir, 0, LANES - 1)
	if target == _lane:
		return
	_lane = target
	var tw := create_tween()
	tw.tween_property(_truck, "position:x", _lane_x(_lane), LANE_SWITCH_TIME)


func _finish() -> void:
	_state = State.FINISHED
	_center_label.text = "도착! 화물 상태 %d%%" % cargo
	await get_tree().create_timer(1.5).timeout
	Story.on_drive_finished(cargo, stars)


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.DRIVING:
		return
	if event.is_action_pressed("move_left"):
		_change_lane(-1)
	elif event.is_action_pressed("move_right"):
		_change_lane(1)
	elif event.is_action_pressed("quick_item"):
		_use_item()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var pos := (event as InputEventScreenTouch).position
		if pos.y < 60 and pos.x > _view.x - 80:
			_use_item()
		else:
			_change_lane(-1 if pos.x < _view.x / 2.0 else 1)


func _use_item() -> void:
	if Story.use_quick_item(true) != "":
		_drowsy_block = 8.0


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _view), Color("6aa84f"))
	var road := Rect2(_road_x - 6, 0, LANES * LANE_W + 12, _view.y)
	draw_rect(road, Color("55555c"))
	draw_rect(Rect2(_road_x - 6, 0, 3, _view.y), Color("e8e8e8"))
	draw_rect(Rect2(_road_x + LANES * LANE_W + 3, 0, 3, _view.y), Color("e8e8e8"))
	for i in range(1, LANES):
		var x := _road_x + LANE_W * i - 1
		var y := -32.0 + _scroll
		while y < _view.y:
			draw_rect(Rect2(x, y, 2, 14), Color("f0d060"))
			y += 32.0
	# "!" at the top of a lane while an obstacle is still above the screen
	for ob: Dictionary in _obstacles:
		var k := str(ob["kind"])
		var y := (ob["node"] as Sprite2D).position.y
		if k == "star" or k == "repair" or y > -8.0:
			continue
		var x := _lane_x(int(ob["lane"]))
		var blink := 1.0 if fmod(_elapsed, 0.3) < 0.2 else 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(x, 4), Vector2(x + 8, 18), Vector2(x - 8, 18)]),
				Color(0.95, 0.3, 0.25, blink))
		draw_rect(Rect2(x - 1, 8, 2, 6), Color(1, 1, 1, blink))
		draw_rect(Rect2(x - 1, 15, 2, 2), Color(1, 1, 1, blink))
	# roadside trees for a sense of speed
	var tree_y := fmod(_scroll * 2.0, 64.0) - 64.0
	while tree_y < _view.y:
		draw_circle(Vector2(_road_x - 24, tree_y), 8, Color("3f7f3a"))
		draw_circle(Vector2(_road_x + LANES * LANE_W + 24, tree_y + 32), 8, Color("3f7f3a"))
		tree_y += 64.0


func _rect_of(s: Sprite2D) -> Rect2:
	var size := s.texture.get_size()
	return Rect2(s.position - size / 2.0, size)


# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply(root)
	_ui.add_child(root)
	var m := UiTheme.edge_margin()

	var panel := PanelContainer.new()
	panel.position = Vector2(m, 6)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8))
	root.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	vb.add_child(UiTheme.make_label("%s 납품 중" % Korean.ro(Story.destination_name()), UiTheme.SIZE, UiTheme.COLOR_BORDER, true))
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(120, 8)
	_progress.show_percentage = false
	vb.add_child(_progress)
	_cargo_label = UiTheme.make_label("화물 상태 100%", UiTheme.SIZE_SMALL)
	vb.add_child(_cargo_label)
	_star_label = UiTheme.make_label("별 0개", UiTheme.SIZE_SMALL, UiTheme.COLOR_WARN)
	vb.add_child(_star_label)
	var tags := PackedStringArray()
	if Story.is_urgent():
		tags.append("긴급")
	if bool(Story.current_task().get("fragile", false)):
		tags.append("파손 주의")
	if not tags.is_empty():
		vb.add_child(UiTheme.make_label("[" + " · ".join(tags) + "]", UiTheme.SIZE_SMALL, UiTheme.COLOR_BAD))
	vb.add_child(UiTheme.make_label("컨디션 " + GameState.condition_label(), UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))

	var hint_text := "← → 차선 변경 / Q 에너지바"
	if GameState.is_touch_device():
		hint_text = "화면 왼쪽·오른쪽 터치로 차선 변경 / 오른쪽 위 터치: 에너지바"
	var hint := UiTheme.make_label(hint_text, UiTheme.SIZE_SMALL, UiTheme.COLOR_TEXT)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.offset_top = -18
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint.add_theme_constant_override("outline_size", 4)
	root.add_child(hint)

	_center_label = UiTheme.make_label("3", UiTheme.SIZE_LARGE, UiTheme.COLOR_TEXT, true)
	_center_label.set_anchors_preset(Control.PRESET_CENTER)
	_center_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_center_label.add_theme_constant_override("outline_size", 6)
	root.add_child(_center_label)


func _flash_text(text: String, color: Color) -> void:
	Dialogue.toast(text, color)
