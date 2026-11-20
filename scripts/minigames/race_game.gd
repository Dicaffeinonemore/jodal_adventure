class_name RaceGame
extends Node2D
## 납품 운전 (11/20 rebuilt): a top-down highway run from the 조달청 to the destination.
## The mechanics follow lane-based casual mobile racers (lanes, overtaking combos,
## slipstream, jump, turbo, fuel and checkpoints); names, art and layout are our own.
##
## - LANES lanes go up the screen and acceleration is automatic. move_left / move_right
##   change one lane per press, move_down brakes to BRAKE_SPEED, move_up / interact jumps
##   over a car, a barricade or an oil puddle (landing on a car roof bounces again),
##   quick_item / run fires the turbo (full gauge, or an energy drink from the bag):
##   faster and invincible for TURBO_TIME, cars in the way pull aside.
## - Overtaking builds a combo (COMBO_WINDOW between passes) for points and turbo gauge;
##   swerving out of a car's lane right behind it ("아슬아슬") counts double. Staying
##   right behind a car (SLIP_RANGE) is the slipstream: faster and the gauge fills, but
##   you have to swerve before you hit it.
## - Fuel drains all the time; the CHECKPOINTS gates and fuel cans refill it. Out of fuel
##   = a tow truck brings the cargo in late (task.late: -reputation at the report).
## - Hitting a car or a barricade costs speed and cargo (Story.cargo_damage_mult(), good
##   condition takes 20% off). Oil puddles (second half) slide you one lane over. Bad
##   condition: now and then a drowsy lane wobble (the turbo / a drink stops it a while).
## - Result: cargo -> delivery quality; stars = picked up + bonus for fuel left and score.
## Fairness: a new row of traffic always leaves two lanes open, cars never spawn beside a
## barricade and steer around them, hazards get a blinking "!" at the top edge before
## they scroll in, and cars change lanes only well ahead of the player after blinking.
## Player-visible text: Story.DRIVE_TEXT. Before the countdown: the paged tutorial
## (TutorialPages + Story.tutorial("drive"), pictures: paint_tutorial()).
## Easy destinations: TrackData.easy_for().

## Tests: drive by itself / pick the course.
static var autopilot := false
static var force_track := -1

const LANES := 5
const LANE_W := 30.0
const ROAD_HALF := 75.0  # LANES * LANE_W / 2
const LANE_SHIFT := 300.0  # px/s sideways while changing lanes
const MAX_SPEED := 230.0
const TIER_SPEED := 10.0  # cruising speed added per checkpoint passed
const SLIP_SPEED := 60.0
const TURBO_SPEED := 390.0
const ACCEL := 150.0
const SLOW := 220.0  # back down to cruising after a turbo / slipstream
const BRAKE := 420.0
const COAST := 110.0  # out of fuel
const BRAKE_SPEED := 70.0
const CRASH_KEEP := 0.4  # speed kept after a hit
const INVULN := 1.2
const CAM_LEAD := 95.0  # the camera looks this far ahead of the truck
const COUNTDOWN := 3.0
const HIT := Vector2(15.0, 27.0)  # car vs car overlap (18x30 sprites, a little forgiving)
const JUMP_TIME := 0.75
const BOUNCE_TIME := 0.5
const JUMP_COOLDOWN := 0.3
const TURBO_TIME := 3.0
const FUEL_RATE := 5.5  # per second
const FUEL_CHECKPOINT := 30.0
const FUEL_CAN := 20.0
const FUEL_LOW := 25.0
const CHECKPOINTS := 4
const COMBO_WINDOW := 2.5
const CHACHA_TIME := 1.5
const SLIP_RANGE := Vector2(36.0, 95.0)  # center distance to the car ahead in your lane
const SLIP_DELAY := 0.4
const SPAWN_EVERY := Vector2(0.6, 1.0)  # seconds between rows of traffic
const CAR_SPEED := Vector2(110.0, 165.0)
const CAR_SIDE := 55.0  # lateral px/s of a traffic car changing lanes
const DESPAWN_BEHIND := 260.0
const WARN_AHEAD := 600.0
const BARRICADES := 7
const OILS := 4
const STAR_GROUPS := [3, 3, 1, 1]  # stars in a column
const FUEL_CANS := 3
const DRINKS := 2
const TOOLBOXES := 1
const HAZARD_GAP := 260.0
const DAMAGE := {"car": 8, "barricade": 6}
const TOW_DAMAGE := 10.0
const TOW_AFTER := 150.0  # seconds: stuck somehow -> tow
const SCORE_PER_STAR := 10000.0  # bonus stars at the end (max 3)
const FUEL_PER_STAR := 25.0  # bonus stars for fuel left (max 2)
const KMH := 0.45
const TRAFFIC_COLORS := [Color("ef6b5b"), Color("7ed37e"), Color("b38cff"), Color("f2c14e"), Color("6fb6ff"), Color("f0f0f0")]
const DROWSY_MIN := 5.0
const DROWSY_MAX := 7.5
const SPRITES := "res://assets/sprites/placeholder/"
const BUILDING_SCALE := 2.0

enum State { COUNTDOWN, DRIVING, FINISHED, GUIDE }

var cargo := 100
var stars := 0
var score := 0
var best_combo := 0
var track_index := 0
var finished_late := false
var stats := {"car": 0, "barricade": 0, "oil": 0, "passes": 0, "jumps": 0, "turbo": 0}

var _state := State.COUNTDOWN
var _t := -COUNTDOWN
var _length := 8000.0
var _theme: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _damage_mult := 1.0
var _cargo_f := 100.0
var _easy: Dictionary = {}  # TrackData.easy_for (tests that force a course drive the normal trip)
var _fuel_rate := FUEL_RATE
var _tier := 0  # checkpoints passed

# player (world: road center x = 0, driving toward -y; the finish line is at -_length)
var _x := 0.0
var _y := 0.0
var _lane := 2
var _speed := 0.0
var _air_t := 0.0
var _air_total := JUMP_TIME
var _jump_cd := 0.0
var _turbo_t := 0.0
var _invuln_t := 0.0
var _fuel := 100.0
var _fuel_warned := false
var _empty_t := 0.0
var _gauge := 0.0
var _combo := 0
var _combo_t := 0.0
var _slip_t := 0.0
var _spin_t := 0.0
var _spawn_t := 1.0
var _drowsy_timer := 6.0
var _drowsy_t := 0.0
var _drowsy_block := 0.0
var _auto_cd := 0.0
var _delta := 0.0

## {node, blink, lane (target), x, y, speed (cruise), cur (this frame), passed, ghost (no
## collisions), chacha (passing it now counts double), plan (-1/0/1 lane change), signal, shoved}
var _cars: Array[Dictionary] = []
var _props: Array[Dictionary] = []  # {kind, node, lane, y, done}
var _gates: Array[Dictionary] = []  # {y, node, passed}
var _truck: Sprite2D
var _shadow: Shadow
var _fx: Effects
var _marks: WarnMarks
var _cam: Camera2D
var _ui: RaceHud


static func tx(key: String) -> String:
	return str(Story.DRIVE_TEXT.get(key, key))


func _ready() -> void:
	GameState.reset_input_locks()
	Sound.play_bgm("drive")
	Sound.play("engine")
	_rng.randomize()
	track_index = force_track if force_track >= 0 else TrackData.for_destination(Story.destination_id(), _rng)
	var info: Dictionary = TrackData.TRACKS[track_index]
	_theme = TrackData.THEMES[str(info["theme"])]
	_length = float(info["length"])
	if force_track < 0:
		_easy = TrackData.easy_for(Story.destination_id())
	_fuel_rate = float(_easy.get("fuel_rate", FUEL_RATE))
	_damage_mult = Story.cargo_damage_mult()
	_drowsy_timer = _rng.randf_range(DROWSY_MIN, DROWSY_MAX)

	var road := RoadView.new()
	add_child(road)
	road.build(_theme, _length, track_index)
	_add_building("pps", true)
	_add_building(Story.destination_id(), false)
	_place_gates()
	_place_props()
	for y: float in [-300.0, -470.0]:
		_spawn_row(y)
	_shadow = Shadow.new()
	_shadow.z_index = 4
	add_child(_shadow)
	_truck = Sprite2D.new()
	_truck.texture = load(SPRITES + "car_player.png") as Texture2D
	_truck.z_index = 7
	add_child(_truck)
	_fx = Effects.new()
	_fx.z_index = 6
	add_child(_fx)
	_marks = WarnMarks.new()
	_marks.game = self
	_marks.z_index = 9
	add_child(_marks)
	_x = _lane_x(_lane)
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_ui = RaceHud.new()
	_ui.game = self
	add_child(_ui)
	_ui.build(str(info["name"]))
	_sync()
	if not autopilot and force_track < 0:  # not in tests
		_state = State.GUIDE
		_show_tutorial()


func _show_tutorial() -> void:
	var tp := TutorialPages.new()
	add_child(tp)
	await tp.run(Story.tutorial("drive"), func(ci: Control, pic: String, labels: Array, t: float) -> void:
		RaceGame.paint_tutorial(ci, pic, labels, t))
	tp.queue_free()
	if _state == State.GUIDE:
		_state = State.COUNTDOWN


## The 조달청 below the start and the destination past the end of the road, with name boards.
func _add_building(id: String, start: bool) -> void:
	var tex := load(SPRITES + "bld_%s.png" % id) as Texture2D
	if tex == null:
		return
	var size := tex.get_size() * BUILDING_SCALE
	var center := Vector2(0.0, 40.0 + size.y / 2.0 + 30.0) if start \
			else Vector2(0.0, -_length - 40.0 - size.y / 2.0 - 60.0)
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(BUILDING_SCALE, BUILDING_SCALE)
	s.position = center
	s.z_index = 2
	add_child(s)
	var board := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("23489a") if start else Color("8a5a36")
	sb.border_color = Color("261e2c")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	board.add_theme_stylebox_override("panel", sb)
	var text := tx("start_board") % tx("pps") if start else tx("end_board") % Story.destination_name()
	board.add_child(UiTheme.make_label(text, UiTheme.SIZE, Color("fbf3dc"), true))
	board.z_index = 8
	add_child(board)
	board.reset_size()
	board.position = (center + Vector2(-board.size.x / 2.0, -size.y / 2.0 - 22.0)).round()


func _place_gates() -> void:
	for k in range(1, CHECKPOINTS + 1):
		var y := -_length * k / float(CHECKPOINTS + 1)
		var g := Gate.new()
		g.text = tx("gate") % k
		g.position = Vector2(0.0, y)
		g.z_index = 3
		add_child(g)
		_gates.append({"y": y, "node": g, "passed": false})
	var fin := Gate.new()
	fin.text = tx("finish_gate")
	fin.finish = true
	fin.position = Vector2(0.0, -_length)
	fin.z_index = 3
	add_child(fin)


## Barricades along the whole road, oil puddles in the second half, then pickups (stars
## in short columns, fuel cans, energy drinks, a toolbox) where there is no hazard.
func _place_props() -> void:
	var lo := -420.0
	var hi := -_length + 420.0
	var bars: int = int(_easy.get("barricades", BARRICADES)) + (2 if Story.is_urgent() else 0)
	var ys: Array[float] = []
	_place_hazards("barricade", bars, lo, hi, ys)
	_place_hazards("oil", int(_easy.get("oils", OILS)), -_length * 0.45, hi, ys)
	var pickups: Array = []
	for g: int in STAR_GROUPS:
		pickups.append(["star", g])
	for i in FUEL_CANS:
		pickups.append(["fuel", 1])
	for i in DRINKS:
		pickups.append(["drink", 1])
	for i in TOOLBOXES:
		pickups.append(["toolbox", 1])
	pickups.shuffle()
	for i in pickups.size():
		var e: Array = pickups[i]
		var y := lo - (lo - hi) * (i + _rng.randf_range(0.2, 0.8)) / pickups.size()
		var lane := _rng.randi_range(0, LANES - 1)
		for k in int(e[1]):
			var py := y - k * 40.0
			if not _hazard_near(lane, py, 70.0, false):
				_add_prop(str(e[0]), lane, py)


func _place_hazards(kind: String, n: int, a: float, b: float, ys: Array[float]) -> void:
	for i in n:
		for attempt in 6:
			var y := a - (a - b) * (i + _rng.randf_range(0.1, 0.9)) / n
			var ok := true
			for other: float in ys:
				if absf(other - y) < HAZARD_GAP:
					ok = false
			for g: Dictionary in _gates:
				if absf(float(g["y"]) - y) < 90.0:
					ok = false
			if ok:
				ys.append(y)
				_add_prop(kind, _rng.randi_range(0, LANES - 1), y)
				break


func _add_prop(kind: String, lane: int, y: float) -> void:
	var p := Prop.new()
	p.kind = kind
	p.position = Vector2(_lane_x(lane), y)
	p.z_index = 3
	add_child(p)
	_props.append({"kind": kind, "node": p, "lane": lane, "y": y, "done": false})


# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			var before := _t
			_t += delta
			if ceili(-before) != ceili(-_t):
				Sound.play("select" if _t < 0.0 else "confirm")
			_ui.set_center(str(ceili(-_t)) if _t < 0.0 else tx("go"))
			if _t >= 0.0:
				_state = State.DRIVING
				_t = 0.0
		State.DRIVING:
			_t += delta
			if _t > 0.8 and _t < 1.0:
				_ui.set_center("")
			_drive(delta)
			_move_cars(delta)
			_spawn(delta)
			_check_props()
			_check_gates()
			if _state == State.DRIVING and _y <= -_length:
				_finish(false, false)
		State.FINISHED:
			_move_cars(delta)
			_speed = move_toward(_speed, 0.0, BRAKE * 1.2 * delta)
			_y -= _speed * delta
			_x = move_toward(_x, _lane_x(_lane), LANE_SHIFT * delta)
			if _air_t > 0.0:
				_air_t = maxf(0.0, _air_t - delta)
	_sync()
	_ui.refresh()


func _drive(delta: float) -> void:
	_delta = delta
	_read_input()
	_jump_cd = maxf(0.0, _jump_cd - delta)
	_invuln_t = maxf(0.0, _invuln_t - delta)
	_turbo_t = maxf(0.0, _turbo_t - delta)
	_spin_t = maxf(0.0, _spin_t - delta)
	if _combo > 0:
		_combo_t -= delta
		if _combo_t <= 0.0:
			_combo = 0
	var gap := _gap_ahead()
	if _air_t <= 0.0 and gap >= SLIP_RANGE.x and gap <= SLIP_RANGE.y:
		_slip_t += delta
		if _slip_t >= SLIP_DELAY and _slip_t - delta < SLIP_DELAY:
			_float(tx("slip"), Vector2(_x, _y - 26.0), UiTheme.COLOR_ACCENT)
	else:
		_slip_t = 0.0
	if slipping():
		_add_gauge(8.0 * delta)

	var target := MAX_SPEED + TIER_SPEED * _tier
	if slipping():
		target += SLIP_SPEED
	if _turbo_t > 0.0:
		target = TURBO_SPEED
	var rate := ACCEL if _speed < target else SLOW
	if _fuel <= 0.0:
		target = 0.0
		rate = COAST
	elif Input.is_action_pressed("move_down"):  # the autopilot never presses it; tests do
		target = minf(target, BRAKE_SPEED)
		rate = ACCEL if _speed < target else BRAKE
	_speed = move_toward(_speed, target, rate * delta)
	_y -= _speed * delta
	_x = move_toward(_x, _lane_x(_lane), LANE_SHIFT * delta)
	if _air_t > 0.0:
		_air_t -= delta
		if _air_t <= 0.0:
			_land()
	_burn_fuel(delta)
	_drowsy(delta)
	if _t > TOW_AFTER:
		_tow()


func _read_input() -> void:
	var dir := 0
	var jump := false
	var turbo := false
	if autopilot:
		var a := _autopilot()
		dir = int(a["dir"])
		jump = bool(a["jump"])
		turbo = bool(a["turbo"])
	else:
		if Input.is_action_just_pressed("move_left"):
			dir -= 1
		if Input.is_action_just_pressed("move_right"):
			dir += 1
		jump = Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("interact")
		turbo = Input.is_action_just_pressed("quick_item") or Input.is_action_just_pressed("run")
	if dir != 0:
		_change_lane(dir, true)
	if jump:
		_jump()
	if turbo:
		_turbo()


func _change_lane(dir: int, by_player: bool) -> void:
	var to := clampi(_lane + dir, 0, LANES - 1)
	if to == _lane:
		return
	if by_player:  # swerving out from right behind a car: passing it now counts double
		for c: Dictionary in _cars:
			var d := _y - float(c["y"])
			if absf(float(c["x"]) - _x) < 20.0 and d > 0.0 and d < 75.0:
				c["chacha"] = CHACHA_TIME
	_lane = to


func _jump() -> void:
	if _air_t > 0.0 or _jump_cd > 0.0 or _fuel <= 0.0:
		return
	_air_total = JUMP_TIME
	_air_t = JUMP_TIME
	_slip_t = 0.0
	stats["jumps"] = int(stats["jumps"]) + 1
	Sound.play("pop")


## Landing on a car roof bounces again (no harm done) and counts toward the combo.
func _land() -> void:
	_jump_cd = JUMP_COOLDOWN
	for c: Dictionary in _cars:
		if float(c["ghost"]) <= 0.0 and absf(float(c["x"]) - _x) < HIT.x and absf(float(c["y"]) - _y) < HIT.y:
			_air_total = BOUNCE_TIME
			_air_t = BOUNCE_TIME
			_bump_combo()
			var pts := 300 * mini(_combo, 10)
			score += pts
			_add_gauge(10.0)
			_float(tx("stomp") % pts, Vector2(_x, _y - 30.0), UiTheme.COLOR_WARN)
			Sound.play("pop")
			return


func _turbo() -> void:
	if _state != State.DRIVING or _turbo_t > 0.0 or _fuel <= 0.0:
		return
	if _gauge >= 100.0:
		_gauge = 0.0
	elif GameState.item_count("energybar") > 0:
		Story.use_quick_item(true)  # drinks one from the bag (also eases fatigue)
	else:
		_ui.flash(tx("turbo_empty"), UiTheme.COLOR_DIM)
		return
	_turbo_t = TURBO_TIME
	_drowsy_block = 8.0
	_speed = maxf(_speed, MAX_SPEED)
	stats["turbo"] = int(stats["turbo"]) + 1
	Sound.play("repair")
	_float(tx("turbo"), Vector2(_x, _y - 34.0), UiTheme.COLOR_WARN)


func _burn_fuel(delta: float) -> void:
	_fuel = maxf(0.0, _fuel - _fuel_rate * delta)
	if _fuel > FUEL_LOW + 5.0:
		_fuel_warned = false
	elif _fuel > 0.0 and _fuel <= FUEL_LOW and not _fuel_warned:
		_fuel_warned = true
		_ui.flash(tx("fuel_low"), UiTheme.COLOR_WARN)
	if _fuel > 0.0:
		_empty_t = 0.0
		return
	if _empty_t == 0.0:
		_ui.flash(tx("fuel_out"), UiTheme.COLOR_BAD)
	_empty_t += delta
	if _speed <= 1.0 and _empty_t > 1.0:
		_tow()


func _tow() -> void:
	_wear(TOW_DAMAGE)
	_finish(true, true)


func _drowsy(delta: float) -> void:
	_drowsy_block = maxf(0.0, _drowsy_block - delta)
	if autopilot or GameState.condition() != GameState.Condition.BAD or _drowsy_block > 0.0:
		return
	if _drowsy_t > 0.0:
		_drowsy_t -= delta
		if _drowsy_t <= 0.0:
			var dir := 1 if _lane == 0 else (-1 if _lane == LANES - 1 or _rng.randf() < 0.5 else 1)
			_change_lane(dir, false)
		return
	_drowsy_timer -= delta
	if _drowsy_timer <= 0.0:
		_drowsy_timer = _rng.randf_range(DROWSY_MIN, DROWSY_MAX)
		_drowsy_t = 0.6
		_ui.flash(tx("drowsy"), UiTheme.COLOR_WARN)


func _finish(late: bool, towed: bool) -> void:
	if _state == State.FINISHED:
		return
	_state = State.FINISHED
	finished_late = late
	var fuel_bonus := 0 if late else clampi(floori(_fuel / FUEL_PER_STAR), 0, 2)
	var score_bonus := clampi(floori(score / SCORE_PER_STAR), 0, 3)
	var bonus := fuel_bonus + score_bonus
	stars += bonus
	stats["score"] = score
	stats["combo"] = best_combo
	stats["fuel"] = roundi(_fuel)
	GameState.task["late"] = late
	var lines := PackedStringArray()
	if towed:
		lines.append(tx("towed"))
		lines.append(tx("cargo") % cargo)
	else:
		lines.append(tx("arrive") % cargo)
	lines.append(tx("result_score") % [Korean.comma(score), best_combo])
	if bonus > 0:
		lines.append(tx("result_bonus") % bonus)
	_ui.set_center("\n".join(lines))
	Sound.play("bad" if late else "jingle_good")
	await get_tree().create_timer(2.5).timeout
	Story.on_drive_finished(cargo, stars)


# ---------------------------------------------------------------- traffic
func _spawn(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	var mult := float(_easy.get("traffic", 1.0)) * (0.85 if Story.is_urgent() else 1.0) * (1.0 - 0.05 * _tier)
	_spawn_t = _rng.randf_range(SPAWN_EVERY.x, SPAWN_EVERY.y) * mult
	var y := _y - view_ahead() - 50.0
	if y > -_length + 500.0:
		_spawn_row(y)


## One to three cars side by side, never closing more than LANES - 2 lanes around y and
## never next to a hazard.
func _spawn_row(y: float) -> void:
	var want := 1
	var r := _rng.randf()
	if r < 0.32 + 0.04 * _tier:
		want = 2
	if _tier >= 2 and r < 0.07:
		want = 3
	var lanes: Array[int] = []
	for l in LANES:
		lanes.append(l)
	lanes.shuffle()
	var placed := 0
	for l: int in lanes:
		if placed >= want or _blocked_lanes(y, 110.0) >= LANES - 2:
			break
		if not _lane_free(l, y, 75.0, {}) or _hazard_near(l, y, 120.0, true):
			continue
		_add_car(l, y)
		placed += 1


func _add_car(lane: int, y: float) -> void:
	var s := Sprite2D.new()
	var plain := _rng.randf() < 0.33
	s.texture = load(SPRITES + ("car_npc.png" if plain else "car_rival.png")) as Texture2D
	if not plain:
		s.self_modulate = TRAFFIC_COLORS[_rng.randi() % TRAFFIC_COLORS.size()]
	s.z_index = 5
	var blink := ColorRect.new()
	blink.color = Color("ffd23c")
	blink.size = Vector2(3, 3)
	blink.hide()
	s.add_child(blink)
	add_child(s)
	var plan := 0
	if _rng.randf() < 0.2:
		plan = -1 if _rng.randf() < 0.5 else 1
	_cars.append({"node": s, "blink": blink, "lane": lane, "x": _lane_x(lane), "y": y,
			"speed": _rng.randf_range(CAR_SPEED.x, CAR_SPEED.y) * (1.0 + 0.04 * _tier), "cur": 0.0,
			"passed": false, "ghost": 0.0, "chacha": 0.0, "plan": plan, "signal": -1.0, "shoved": false})


func _move_cars(delta: float) -> void:
	for i in range(_cars.size() - 1, -1, -1):
		var c: Dictionary = _cars[i]
		var y := float(c["y"])
		var spd := float(c["speed"])
		var lane := int(c["lane"])
		c["ghost"] = maxf(0.0, float(c["ghost"]) - delta)
		c["chacha"] = maxf(0.0, float(c["chacha"]) - delta)
		var shoved := bool(c["shoved"])
		if shoved:
			spd = 60.0
		elif lane >= 0 and lane < LANES:
			# planned lane change: blink first, only well ahead of the player
			var ahead := _y - y
			if int(c["plan"]) != 0 and float(c["signal"]) < 0.0 and ahead > 170.0 and ahead < 420.0:
				c["signal"] = 0.9
			if float(c["signal"]) >= 0.0:
				c["signal"] = float(c["signal"]) - delta
				if float(c["signal"]) < 0.0:
					var to := lane + int(c["plan"])
					if to >= 0 and to < LANES and ahead > 120.0 and _lane_free(to, y, 60.0, c) \
							and not _hazard_near(to, y, 100.0, true):
						c["lane"] = to
					c["plan"] = 0
			# barricade ahead in its lane: move over, or wait behind it
			var bar := _hazard_dist(int(c["lane"]), y, "barricade")
			if bar >= 0.0 and bar < 150.0:
				var moved := false
				var dirs: Array[int] = [-1, 1]
				if _rng.randf() < 0.5:
					dirs.reverse()
				for d: int in dirs:
					var to := int(c["lane"]) + d
					if to >= 0 and to < LANES and _lane_free(to, y, 55.0, c) and not _hazard_near(to, y, 90.0, true):
						c["lane"] = to
						moved = true
						break
				if not moved and bar < 45.0:
					spd = 0.0
			# keep a distance to the car in front
			var lead := _lead_car(c)
			if not lead.is_empty():
				var gap := y - float(lead["y"])
				if gap < 32.0:
					spd = minf(spd, float(lead["cur"]) * 0.8)
				elif gap < 46.0:
					spd = minf(spd, float(lead["cur"]))
		if _state == State.COUNTDOWN or _state == State.GUIDE:
			spd = 0.0
		c["cur"] = spd
		c["y"] = y - spd * delta
		c["x"] = move_toward(float(c["x"]), _lane_x(int(c["lane"])), CAR_SIDE * (2.5 if shoved else 1.0) * delta)
		y = float(c["y"])
		if y > _y + DESPAWN_BEHIND or y < _y - 1100.0 or y < -_length + 20.0:
			(c["node"] as Node).queue_free()
			_cars.remove_at(i)
			continue
		if not bool(c["passed"]) and y > _y + 20.0:
			c["passed"] = true
			if _state == State.DRIVING:
				_on_pass(c)
		elif bool(c["passed"]) and y < _y - 30.0:
			c["passed"] = false
		if _state == State.DRIVING and _air_t <= 0.0 and float(c["ghost"]) <= 0.0 \
				and absf(float(c["x"]) - _x) < HIT.x and absf(y - _y) < HIT.y:
			if _turbo_t > 0.0:
				_shove(c)
			elif _invuln_t <= 0.0:
				_crash(c)


## The nearest car ahead of c that overlaps it sideways, or {}.
func _lead_car(c: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_gap := INF
	var y := float(c["y"])
	for o: Dictionary in _cars:
		if is_same(o, c) or absf(float(o["x"]) - float(c["x"])) > 20.0:
			continue
		var gap := y - float(o["y"])
		if gap > 0.0 and gap < best_gap:
			best_gap = gap
			best = o
	return best


func _on_pass(c: Dictionary) -> void:
	if float(c["ghost"]) > 0.0:
		return
	_bump_combo()
	stats["passes"] = int(stats["passes"]) + 1
	var chacha := float(c["chacha"]) > 0.0
	var pts := 100 * mini(_combo, 10) * (2 if chacha else 1)
	score += pts
	_add_gauge(4.0 + mini(_combo, 6) + (6.0 if chacha else 0.0))
	var text := tx("combo_pass") % [_combo, pts] if _combo > 1 else tx("pass") % pts
	if chacha:
		text = tx("chacha") + text
	_float(text, Vector2(_x, _y - 22.0), UiTheme.COLOR_WARN if chacha else UiTheme.COLOR_TEXT)
	Sound.play("coin" if _combo % 5 == 0 else "blip")


func _bump_combo() -> void:
	_combo += 1
	_combo_t = COMBO_WINDOW
	best_combo = maxi(best_combo, _combo)


func _crash(c: Dictionary) -> void:
	_speed *= CRASH_KEEP
	_invuln_t = INVULN
	c["ghost"] = INVULN
	c["speed"] = float(c["speed"]) + 30.0  # nudged ahead
	_combo = 0
	_slip_t = 0.0
	_damage("car")


## Turbo: the car pulls aside onto the shoulder.
func _shove(c: Dictionary) -> void:
	c["ghost"] = 3.0
	c["shoved"] = true
	c["lane"] = -1 if float(c["x"]) <= _x else LANES
	score += 150
	_float(tx("shove") % 150, Vector2(float(c["x"]), float(c["y"]) - 18.0), UiTheme.COLOR_WARN)
	Sound.play("crash", 0.2)


# ---------------------------------------------------------------- road things
func _check_props() -> void:
	for p: Dictionary in _props:
		if bool(p["done"]):
			continue
		var py := float(p["y"])
		var kind := str(p["kind"])
		var hazard := kind == "barricade" or kind == "oil"
		if absf(_lane_x(int(p["lane"])) - _x) > (13.0 if hazard else 16.0) or absf(py - _y) > (19.0 if hazard else 21.0):
			continue
		var node: Node2D = p["node"]
		if hazard and (_air_t > 0.0 or (_invuln_t > 0.0 and _turbo_t <= 0.0)):
			continue
		match kind:
			"barricade":
				p["done"] = true
				if _turbo_t > 0.0:
					score += 100
					Sound.play("crash", 0.2)
				else:
					_speed *= CRASH_KEEP
					_invuln_t = INVULN
					_combo = 0
					_damage("barricade")
				_knock_away(node)
			"oil":
				if _turbo_t <= 0.0:  # the turbo just drives through
					p["done"] = true
					stats["oil"] = int(stats["oil"]) + 1
					_change_lane(1 if _lane == 0 else (-1 if _lane == LANES - 1 or _rng.randf() < 0.5 else 1), false)
					_spin_t = 0.5
					_ui.flash(tx("oil"), UiTheme.COLOR_WARN)
			"star":
				p["done"] = true
				stars += 1
				score += 200
				GameState.add_money(Story.STAR_BONUS)
				GameState.log_add("money", Story.STAR_BONUS)
				Sound.play("star", 0.06)
				_float(tx("star") % Story.STAR_BONUS, node.position + Vector2(0, -12), UiTheme.COLOR_WARN)
				node.queue_free()
			"fuel":
				p["done"] = true
				_fuel = minf(100.0, _fuel + FUEL_CAN)
				Sound.play("repair")
				_float(tx("fuel_can") % int(FUEL_CAN), node.position + Vector2(0, -12), UiTheme.COLOR_GOOD)
				node.queue_free()
			"drink":
				p["done"] = true
				_add_gauge(40.0)
				Sound.play("repair")
				_float(tx("drink") % 40, node.position + Vector2(0, -12), UiTheme.COLOR_GOOD)
				node.queue_free()
			"toolbox":
				p["done"] = true
				_cargo_f = minf(100.0, _cargo_f + 10.0)
				cargo = roundi(_cargo_f)
				Sound.play("repair")
				_float(tx("toolbox") % 10, node.position + Vector2(0, -12), UiTheme.COLOR_GOOD)
				node.queue_free()


func _check_gates() -> void:
	for k in _gates.size():
		var g: Dictionary = _gates[k]
		if bool(g["passed"]) or _y > float(g["y"]):
			continue
		g["passed"] = true
		_tier += 1
		_fuel = minf(100.0, _fuel + FUEL_CHECKPOINT)
		score += 1000
		(g["node"] as Gate).modulate = Color(1, 1, 1, 0.6)
		_ui.flash(tx("checkpoint") % [k + 1, CHECKPOINTS, int(FUEL_CHECKPOINT)], UiTheme.COLOR_GOOD)


func _damage(kind: String) -> void:
	var dmg := roundi(int(DAMAGE.get(kind, 5)) * _damage_mult)
	if GameState.condition() == GameState.Condition.GOOD:
		dmg = roundi(dmg * 0.8)
	stats[kind] = int(stats.get(kind, 0)) + 1
	_wear(float(dmg))
	Sound.play("crash", 0.1)
	_ui.flash(tx("crash_" + kind) % dmg, UiTheme.COLOR_BAD)
	_truck.self_modulate = Color(1, 0.5, 0.5)
	create_tween().tween_property(_truck, "self_modulate", Color.WHITE, 0.35)
	var shake := create_tween()
	for k in 3:
		shake.tween_property(_cam, "offset", Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4)), 0.04)
	shake.tween_property(_cam, "offset", Vector2.ZERO, 0.04)


func _wear(amount: float) -> void:
	_cargo_f = maxf(0.0, _cargo_f - amount)
	cargo = roundi(_cargo_f)


func _knock_away(node: Node2D) -> void:
	var side := Vector2.RIGHT if node.position.x >= _x else Vector2.LEFT
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "position", node.position + side * 40.0 + Vector2(0, -_speed * 0.2), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", TAU, 0.45)
	tw.tween_property(node, "modulate:a", 0.0, 0.45).set_delay(0.15)
	tw.chain().tween_callback(node.queue_free)


## Score popup that floats up and fades, in the world.
func _float(text: String, at: Vector2, color: Color) -> void:
	var l := UiTheme.make_label(text, UiTheme.SIZE, color, true)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.15))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 10
	add_child(l)
	l.reset_size()
	l.position = (at - Vector2(l.size.x / 2.0, l.size.y)).round()
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)


func _add_gauge(amount: float) -> void:
	var was := _gauge
	_gauge = minf(100.0, _gauge + amount)
	if was < 100.0 and _gauge >= 100.0:
		Sound.play("star")
		_float(tx("turbo_full"), Vector2(_x, _y - 46.0), UiTheme.COLOR_WARN)


# ---------------------------------------------------------------- queries
func _lane_x(lane: int) -> float:
	return (lane - (LANES - 1) / 2.0) * LANE_W


## Center distance to the nearest car ahead in the player's lane (INF if none).
func _gap_ahead() -> float:
	var best := INF
	for c: Dictionary in _cars:
		if float(c["ghost"]) > 0.0 or absf(float(c["x"]) - _x) > 12.0:
			continue
		var d := _y - float(c["y"])
		if d > 0.0:
			best = minf(best, d)
	return best


func _lane_free(lane: int, y: float, r: float, except: Dictionary) -> bool:
	var lx := _lane_x(lane)
	for o: Dictionary in _cars:
		if is_same(o, except):
			continue
		if (int(o["lane"]) == lane or absf(float(o["x"]) - lx) < 22.0) and absf(float(o["y"]) - y) < r:
			return false
	return true


func _hazard_near(lane: int, y: float, r: float, only_live: bool) -> bool:
	for p: Dictionary in _props:
		var kind := str(p["kind"])
		if (kind == "barricade" or kind == "oil") and int(p["lane"]) == lane and absf(float(p["y"]) - y) < r \
				and not (only_live and bool(p["done"])):
			return true
	return false


## Distance from y to the next live hazard of this kind ahead in the lane, or -1.
func _hazard_dist(lane: int, y: float, kind: String) -> float:
	var best := -1.0
	for p: Dictionary in _props:
		if str(p["kind"]) != kind or bool(p["done"]) or int(p["lane"]) != lane:
			continue
		var d := y - float(p["y"])
		if d > 0.0 and (best < 0.0 or d < best):
			best = d
	return best


func _blocked_lanes(y: float, r: float) -> int:
	var n := 0
	for l in LANES:
		if not _lane_free(l, y, r, {}) or _hazard_near(l, y, r, true):
			n += 1
	return n


# ---------------------------------------------------------------- autopilot (tests)
## Picks the lane with the most room ahead (reachable without hitting anything on the
## way, a pickup is a small plus), jumps when nothing else helps, turbo when full.
func _autopilot() -> Dictionary:
	_auto_cd = maxf(0.0, _auto_cd - _delta)
	var best := _lane
	var best_v := -INF
	for l in LANES:
		var ok := true
		var k := _lane
		while k != l:
			k += signi(l - _lane)
			if not _row_clear(k):
				ok = false
				break
		if not ok:
			continue
		var v := _lane_clear(l) - absi(l - _lane) * 20.0 + (25.0 if l == _lane else 0.0) + _pickup_value(l)
		if v > best_v:
			best_v = v
			best = l
	var dir := 0
	if best != _lane and _auto_cd <= 0.0:
		dir = signi(best - _lane)
		_auto_cd = 0.12
	var jump := _air_t <= 0.0 and dir == 0 and _lane_clear(_lane) < 40.0
	return {"dir": dir, "jump": jump, "turbo": _gauge >= 100.0 and _turbo_t <= 0.0}


## Room ahead in a lane, in px at the player's speed (cars count by closing speed).
func _lane_clear(lane: int) -> float:
	var lx := _lane_x(lane)
	var best := 600.0
	for c: Dictionary in _cars:
		if float(c["ghost"]) > 0.0 or (int(c["lane"]) != lane and absf(float(c["x"]) - lx) > 22.0):
			continue
		var d := _y - float(c["y"])
		if d < -HIT.y:
			continue
		if d < HIT.y + 4.0:
			return 0.0
		var rel := maxf(_speed - float(c["cur"]), 25.0)
		best = minf(best, (d - HIT.y) * maxf(_speed, 60.0) / rel)
	for p: Dictionary in _props:
		var kind := str(p["kind"])
		if bool(p["done"]) or int(p["lane"]) != lane or not (kind == "barricade" or kind == "oil"):
			continue
		var d := _y - float(p["y"])
		if d < -20.0:
			continue
		if d < 22.0:
			return 0.0
		best = minf(best, d - 22.0)
	return best


func _row_clear(lane: int) -> bool:
	var lx := _lane_x(lane)
	for c: Dictionary in _cars:
		if float(c["ghost"]) > 0.0 or (int(c["lane"]) != lane and absf(float(c["x"]) - lx) > 22.0):
			continue
		var d := _y - float(c["y"])
		if d > -35.0 and d < 45.0:
			return false
	return not _hazard_near(lane, _y, 30.0, true)


func _pickup_value(lane: int) -> float:
	var v := 0.0
	for p: Dictionary in _props:
		var kind := str(p["kind"])
		if bool(p["done"]) or int(p["lane"]) != lane or kind == "barricade" or kind == "oil":
			continue
		var d := _y - float(p["y"])
		if d > 10.0 and d < 220.0:
			v += 40.0
	return minf(v, 80.0)


# ---------------------------------------------------------------- view
func _height() -> float:
	return sin(PI * (1.0 - _air_t / _air_total)) if _air_t > 0.0 else 0.0


func _sync() -> void:
	var h := _height()
	_truck.position = Vector2(_x, _y - h * 8.0)
	_truck.scale = Vector2.ONE * (1.0 + 0.3 * h)
	_truck.rotation = (1.0 - _spin_t / 0.5) * TAU if _spin_t > 0.0 else 0.0
	_truck.visible = _invuln_t <= 0.0 or fmod(_invuln_t, 0.2) < 0.12
	_shadow.position = Vector2(_x + 2.0 + h * 5.0, _y + 3.0)
	_shadow.scale = Vector2.ONE * (1.0 - 0.3 * h)
	for c: Dictionary in _cars:
		var s: Sprite2D = c["node"]
		s.position = Vector2(float(c["x"]), float(c["y"]))
		s.modulate.a = clampf((float(c["y"]) + _length - 20.0) / 160.0, 0.0, 1.0)  # fade out at the destination
		var blink: ColorRect = c["blink"]
		var sig := float(c["signal"])
		blink.visible = sig >= 0.0 and fmod(sig, 0.3) < 0.18
		blink.position = Vector2(-1.5 + 8.0 * int(c["plan"]), -15.0)
	_fx.update(Vector2(_x, _y - h * 8.0), _turbo_t > 0.0, slipping())
	_cam.position = Vector2(0.0, _y - CAM_LEAD)
	_marks.queue_redraw()


## How far ahead of the truck the top edge of the screen is.
func view_ahead() -> float:
	return CAM_LEAD + get_viewport_rect().size.y / 2.0


func slipping() -> bool:
	return _slip_t >= SLIP_DELAY


func progress() -> float:
	return clampf(-_y / _length, 0.0, 1.0)


func fuel() -> float:
	return _fuel


func gauge() -> float:
	return _gauge


func combo() -> int:
	return _combo


func speed_kmh() -> int:
	return roundi(_speed * KMH)


func elapsed() -> float:
	return maxf(_t, 0.0)


# ================================================================ drawing helpers
## Ground, the river / sea band on the left, and the road in chunks (so the parts off
## screen are culled) with the decor of the course theme.
class RoadView:
	extends Node2D
	const CHUNK := 480.0
	var _theme: Dictionary
	var _length := 0.0

	func build(theme: Dictionary, length: float, seed_value: int) -> void:
		_theme = theme
		_length = length
		z_index = -10
		var y := 420.0
		var i := 0
		while y > -length - 560.0:
			var ch := RaceGame.RoadChunk.new()
			ch.theme = theme
			ch.length = length
			ch.y0 = y - CHUNK
			ch.y1 = y
			ch.seed_value = seed_value * 1000 + i
			add_child(ch)
			y -= CHUNK
			i += 1
		queue_redraw()

	func _draw() -> void:
		var top := -_length - 700.0
		var r := Rect2(-900.0, top, 1800.0, 1300.0 - top)
		draw_rect(r, _theme["ground"])
		if _theme.has("band"):
			var col: Color = _theme["band"]
			var sea := _theme.has("sea")
			var width := 260.0 if sea else 110.0
			var right := -(RaceGame.ROAD_HALF + 70.0)
			draw_rect(Rect2(right - width - 20.0, top, width + 40.0, r.size.y), col.lightened(0.55) if sea else Color("6fae4f"))
			draw_rect(Rect2(right - width, top, width, r.size.y), col)
			draw_rect(Rect2(right - width * 0.68, top, width * 0.35, r.size.y), col.lightened(0.18))


class RoadChunk:
	extends Node2D
	const INK := Color("261e2c")
	var theme: Dictionary
	var length := 0.0
	var y0 := 0.0
	var y1 := 0.0
	var seed_value := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		_draw_decor(rng)
		var road_top := -length - 40.0
		var road_bot := 40.0
		var a := maxf(y0, road_top)
		var b := minf(y1, road_bot)
		var half := RaceGame.ROAD_HALF
		if b > a:
			if theme.has("sidewalk"):
				draw_rect(Rect2(-half - 22.0, a, (half + 22.0) * 2.0, b - a), theme["sidewalk"])
			draw_rect(Rect2(-half - 4.0, a, (half + 4.0) * 2.0, b - a), theme["edge"])
			draw_rect(Rect2(-half, a, half * 2.0, b - a), theme["road"])
			for side: float in [-1.0, 1.0]:
				draw_rect(Rect2(side * (half - 3.0) - 1.0, a, 2.0, b - a), Color(1, 1, 1, 0.85))
			for i in range(1, RaceGame.LANES):
				var x := -half + i * RaceGame.LANE_W
				var yy := floorf(a / 40.0) * 40.0
				while yy < b:
					var s := maxf(yy, a)
					var e := minf(yy + 18.0, b)
					if e > s:
						draw_rect(Rect2(x - 1.0, s, 2.0, e - s), Color(1, 1, 1, 0.7))
					yy += 40.0
			if theme.has("fence"):
				var col: Color = theme["fence"]
				for side: float in [-1.0, 1.0]:
					var fx := side * (half + 12.0)
					draw_rect(Rect2(fx - 1.0, a, 2.0, b - a), col)
					var yy := floorf(a / 24.0) * 24.0
					while yy < b:
						if yy >= a:
							draw_rect(Rect2(fx - 2.0, yy - 2.0, 4.0, 4.0), col.darkened(0.3))
						yy += 24.0
		_yard(40.0, 360.0)
		_yard(road_top - 340.0, road_top)

	## Paved yard in front of the start and destination buildings.
	func _yard(top: float, bottom: float) -> void:
		var a := maxf(y0, top)
		var b := minf(y1, bottom)
		if b <= a:
			return
		draw_rect(Rect2(-174.0, a, 348.0, b - a), INK)
		draw_rect(Rect2(-170.0, a, 340.0, b - a), Color("d8d2c4"))
		var yy := floorf(a / 12.0) * 12.0
		while yy < b:
			if yy >= a:
				draw_line(Vector2(-170.0, yy), Vector2(170.0, yy), Color("c8c2b4"), 1.0)
			yy += 12.0

	func _draw_decor(rng: RandomNumberGenerator) -> void:
		var table: Array = theme["decor"]
		var weight := 0
		for e: Array in table:
			weight += int(e[1])
		var colors: Array = theme["colors"]
		var half := RaceGame.ROAD_HALF
		var near := half + (60.0 if theme.has("sidewalk") else 40.0)
		var band_far := half + 70.0 + (300.0 if theme.has("sea") else 150.0)
		var tries := int(theme.get("density", 1))
		var y := y0
		while y < y1:
			for k in tries * 2:
				var side := -1.0 if k % 2 == 0 else 1.0
				var lo := band_far if theme.has("band") and side < 0.0 else near
				var p := Vector2(side * (lo + rng.randf_range(10.0, 280.0)), y + rng.randf_range(-20.0, 20.0))
				var pick := rng.randi() % weight
				var col: Color = colors[rng.randi() % colors.size()]
				if absf(p.x) < 230.0 and (p.y > -60.0 or p.y < -length - 20.0):
					continue  # room for the buildings
				var kind := ""
				for e: Array in table:
					pick -= int(e[1])
					if pick < 0:
						kind = str(e[0])
						break
				RaceGame.Decor.draw(self, kind, p, col, rng)
			y += 56.0


## Scenery seen from above, one thing at p (shared by every course theme).
class Decor:
	const INK := Color("261e2c")

	static func draw(ci: CanvasItem, kind: String, p: Vector2, col: Color, rng: RandomNumberGenerator) -> void:
		match kind:
			"tower":  # downtown building from above: roof, rooftop unit, window strips
				var s := Vector2(rng.randf_range(48, 78), rng.randf_range(44, 70))
				var rect := Rect2(p - s / 2.0, s)
				ci.draw_rect(Rect2(rect.position + Vector2(4, 4), s), Color(0, 0, 0, 0.18))
				ci.draw_rect(rect, col)
				ci.draw_rect(rect.grow(-4), col.lightened(0.12))
				var y := rect.position.y + 8.0
				while y < rect.end.y - 8.0:
					ci.draw_rect(Rect2(rect.position.x + 7, y, s.x - 14, 3), Color("8ec8f0"))
					y += 9.0
				ci.draw_rect(Rect2(p - Vector2(8, 6), Vector2(16, 12)), col.darkened(0.25))
				ci.draw_rect(rect, INK, false, 2.0)
			"apartment":  # long apartment block
				var s := Vector2(34, rng.randf_range(80, 110))
				var rect := Rect2(p - s / 2.0, s)
				ci.draw_rect(Rect2(rect.position + Vector2(4, 4), s), Color(0, 0, 0, 0.18))
				ci.draw_rect(rect, col)
				ci.draw_rect(Rect2(rect.position, Vector2(8, s.y)), Color("c86a5a"))
				var yy := rect.position.y + 5.0
				while yy < rect.end.y - 6.0:
					ci.draw_rect(Rect2(rect.position.x + 13, yy, 5, 5), Color("8ec8f0"))
					ci.draw_rect(Rect2(rect.position.x + 23, yy, 5, 5), Color("8ec8f0"))
					yy += 9.0
				ci.draw_rect(rect, INK, false, 2.0)
			"shop":
				var rect := Rect2(p - Vector2(24, 16), Vector2(48, 32))
				ci.draw_rect(rect, Color("f4ead8"))
				ci.draw_rect(Rect2(rect.position, Vector2(48, 10)), col)
				ci.draw_rect(Rect2(rect.position + Vector2(8, 16), Vector2(14, 12)), Color("8ec8f0"))
				ci.draw_rect(Rect2(rect.position + Vector2(28, 16), Vector2(12, 16)), Color("8a5a36"))
				ci.draw_rect(rect, INK, false, 2.0)
			"stall":  # market stall with a striped awning and produce
				var rect := Rect2(p - Vector2(18, 12), Vector2(36, 24))
				ci.draw_rect(rect, Color("f4ead8"))
				for k in 4:
					ci.draw_rect(Rect2(rect.position.x + k * 9, rect.position.y, 9, 9), col if k % 2 == 0 else Color.WHITE)
				for k in 3:
					ci.draw_circle(rect.position + Vector2(8 + k * 10, 17), 3, [Color("e05050"), Color("f0c040"), Color("5fbf6f")][k])
				ci.draw_rect(rect, INK, false, 2.0)
			"crowd":
				for k in 5:
					var q := p + Vector2(rng.randf_range(-14, 14), rng.randf_range(-10, 10))
					ci.draw_circle(q, 4, [Color("e05050"), Color("4f8fe0"), Color("f0c040"), Color("5fbf6f")][k % 4])
					ci.draw_circle(q + Vector2(0, -3), 2.5, Color("ffe2c8"))
			"house":  # farmhouse from above: colored roof with a ridge, a little yard
				ci.draw_rect(Rect2(p - Vector2(30, 24), Vector2(60, 48)), Color("d8c8a0"))
				var roof := Rect2(p - Vector2(22, 14), Vector2(44, 28))
				ci.draw_rect(roof, col)
				ci.draw_line(Vector2(roof.position.x, p.y), Vector2(roof.end.x, p.y), col.darkened(0.35), 2.0)
				ci.draw_rect(roof, INK, false, 2.0)
			"paddy":  # rice paddy with rows of seedlings (green, or ripe gold)
				var gold := rng.randf() < 0.4
				var s := Vector2(rng.randf_range(70, 100), rng.randf_range(50, 70))
				var rect := Rect2(p - s / 2.0, s)
				ci.draw_rect(rect, Color("e0c860") if gold else Color("6fbf5a"))
				var y := rect.position.y + 5.0
				while y < rect.end.y - 3.0:
					ci.draw_line(Vector2(rect.position.x + 3, y), Vector2(rect.end.x - 3, y), Color("c8a840") if gold else Color("4f9f45"), 2.0)
					y += 7.0
				ci.draw_rect(rect, Color("8a6a40"), false, 3.0)
			"haystack":
				ci.draw_circle(p, 11, Color("e8d080"))
				ci.draw_arc(p, 11, 0, TAU, 14, INK, 2.0)
				ci.draw_arc(p, 6, 0, TAU, 10, Color("c8a850"), 1.0)
			"persimmon":
				_tree(ci, p, Color("5f9f45"), 12)
				for k in 4:
					ci.draw_circle(p + Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7)), 2.2, Color("f08a30"))
			"pine":
				ci.draw_circle(p + Vector2(3, 4), 12, Color(0, 0, 0, 0.15))
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -16), p + Vector2(13, 8), p + Vector2(-13, 8)]), col)
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -22), p + Vector2(9, -2), p + Vector2(-9, -2)]), col.lightened(0.15))
				ci.draw_polyline(PackedVector2Array([p + Vector2(0, -22), p + Vector2(13, 8), p + Vector2(-13, 8), p + Vector2(0, -22)]), INK, 2.0)
			"rock":
				ci.draw_circle(p, 10, Color("9a9aa4"))
				ci.draw_circle(p + Vector2(-3, -3), 4, Color("b8b8c0"))
				ci.draw_arc(p, 10, 0, TAU, 12, INK, 2.0)
			"reeds":
				for k in 5:
					var q := p + Vector2(k * 4 - 8, 0)
					ci.draw_line(q, q + Vector2(rng.randf_range(-3, 3), -14), Color("6f8f3a"), 2.0)
					ci.draw_rect(Rect2(q + Vector2(-1, -16), Vector2(3, 5)), Color("8a6a40"))
			"palm":
				ci.draw_line(p, p + Vector2(4, -6), Color("8a6a40"), 3.0)
				for k in 5:
					ci.draw_line(p + Vector2(4, -6), p + Vector2(4, -6) + Vector2.from_angle(k * TAU / 5.0) * 14.0, Color("3f9f45"), 4.0)
				ci.draw_circle(p + Vector2(4, -6), 3, Color("8a6a40"))
			"parasol":
				ci.draw_circle(p, 13, col)
				for k in 4:
					ci.draw_line(p, p + Vector2.from_angle(k * TAU / 4.0 + 0.4) * 13.0, Color.WHITE, 2.0)
				ci.draw_arc(p, 13, 0, TAU, 16, INK, 2.0)
				ci.draw_rect(Rect2(p + Vector2(10, 4), Vector2(14, 7)), Color("f4f0e0"))
			"bench":
				ci.draw_rect(Rect2(p - Vector2(4, 12), Vector2(8, 24)), Color("b07a48"))
				ci.draw_rect(Rect2(p - Vector2(4, 12), Vector2(8, 24)), INK, false, 1.5)
			"flowers":
				ci.draw_circle(p, 10, Color("5fa045"))
				for k in 6:
					ci.draw_circle(p + Vector2.from_angle(k * 1.05) * 6.0, 2.2, [Color("ff8fb0"), Color("fff0a0"), Color.WHITE][k % 3])
			"pond":
				ci.draw_circle(p, 26, Color("8a6a40"))
				ci.draw_circle(p, 23, Color("5aa0e0"))
				ci.draw_circle(p + Vector2(-6, -6), 6, Color("8ec8f0"))
			"lamp":  # street light by the sidewalk
				ci.draw_circle(p, 9, Color(1.0, 0.95, 0.6, 0.35))
				ci.draw_circle(p, 3, INK)
			"street_tree":
				_tree(ci, p, Color("4f9f45"), 10)
			"playground":
				ci.draw_rect(Rect2(p - Vector2(28, 20), Vector2(56, 40)), Color("e8d0a0"))
				ci.draw_rect(Rect2(p - Vector2(20, 12), Vector2(14, 6)), Color("e05050"))
				ci.draw_circle(p + Vector2(10, 4), 7, Color("4f8fe0"))
				ci.draw_rect(Rect2(p - Vector2(28, 20), Vector2(56, 40)), INK, false, 2.0)
			_:  # tree
				_tree(ci, p, col, 13)

	static func _tree(ci: CanvasItem, p: Vector2, col: Color, r: float) -> void:
		ci.draw_circle(p + Vector2(3, 4), r, Color(0, 0, 0, 0.15))
		ci.draw_circle(p, r, col)
		ci.draw_arc(p, r, 0, TAU, 14, INK, 2.0)
		ci.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, col.lightened(0.25))


## Something on the road: a barricade, an oil puddle or a pickup.
class Prop:
	extends Node2D
	const TEX := {"barricade": "barricade.png", "star": "pickup_star.png", "drink": "pickup_drink.png",
			"toolbox": "pickup_repair.png"}
	const INK := Color("261e2c")
	var kind := ""

	func _ready() -> void:
		if TEX.has(kind):
			var s := Sprite2D.new()
			s.texture = load(RaceGame.SPRITES + str(TEX[kind])) as Texture2D
			if kind == "barricade":
				s.scale = Vector2(0.8, 1.0)  # 38 px sprite in a 30 px lane
			add_child(s)

	func _draw() -> void:
		match kind:
			"oil":
				draw_circle(Vector2(-4, 1), 9, Color(0.08, 0.07, 0.12, 0.85))
				draw_circle(Vector2(5, -2), 7, Color(0.08, 0.07, 0.12, 0.85))
				draw_circle(Vector2(1, 5), 6, Color(0.08, 0.07, 0.12, 0.85))
				draw_arc(Vector2(-4, -1), 4, PI, PI * 1.6, 6, Color(0.6, 0.5, 0.9, 0.7), 1.5)
				draw_arc(Vector2(5, -3), 3, PI, PI * 1.6, 6, Color(0.5, 0.8, 0.9, 0.7), 1.5)
			"fuel":  # red jerry can
				draw_rect(Rect2(-6, -7, 12, 15), Color("e04a3a"))
				draw_rect(Rect2(-6, -7, 12, 15), INK, false, 1.5)
				draw_rect(Rect2(1, -10, 4, 3), Color("3a3a44"))
				draw_line(Vector2(-4, -5), Vector2(4, 6), Color("f8d8c8"), 1.5)
				draw_line(Vector2(4, -5), Vector2(-4, 6), Color("f8d8c8"), 1.5)


## A checkpoint banner across the road (or the checkered finish line).
class Gate:
	extends Node2D
	const INK := Color("261e2c")
	var text := ""
	var finish := false

	func _ready() -> void:
		var l := UiTheme.make_label(text, UiTheme.SIZE, Color("fbf3dc"), true)
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", 4)
		add_child(l)
		l.reset_size()
		l.position = Vector2(-l.size.x / 2.0, -l.size.y / 2.0 - (14.0 if finish else 0.0)).round()

	func _draw() -> void:
		var w := RaceGame.ROAD_HALF + 10.0
		if finish:
			var size := 6.0
			var x := -RaceGame.ROAD_HALF
			var i := 0
			while x < RaceGame.ROAD_HALF:
				draw_rect(Rect2(x, -6.0, size, size), Color.WHITE if i % 2 == 0 else INK)
				draw_rect(Rect2(x, 0.0, size, size), INK if i % 2 == 0 else Color.WHITE)
				x += size
				i += 1
			return
		draw_rect(Rect2(-w, -7.0, w * 2.0, 14.0), INK)
		draw_rect(Rect2(-w + 1.0, -6.0, w * 2.0 - 2.0, 12.0), Color("23489a"))
		var x2 := -w + 4.0
		while x2 < w - 8.0:
			draw_rect(Rect2(x2, -6.0, 4.0, 2.0), Color("f2c14e"))
			draw_rect(Rect2(x2 + 4.0, 4.0, 4.0, 2.0), Color("f2c14e"))
			x2 += 8.0
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(side * w, 0.0), 5.0, INK)
			draw_circle(Vector2(side * w, 0.0), 3.5, Color("e8e8f0"))


class Shadow:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(-8, -13, 16, 28), Color(0, 0, 0, 0.28))


## Turbo flame and slipstream wind lines around the player.
class Effects:
	extends Node2D
	var _turbo := false
	var _slip := false
	var _t := 0.0

	func update(pos: Vector2, turbo: bool, slip: bool) -> void:
		position = pos
		_turbo = turbo
		_slip = slip
		_t += get_process_delta_time()
		queue_redraw()

	func _draw() -> void:
		if _turbo:
			var l := 14.0 + sin(_t * 40.0) * 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(-5, 14), Vector2(5, 14), Vector2(0, 14 + l)]), Color("ff9a3c"))
			draw_colored_polygon(PackedVector2Array([Vector2(-2, 14), Vector2(2, 14), Vector2(0, 14 + l * 0.6)]), Color("fff0a0"))
			draw_arc(Vector2.ZERO, 20.0, 0, TAU, 20, Color(1.0, 0.85, 0.3, 0.5 + 0.3 * sin(_t * 20.0)), 2.0)
		if _turbo or _slip:
			for k in 4:
				var x := (-13.0 if k % 2 == 0 else 13.0) + (-3.0 if k % 2 == 0 else 3.0) * (1.0 if k >= 2 else 0.0)
				var y := fmod(_t * 260.0 + k * 23.0, 50.0) - 20.0
				draw_line(Vector2(x, y), Vector2(x, y + 10.0), Color(1, 1, 1, 0.75), 1.0)


## Blinking "!" at the top edge of the screen over hazards that are about to scroll in.
class WarnMarks:
	extends Node2D
	var game: RaceGame
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta

	func _draw() -> void:
		if game == null or fmod(_t, 0.4) > 0.26:
			return
		var ahead := game.view_ahead()
		var top := game._y - ahead + 14.0
		for p: Dictionary in game._props:
			var kind := str(p["kind"])
			if bool(p["done"]) or not (kind == "barricade" or kind == "oil"):
				continue
			var d := game._y - float(p["y"])
			if d < ahead - 6.0 or d > RaceGame.WARN_AHEAD:
				continue
			var c := Vector2(game._lane_x(int(p["lane"])), top)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 6), c + Vector2(-8, 6)]), UiTheme.COLOR_WARN)
			draw_polyline(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 6), c + Vector2(-8, 6), c + Vector2(0, -8)]), Color("261e2c"), 1.5)
			draw_rect(Rect2(c + Vector2(-1, -4), Vector2(2, 5)), Color("261e2c"))
			draw_rect(Rect2(c + Vector2(-1, 2), Vector2(2, 2)), Color("261e2c"))


## HUD: destination, fuel, cargo, speed, trip bar (left); score, combo, turbo (right).
class RaceHud:
	extends CanvasLayer
	var game: RaceGame
	var _fuel: ProgressBar
	var _fuel_fill: StyleBoxFlat
	var _cargo: Label
	var _speed: Label
	var _trip: TripBar
	var _score: Label
	var _combo: Label
	var _gauge: ProgressBar
	var _turbo: Label
	var _center: Label
	var _hint: Label
	var _t := 0.0

	func build(track_name: String) -> void:
		layer = 10
		var root := Control.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTheme.apply(root)
		add_child(root)
		var m := UiTheme.edge_margin()
		var panel := PanelContainer.new()
		panel.position = Vector2(m, 6)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8))
		root.add_child(panel)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 1)
		panel.add_child(vb)
		vb.add_child(UiTheme.make_label(RaceGame.tx("heading") % Korean.ro(Story.destination_name()), UiTheme.SIZE, UiTheme.COLOR_BORDER, true))
		vb.add_child(UiTheme.make_label(RaceGame.tx("course") % track_name, UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))
		var tags := PackedStringArray()
		if Story.is_urgent():
			tags.append(RaceGame.tx("urgent"))
		if bool(Story.current_task().get("fragile", false)):
			tags.append(RaceGame.tx("fragile"))
		if not tags.is_empty():
			vb.add_child(UiTheme.make_label("[" + " · ".join(tags) + "]", UiTheme.SIZE_SMALL, UiTheme.COLOR_BAD))
		_trip = TripBar.new()
		_trip.game = game
		_trip.custom_minimum_size = Vector2(130, 14)
		vb.add_child(_trip)
		vb.add_child(UiTheme.make_label(RaceGame.tx("fuel"), UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))
		_fuel = ProgressBar.new()
		_fuel.custom_minimum_size = Vector2(130, 8)
		_fuel.show_percentage = false
		_fuel_fill = (UiTheme.theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat).duplicate() as StyleBoxFlat
		_fuel.add_theme_stylebox_override("fill", _fuel_fill)
		vb.add_child(_fuel)
		_cargo = UiTheme.make_label("", UiTheme.SIZE_SMALL)
		vb.add_child(_cargo)
		_speed = UiTheme.make_label("", UiTheme.SIZE, UiTheme.COLOR_TEXT, true)
		vb.add_child(_speed)

		var rp := PanelContainer.new()
		rp.anchor_left = 1.0
		rp.anchor_right = 1.0
		rp.offset_left = -m - 120
		rp.offset_right = -m
		rp.offset_top = 6
		rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rp.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8))
		root.add_child(rp)
		var rvb := VBoxContainer.new()
		rvb.add_theme_constant_override("separation", 1)
		rp.add_child(rvb)
		_score = UiTheme.make_label("", UiTheme.SIZE_LARGE, UiTheme.COLOR_TEXT, true)
		_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rvb.add_child(_score)
		_combo = UiTheme.make_label("", UiTheme.SIZE, UiTheme.COLOR_WARN, true)
		_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rvb.add_child(_combo)
		rvb.add_child(UiTheme.make_label(RaceGame.tx("turbo_gauge"), UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))
		_gauge = ProgressBar.new()
		_gauge.custom_minimum_size = Vector2(108, 8)
		_gauge.show_percentage = false
		var fill := (UiTheme.theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat).duplicate() as StyleBoxFlat
		fill.bg_color = Color("ff9a3c")
		_gauge.add_theme_stylebox_override("fill", fill)
		rvb.add_child(_gauge)
		_turbo = UiTheme.make_label("", UiTheme.SIZE_SMALL, UiTheme.COLOR_WARN, true)
		rvb.add_child(_turbo)

		var hint_text := RaceGame.tx("hint")
		if GameState.is_touch_device():
			hint_text = RaceGame.tx("hint_touch")
			_touch_buttons(root, m)
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
		_hint = hint

		_center = UiTheme.make_label("", UiTheme.SIZE_LARGE, UiTheme.COLOR_TEXT, true)
		_center.set_anchors_preset(Control.PRESET_CENTER)
		_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_center.grow_vertical = Control.GROW_DIRECTION_BOTH
		_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_center.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_center.add_theme_constant_override("outline_size", 6)
		root.add_child(_center)

	func _touch_buttons(root: Control, m: float) -> void:
		var view := root.get_viewport().get_visible_rect().size
		var specs := [
			["move_left", "btn_left", Vector2(m + 4, view.y - 64)], ["move_right", "btn_right", Vector2(m + 66, view.y - 64)],
			["move_down", "btn_brake", Vector2(view.x - m - 194, view.y - 64)],
			["interact", "btn_jump", Vector2(view.x - m - 128, view.y - 64)], ["quick_item", "btn_turbo", Vector2(view.x - m - 62, view.y - 64)],
		]
		var tex := load("res://assets/sprites/placeholder/touch_a.png") as Texture2D
		for sp: Array in specs:
			var b := TouchScreenButton.new()
			b.texture_normal = tex
			b.action = str(sp[0])
			b.scale = Vector2(1.3, 1.3)
			b.position = sp[2]
			add_child(b)
			var l := UiTheme.make_label(RaceGame.tx(str(sp[1])), UiTheme.SIZE_SMALL, UiTheme.COLOR_TEXT, true)
			l.position = Vector2(-6, 20)  # 12 px text is wider than the button
			l.size = Vector2(56, 12)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			l.add_theme_constant_override("outline_size", 4)
			b.add_child(l)

	func refresh() -> void:
		_t += get_process_delta_time()
		var f := game.fuel()
		_fuel.value = f
		var low := f <= RaceGame.FUEL_LOW
		_fuel_fill.bg_color = UiTheme.COLOR_BAD if low else UiTheme.COLOR_GOOD
		_fuel.modulate.a = 0.4 if low and fmod(_t, 0.5) < 0.2 else 1.0
		_cargo.text = RaceGame.tx("cargo") % game.cargo
		_speed.text = RaceGame.tx("speed") % game.speed_kmh()
		_trip.queue_redraw()
		if game.elapsed() > 8.0:  # the hint covers the road behind the truck: fade it after a while
			_hint.modulate.a = move_toward(_hint.modulate.a, 0.0, get_process_delta_time())
		_score.text = Korean.comma(game.score)
		_combo.text = RaceGame.tx("combo") % game.combo() if game.combo() > 1 else ""
		_gauge.value = game.gauge()
		if game.gauge() >= 100.0:
			_turbo.text = RaceGame.tx("turbo_ready_touch" if GameState.is_touch_device() else "turbo_ready")
			_turbo.modulate.a = 1.0 if fmod(_t, 0.6) < 0.4 else 0.5
		else:
			var bag := GameState.item_count("energybar")
			_turbo.text = RaceGame.tx("bag") % bag if bag > 0 else ""
			_turbo.modulate.a = 1.0

	func set_center(text: String) -> void:
		_center.text = text

	func flash(text: String, color: Color) -> void:
		Dialogue.toast(text, color)


## The trip as a line: checkpoints (lit once passed), the destination flag, the truck.
class TripBar:
	extends Control
	var game: RaceGame

	func _draw() -> void:
		var y := size.y / 2.0
		var x0 := 4.0
		var x1 := size.x - 10.0
		draw_line(Vector2(x0, y), Vector2(x1, y), Color("a0a4b4"), 3.0)
		var prog := game.progress()
		draw_line(Vector2(x0, y), Vector2(lerpf(x0, x1, prog), y), UiTheme.COLOR_GOOD, 3.0)
		for k in range(1, RaceGame.CHECKPOINTS + 1):
			var f := float(k) / (RaceGame.CHECKPOINTS + 1)
			var px := lerpf(x0, x1, f)
			draw_rect(Rect2(px - 2.0, y - 4.0, 4.0, 8.0), UiTheme.COLOR_GOOD if prog >= f else Color("d0d0d8"))
		draw_line(Vector2(x1, y - 6.0), Vector2(x1, y + 5.0), Color.WHITE, 1.0)
		draw_rect(Rect2(x1, y - 6.0, 7.0, 5.0), UiTheme.COLOR_BAD)
		var p := Vector2(lerpf(x0, x1, prog), y)
		draw_circle(p, 4.0, Color("ffe08a"))
		draw_arc(p, 4.0, 0, TAU, 10, Color.BLACK, 1.0)


# ================================================================ tutorial pictures
## TutorialPages painter for Story.TUTORIALS["drive"]: draws `pic` into ci (PIC_SIZE),
## animated by t; labels are the captions from Story.
static func paint_tutorial(ci: Control, pic: String, labels: Array, t: float) -> void:
	var sz := ci.size
	var lab := func(i: int) -> String: return str(labels[i]) if i < labels.size() else ""
	match pic:
		"goal":
			ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("7cc35a"))
			var from := TutorialPages.tex(SPRITES + "bld_pps.png")
			var to: Texture2D = null
			if Story.destination_id() != "":
				to = TutorialPages.tex(SPRITES + "bld_%s.png" % Story.destination_id())
			if to == null:
				to = TutorialPages.tex(SPRITES + "bld_school.png")
			ci.draw_rect(Rect2(0, sz.y / 2.0 + 8.0, sz.x, 28.0), Color("4f5160"))
			var x := 80.0
			while x < sz.x - 80.0:
				ci.draw_rect(Rect2(x, sz.y / 2.0 + 21.0, 10, 2), Color(1, 1, 1, 0.7))
				x += 20.0
			for k in 2:
				var tex: Texture2D = from if k == 0 else to
				var cx := 44.0 if k == 0 else sz.x - 44.0
				if tex != null:
					var h := 60.0
					var w := tex.get_width() * h / tex.get_height()
					ci.draw_texture_rect(tex, Rect2(cx - w / 2.0, 6.0, w, h), false)
				TutorialPages.text(ci, Vector2(cx, sz.y - 6.0), lab.call(k), UiTheme.COLOR_TEXT)
			var p := fmod(t * 0.35, 1.0)
			_tut_car(ci, "car_player.png", Vector2(lerpf(90.0, sz.x - 90.0, p), sz.y / 2.0 + 22.0), PI / 2.0)
		"lanes":
			var road := _tut_road(ci, sz, 0.0)
			var lw := road.size.x / LANES
			var lane := 2 if fmod(t, 2.4) < 1.2 else 1
			_tut_car(ci, "car_rival.png", Vector2(road.position.x + 2.5 * lw, 26.0), 0.0, Color("ef6b5b"))
			_tut_car(ci, "car_player.png", Vector2(road.position.x + (lane + 0.5) * lw, sz.y - 26.0), 0.0)
			var on := fmod(t, 0.6) < 0.4
			for side: float in [-1.0, 1.0]:
				var ax := sz.x / 2.0 + side * (road.size.x / 2.0 + 34.0)
				var col := UiTheme.COLOR_WARN if on else Color(1, 1, 1, 0.4)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(ax + side * 14.0, sz.y / 2.0),
						Vector2(ax - side * 4.0, sz.y / 2.0 - 12.0), Vector2(ax - side * 4.0, sz.y / 2.0 + 12.0)]), col)
		"combo":
			var road := _tut_road(ci, sz, t * 120.0)
			var lw := road.size.x / LANES
			var cycle := fmod(t, 2.0) / 2.0
			for k in 3:
				var y := fmod(cycle * 150.0 + k * 50.0, 150.0) - 20.0
				_tut_car(ci, "car_rival.png", Vector2(road.position.x + ((k * 2) % LANES + 0.5) * lw, y), 0.0,
						TRAFFIC_COLORS[k % TRAFFIC_COLORS.size()])
			_tut_car(ci, "car_player.png", Vector2(road.position.x + 3.5 * lw, sz.y - 30.0), 0.0)
			TutorialPages.text(ci, Vector2(road.position.x + 3.5 * lw, sz.y - 50.0 - cycle * 10.0), lab.call(0), UiTheme.COLOR_WARN)
			TutorialPages.text(ci, Vector2(52.0, sz.y / 2.0 + 4.0), lab.call(1), UiTheme.COLOR_WARN)
			TutorialPages.text(ci, Vector2(sz.x - 52.0, sz.y / 2.0 - 10.0), lab.call(2), UiTheme.COLOR_ACCENT)
			for k in 3:
				var wy := fmod(t * 90.0 + k * 14.0, 40.0) + sz.y / 2.0
				ci.draw_line(Vector2(sz.x - 62.0 + k * 10.0, wy), Vector2(sz.x - 62.0 + k * 10.0, wy + 8.0), Color(1, 1, 1, 0.7), 1.0)
		"jump":
			var area := Vector2(sz.x * 0.55, sz.y)
			var road := _tut_road(ci, area, 0.0)
			ci.draw_rect(Rect2(area.x, 0.0, sz.x - area.x, sz.y), Color(0.13, 0.14, 0.21))
			var lw := road.size.x / LANES
			var bar := TutorialPages.tex(SPRITES + "barricade.png")
			var bx := road.position.x + 2.5 * lw
			ci.draw_texture_rect(bar, Rect2(bx - 12.0, 46.0, 24.0, 10.0), false)
			var ph := fmod(t, 1.6) / 1.6
			var y := lerpf(sz.y - 20.0, 4.0, ph)
			var h := sin(clampf((ph - 0.25) / 0.5, 0.0, 1.0) * PI)
			ci.draw_rect(Rect2(bx - 8.0 + h * 5.0, y - 12.0, 16.0, 28.0), Color(0, 0, 0, 0.3))
			_tut_car(ci, "car_player.png", Vector2(bx, y - h * 10.0), 0.0, Color.WHITE, 1.0 + 0.35 * h)
			if h > 0.3:
				TutorialPages.text(ci, Vector2(bx + 36.0, y - 6.0), lab.call(0), UiTheme.COLOR_WARN)
			var gx := sz.x * 0.62
			TutorialPages.text(ci, Vector2(gx + 50.0, 22.0), lab.call(1), UiTheme.COLOR_DIM)
			var fill := clampf(fmod(t, 3.0) / 2.0, 0.0, 1.0)
			ci.draw_rect(Rect2(gx, 30.0, 100.0, 8.0), Color(0, 0, 0, 0.5))
			ci.draw_rect(Rect2(gx, 30.0, 100.0 * fill, 8.0), Color("ff9a3c"))
			if fill >= 1.0:
				var c := Vector2(gx + 50.0, 80.0)
				var l := 12.0 + sin(t * 40.0) * 4.0
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 14), c + Vector2(5, 14), c + Vector2(0, 14 + l)]), Color("ff9a3c"))
				ci.draw_arc(c, 20.0, 0, TAU, 20, Color(1.0, 0.85, 0.3, 0.7), 2.0)
				_tut_car(ci, "car_player.png", c, 0.0)
				TutorialPages.text(ci, Vector2(gx + 50.0, 56.0), lab.call(2), UiTheme.COLOR_WARN)
		"fuel":
			var f := 1.0 - fmod(t, 3.0) / 3.0 * 0.8
			TutorialPages.text(ci, Vector2(60.0, 30.0), lab.call(0), UiTheme.COLOR_TEXT)
			ci.draw_rect(Rect2(14.0, 40.0, 92.0, 10.0), Color(0, 0, 0, 0.5))
			ci.draw_rect(Rect2(14.0, 40.0, 92.0 * f, 10.0), UiTheme.COLOR_BAD if f < 0.3 else UiTheme.COLOR_GOOD)
			_tut_car(ci, "car_player.png", Vector2(60.0, 80.0), 0.0)
			var gx := 196.0
			ci.draw_rect(Rect2(gx - 66.0, 40.0, 132.0, 14.0), Color("261e2c"))
			ci.draw_rect(Rect2(gx - 65.0, 41.0, 130.0, 12.0), Color("23489a"))
			var x := gx - 62.0
			while x < gx + 58.0:
				ci.draw_rect(Rect2(x, 41.0, 4.0, 2.0), Color("f2c14e"))
				ci.draw_rect(Rect2(x + 4.0, 51.0, 4.0, 2.0), Color("f2c14e"))
				x += 8.0
			TutorialPages.text(ci, Vector2(gx, 30.0), lab.call(1), UiTheme.COLOR_GOOD)
			_tut_fuel_can(ci, Vector2(gx - 20.0, 84.0), 1.6)
			TutorialPages.text(ci, Vector2(gx + 40.0, 90.0), lab.call(2), UiTheme.COLOR_GOOD)
		"items":
			var icons := ["star", "fuel", "drink", "toolbox", "barricade", "oil", "warn"]
			var tex := {"star": "pickup_star.png", "drink": "pickup_drink.png", "toolbox": "pickup_repair.png", "barricade": "barricade.png"}
			var step := sz.x / icons.size()
			for i in icons.size():
				var c := Vector2(step * (i + 0.5), sz.y / 2.0 - 8.0 + (sin(t * 4.0 + i) * 2.0 if i < 4 else 0.0))
				var kind: String = icons[i]
				if tex.has(kind):
					var tx2 := TutorialPages.tex(SPRITES + str(tex[kind]))
					var s := tx2.get_size() * (1.0 if kind == "barricade" else 2.0)
					ci.draw_texture_rect(tx2, Rect2(c - s / 2.0, s), false)
				elif kind == "fuel":
					_tut_fuel_can(ci, c, 1.6)
				elif kind == "oil":
					ci.draw_circle(c + Vector2(-5, 1), 11, Color(0.05, 0.05, 0.08))
					ci.draw_circle(c + Vector2(6, -2), 9, Color(0.05, 0.05, 0.08))
					ci.draw_arc(c + Vector2(-5, -1), 5, PI, PI * 1.6, 6, Color(0.6, 0.5, 0.9, 0.8), 1.5)
				elif fmod(t, 0.5) < 0.33:
					ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, 9), c + Vector2(-12, 9)]), UiTheme.COLOR_WARN)
					ci.draw_rect(Rect2(c + Vector2(-1.5, -5), Vector2(3, 8)), Color("261e2c"))
					ci.draw_rect(Rect2(c + Vector2(-1.5, 5), Vector2(3, 3)), Color("261e2c"))
				TutorialPages.text(ci, Vector2(c.x, sz.y - 14.0), lab.call(i), UiTheme.COLOR_TEXT)
		"keys":
			var touch := GameState.is_touch_device()
			var keys := ["◀", "▶", "점프", "터보", "감속"] if touch else ["←", "→", "↑", "Q", "↓"]
			var step := sz.x / keys.size()
			var lit_i := int(fmod(t, keys.size() * 0.5) / 0.5)
			for i in keys.size():
				var c := Vector2(step * (i + 0.5), sz.y / 2.0 - 10.0)
				var col := Color("f2c14e") if i == lit_i else Color("e8d9a8")
				if touch:
					ci.draw_circle(c, 18.0, col)
					ci.draw_arc(c, 18.0, 0, TAU, 20, Color("261e2c"), 1.5)
				else:
					var r := Rect2(c - Vector2(20, 16), Vector2(40, 32))
					ci.draw_rect(r, col)
					ci.draw_rect(r, Color("261e2c"), false, 1.5)
				TutorialPages.text(ci, Vector2(c.x, c.y + 5.0), str(keys[i]), Color("261e2c"), UiTheme.SIZE, false)
				TutorialPages.text(ci, Vector2(c.x, sz.y - 16.0), lab.call(i), UiTheme.COLOR_TEXT)


## A 5-lane road down the middle of an area (dashes scroll by `scroll`); returns its rect.
static func _tut_road(ci: Control, sz: Vector2, scroll: float) -> Rect2:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("7cc35a"))
	var w := 110.0
	var road := Rect2(sz.x / 2.0 - w / 2.0, 0.0, w, sz.y)
	ci.draw_rect(road.grow_individual(3, 0, 3, 0), Color("f0f0f0"))
	ci.draw_rect(road, Color("4f5160"))
	for i in range(1, LANES):
		var x := road.position.x + i * w / LANES
		var y := fmod(scroll, 30.0) - 30.0
		while y < sz.y:
			var a := maxf(y, 0.0)
			var b := minf(y + 14.0, sz.y)
			if b > a:
				ci.draw_rect(Rect2(x - 1.0, a, 2.0, b - a), Color(1, 1, 1, 0.7))
			y += 30.0
	return road


static func _tut_car(ci: Control, file: String, at: Vector2, angle: float, tint := Color.WHITE, scale := 1.0) -> void:
	var tex := TutorialPages.tex(SPRITES + file)
	if tex == null:
		return
	ci.draw_set_transform(at, angle, Vector2(scale, scale))
	ci.draw_texture(tex, -tex.get_size() / 2.0, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _tut_fuel_can(ci: Control, c: Vector2, k: float) -> void:
	var r := Rect2(c + Vector2(-6, -7) * k, Vector2(12, 15) * k)
	ci.draw_rect(r, Color("e04a3a"))
	ci.draw_rect(r, Color("261e2c"), false, 1.5)
	ci.draw_rect(Rect2(c + Vector2(1, -10) * k, Vector2(4, 3) * k), Color("3a3a44"))
	ci.draw_line(c + Vector2(-4, -5) * k, c + Vector2(4, 6) * k, Color("f8d8c8"), 2.0)
	ci.draw_line(c + Vector2(4, -5) * k, c + Vector2(-4, 6) * k, Color("f8d8c8"), 2.0)
