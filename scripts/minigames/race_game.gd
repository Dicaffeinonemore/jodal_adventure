class_name RaceGame
extends Node2D
## 납품 운전 (time trial): drive from the 조달청 to the destination building on one of
## TrackData's courses before the time runs out. Cars on the road (slower ones in your
## lane, oncoming ones in the other lane) and road-works barricades are the obstacles;
## hitting them lowers the cargo condition, which becomes the delivery quality.
## Arriving early pays bonus stars; arriving late is marked on the task (Story takes a
## little reputation at the report).
##
## Controls (actions only): move_left / move_right steer, acceleration is automatic,
## move_down (↓) brakes down to BRAKE_SPEED (tight corners, traffic ahead),
## "run" (Shift) drifts (sharper turn, fills the drift gauge: full gauge = +1 booster),
## "quick_item" (Q) drinks an energy drink = booster (a drift charge first, else one
## from the bag). Touch devices get on-screen buttons for the same actions.
## Bad condition makes the wheel jerk now and then (drowsy); a drink stops it a while.
## Fairness rules (11/18, after playtest: oncoming cars appeared right in front while
## overtaking, and cars next to barricades closed both lanes):
##   - fewer, slower oncoming cars, respawned further ahead, with a blinking "!" while
##     they are near; one that meets the player in its lane brakes and pulls onto the
##     shoulder (yield),
##   - oncoming cars wait before a barricade until the player has passed it, cars ahead
##     of the player speed up through a barricade zone and steer around barricades in
##     their own lane, so a barricade never has a car beside it when the player arrives,
##   - barricades are at least BARRICADE_GAP apart and cars never spawn on top of one.
## Story.cargo_damage_mult() scales damage (fragile cargo, truck upgrade).
## 11/18: before the countdown, a guide popup (Story.drive_guide(): the first drive, and
## every school run) says to use only the left/right keys. Easy destinations
## (TrackData.easy_for, the school) get fewer cars and barricades and more time.

## Tests: drive by itself (keeps right, avoids obstacles, boosts) / pick the course.
static var autopilot := false
static var force_track := -1

const ROAD_HALF := 46.0
const LANE := 22.0  # lane centers at +-LANE (traffic keeps right: forward at -LANE)
const MAX_SPEED := 240.0
const BOOST_SPEED := 350.0
const OFFROAD_SPEED := 115.0
const ACCEL := 230.0
const BRAKE := 420.0
const BRAKE_SPEED := 70.0  # holding move_down slows the truck to this
const TURN := 2.5  # rad/s at full grip
const DRIFT_TURN := 3.5
const GRIP := 9.0
const DRIFT_GRIP := 2.0
const BOOST_TIME := 1.4
const DRIFT_FILL := 45.0  # gauge per second of drifting (100 = one booster)
const START_CHARGES := 1
const MAX_CHARGES := 3
const LATE_GRACE := 30.0  # after the time limit, a tow truck brings you in this much later
const OFFROAD_DAMAGE := 2.0  # cargo per second on rough ground
const FENCE := 150.0  # past the curb, an invisible fence stops the truck
const COUNTDOWN := 3.0
const CAR_R := 9.0
const TRAFFIC := 7
const BARRICADES := 6
const ONCOMING_SHARE := 0.3
const ONCOMING_SPEED := Vector2(80.0, 115.0)
const FORWARD_SPEED := Vector2(100.0, 140.0)
const ONCOMING_RESPAWN := Vector2(1200.0, 1600.0)  # ahead of the player, along the road
const FORWARD_RESPAWN := Vector2(700.0, 1100.0)
const CAR_GAP := 260.0  # min distance between two cars in the same lane when placing
const YIELD_DIST := 300.0  # oncoming car brakes and moves to the shoulder this far ahead of a player in its lane
const SHOULDER := 44.0  # lateral of a yielding car (road half width 46)
const WARN_DIST := 560.0  # "!" over oncoming cars this close ahead
const BARRICADE_CLEAR := 220.0  # no traffic this close to a barricade while the player approaches it
const BARRICADE_WATCH := 700.0  # ... "approaches" = the barricade is this close ahead of the player
const BARRICADE_GAP := 550.0
const SIDE_STEP := 70.0  # lateral px/s when a car changes its line
const STARS := 8
const DRINKS := 2
const DAMAGE := {"car": 8, "barricade": 6, "fence": 4}
const EARLY_BONUS_EVERY := 6.0  # one bonus star per this many seconds left (max 4)
const TRAFFIC_COLORS := [Color("ef6b5b"), Color("7ed37e"), Color("b38cff"), Color("f2c14e"), Color("6fb6ff"), Color("f0f0f0")]
const DROWSY_MIN := 4.0
const DROWSY_MAX := 6.5
const SPRITES := "res://assets/sprites/placeholder/"
const BUILDING_SCALE := 2.0

enum State { COUNTDOWN, DRIVING, FINISHED, GUIDE }

var cargo := 100
var stars := 0
var track_index := 0
var time_limit := 40.0
var finished_late := false
var stats := {"offroad_s": 0.0}  # damage count by cause + seconds off the road (tests print it)

var _state := State.COUNTDOWN
var _t := -COUNTDOWN
var _curve: Curve2D
var _length := 0.0
var _theme: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _damage_mult := 1.0
var _cargo_f := 100.0
var _late_warned := false
var _easy: Dictionary = {}  # TrackData.easy_for (tests that force a course drive the normal trip)

# player
var _pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _heading := 0.0  # 0 = facing up
var _speed := 0.0
var _offset := 0.0
var _boost_t := 0.0
var _charges := START_CHARGES
var _gauge := 0.0
var _drifting := false
var _hit_cd := 0.0
var _wrong_way_t := 0.0
var _drowsy_timer := 5.0
var _drowsy_t := 0.0
var _drowsy_dir := 0.0
var _drowsy_block := 0.0
var _auto_drift := false

var _truck: Sprite2D
## {node, warn (Label), offset, lateral (its lane), lat (where it is now), speed (+ forward / - oncoming), cd}
var _traffic: Array[Dictionary] = []
var _warn_cd := 0.0
var _items: Array[Dictionary] = []  # {kind, node, offset, lateral}
var _skids: Skids
var _fx: Effects
var _cam: Camera2D
var _ui: RaceHud


func _ready() -> void:
	GameState.reset_input_locks()
	Sound.play_bgm("drive")
	Sound.play("engine")
	_rng.randomize()
	track_index = force_track if force_track >= 0 else TrackData.for_destination(Story.destination_id(), _rng)
	var info: Dictionary = TrackData.TRACKS[track_index]
	_theme = TrackData.THEMES[str(info["theme"])]
	_curve = TrackData.build_curve(track_index)
	_length = _curve.get_baked_length()
	time_limit = TrackData.time_limit(_length)
	if force_track < 0:
		_easy = TrackData.easy_for(Story.destination_id())
	time_limit += float(_easy.get("extra_time", 0.0))
	_damage_mult = Story.cargo_damage_mult()
	_drowsy_timer = _rng.randf_range(DROWSY_MIN, DROWSY_MAX)

	var view := TrackView.new()
	view.setup(_curve, _theme, track_index)
	add_child(view)
	_add_building("pps", 0.0, -1.0, "조달청")
	_add_building(Story.destination_id(), _length, 1.0, Story.destination_name())
	_skids = Skids.new()
	add_child(_skids)
	_place_items()
	_spawn_traffic()
	_truck = Sprite2D.new()
	_truck.texture = load(SPRITES + "car_player.png") as Texture2D
	_truck.z_index = 5
	add_child(_truck)
	_fx = Effects.new()
	_fx.z_index = 4
	add_child(_fx)
	_offset = 30.0
	_pos = _curve.sample_baked(_offset) + _normal(_offset) * -LANE
	_heading = _tangent(_offset).angle() + PI / 2.0
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 7.0
	add_child(_cam)
	_cam.make_current()
	_cam.position = _pos
	_ui = RaceHud.new()
	_ui.game = self
	add_child(_ui)
	_ui.build(str(info["name"]))
	_sync_sprites()
	_cam.reset_smoothing()
	var guide: Dictionary = {} if autopilot or force_track >= 0 else Story.drive_guide()  # not in tests
	if not guide.is_empty():
		_state = State.GUIDE
		_ui.show_guide(guide, _start_countdown)


func _start_countdown() -> void:
	if _state == State.GUIDE:
		_state = State.COUNTDOWN


## The 조달청 behind the start and the destination past the end of the road, upright,
## on a paved yard, with its name board.
func _add_building(id: String, at: float, dir: float, label: String) -> void:
	var tex := load(SPRITES + "bld_%s.png" % id) as Texture2D
	if tex == null:
		return
	var end := _curve.sample_baked(at)
	var t := _tangent(at) * dir
	var size := tex.get_size() * BUILDING_SCALE
	var center := end + t * (size.length() * 0.5 + 30.0)
	var yard := Yard.new()
	yard.position = end + t * 40.0
	yard.radius = maxf(size.x, size.y) * 0.75
	add_child(yard)
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(BUILDING_SCALE, BUILDING_SCALE)
	s.position = center
	s.z_index = 2
	add_child(s)
	var board := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("8a5a36") if dir > 0.0 else Color("23489a")
	sb.border_color = Color("261e2c")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	board.add_theme_stylebox_override("panel", sb)
	board.add_child(UiTheme.make_label(("도착: " if dir > 0.0 else "출발: ") + label, UiTheme.SIZE, Color("fbf3dc"), true))
	board.z_index = 6
	add_child(board)
	board.reset_size()
	board.position = (center + Vector2(-board.size.x / 2.0, -size.y / 2.0 - 22.0)).round()


# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			var before := _t
			_t += delta
			if ceili(-before) != ceili(-_t):
				Sound.play("select" if _t < 0.0 else "confirm")
			_ui.set_center(str(ceili(-_t)) if _t < 0.0 else "출발!")
			if _t >= 0.0:
				_state = State.DRIVING
				_t = 0.0
		State.DRIVING:
			_t += delta
			if _t > 0.8 and _t < 1.0:
				_ui.set_center("")
			_drive(delta)
			_move_traffic(delta)
			_check_items()
			_check_finish()
		State.FINISHED:
			_move_traffic(delta)
			_speed = move_toward(_speed, 0.0, BRAKE * delta)
			_vel = _vel.move_toward(Vector2.ZERO, BRAKE * delta)
			_pos += _vel * delta
	_sync_sprites()
	_ui.refresh()


func _drive(delta: float) -> void:
	var steer := _steer_input(delta)
	var drift_key := Input.is_action_pressed("run") or (autopilot and _auto_drift)
	_drifting = drift_key and absf(steer) > 0.1 and _speed > 120.0
	var turn := (DRIFT_TURN if _drifting else TURN) * clampf(_speed / 140.0, 0.35, 1.0)
	_heading += steer * turn * delta
	var d := _curve.sample_baked(_offset).distance_to(_pos)
	var offroad := d > ROAD_HALF
	var target := MAX_SPEED
	if offroad:
		target = OFFROAD_SPEED
	if _boost_t > 0.0:
		_boost_t -= delta
		target = BOOST_SPEED * (0.7 if offroad else 1.0)
	if _drifting:
		target *= 0.95
	if Input.is_action_pressed("move_down"):  # the autopilot never presses it; tests do
		target = minf(target, BRAKE_SPEED)
	_speed = move_toward(_speed, target, (ACCEL if _speed < target else BRAKE) * delta)
	var dir := Vector2.UP.rotated(_heading)
	_vel = _vel.lerp(dir * _speed, 1.0 - exp(-(DRIFT_GRIP if _drifting else GRIP) * delta))
	_pos += _vel * delta
	_update_offset()

	if offroad:
		stats["offroad_s"] = float(stats["offroad_s"]) + delta
		if _speed > 40.0:
			_wear(OFFROAD_DAMAGE * delta)
	_hit_cd = maxf(0.0, _hit_cd - delta)
	var center := _curve.sample_baked(_offset)
	var away := _pos - center
	if away.length() > ROAD_HALF + FENCE:  # invisible fence a little past the curb
		_pos = center + away.normalized() * (ROAD_HALF + FENCE)
		_speed *= 0.5
		_vel *= 0.5
		if _hit_cd <= 0.0:
			_damage("fence")
	if _drifting:
		_gauge += DRIFT_FILL * delta * (_speed / MAX_SPEED)
		_skids.add(_pos - dir * 12.0, _pos - dir * 12.0 + dir.orthogonal() * 6.0)
		if _gauge >= 100.0:
			_gauge = 0.0
			if _charges < MAX_CHARGES:
				_charges += 1
				Sound.play("star")
				_ui.flash("드리프트 게이지 완충! 부스터 +1", UiTheme.COLOR_WARN)
	var along := Vector2.UP.rotated(_heading).dot(_tangent(_offset))
	_wrong_way_t = _wrong_way_t + delta if along < -0.3 and _speed > 60.0 else 0.0
	if _wrong_way_t > 1.2:
		_wrong_way_t = -3.0
		_ui.flash("반대 방향이에요! 돌아가요", UiTheme.COLOR_BAD)
	if autopilot and _charges > 0 and _boost_t <= 0.0 and absf(steer) < 0.15 and _t > 2.0:
		_boost()


func _steer_input(delta: float) -> float:
	var s := _autopilot_steer() if autopilot else Input.get_axis("move_left", "move_right")
	_drowsy_block = maxf(0.0, _drowsy_block - delta)
	if GameState.condition() == GameState.Condition.BAD and _drowsy_block <= 0.0 and not autopilot:
		_drowsy_timer -= delta
		if _drowsy_timer <= 0.0:
			_drowsy_timer = _rng.randf_range(DROWSY_MIN, DROWSY_MAX)
			_drowsy_t = 0.4
			_drowsy_dir = -1.0 if _rng.randf() < 0.5 else 1.0
			_ui.flash("졸음! 핸들이 흔들려요", UiTheme.COLOR_WARN)
	if _drowsy_t > 0.0:
		_drowsy_t -= delta
		s = clampf(s + _drowsy_dir, -1.0, 1.0)
	return s


## Like a careful driver: keeps right, moves over for barricades and slow cars ahead
## (when no car is coming the other way), and back.
func _autopilot_steer() -> float:
	var ahead := minf(_offset + 70.0 + _speed * 0.3, _length)
	var lane := -LANE
	var blocked_right := false
	var blocked_left := false
	var oncoming_near := false
	for it: Dictionary in _items:
		var d := float(it["offset"]) - _offset
		if str(it["kind"]) == "barricade" and d > -10.0 and d < 190.0:
			if float(it["lateral"]) < 0.0:
				blocked_right = true
			else:
				blocked_left = true
	for c: Dictionary in _traffic:
		var d := float(c["offset"]) - _offset
		if float(c["speed"]) > 0.0 and d > -10.0 and d < 150.0:
			blocked_right = true
		if float(c["speed"]) < 0.0 and d > -40.0 and d < 260.0:
			oncoming_near = true
	if blocked_right and not oncoming_near and not blocked_left:
		lane = LANE
	var look := _curve.sample_baked(ahead) + _normal(ahead) * lane
	var want := (look - _pos).angle() + PI / 2.0
	var diff := wrapf(want - _heading, -PI, PI)
	_auto_drift = absf(diff) > 0.5
	return clampf(diff * 2.5, -1.0, 1.0)


## Progress along the road: the nearest road point, searched only from a little
## behind to a little ahead of the current progress. A global nearest point would jump
## to another part of the road at hairpins, freeze the progress and pin the truck to
## the fence around the old spot.
func _update_offset() -> void:
	var best := _offset
	var best_d := INF
	var o := maxf(0.0, _offset - 150.0)
	var stop := minf(_length, _offset + 400.0)
	while o <= stop:
		var d := _curve.sample_baked(o).distance_squared_to(_pos)
		if d < best_d:
			best_d = d
			best = o
		o += 8.0
	_offset = best


func _check_finish() -> void:
	if _t >= time_limit and not _late_warned:
		_late_warned = true
		Sound.play("warn")
		_ui.flash("납품 기한 초과! 그래도 끝까지 가요", UiTheme.COLOR_BAD)
	if _offset >= _length - 20.0:
		_finish(_t > time_limit)
	elif _t >= time_limit + LATE_GRACE:  # stuck or idle: a tow truck brings the cargo in
		_wear(10.0)
		_finish(true)


func _finish(late: bool) -> void:
	_state = State.FINISHED
	finished_late = late
	var left := time_limit - _t
	var bonus := 0 if late else clampi(int(left / EARLY_BONUS_EVERY), 0, 4)
	stars += bonus
	GameState.task["late"] = late
	var msg := "납품 기한을 넘겼어요..." if late else "도착! %d초 일찍 왔어요" % int(left)
	if late and _t >= time_limit + LATE_GRACE:
		msg = "견인차의 도움으로 도착했어요..."
	_ui.set_center("%s\n화물 상태 %d%%%s" % [msg, cargo, ("  /  빠른 도착 보너스 별 +%d" % bonus) if bonus > 0 else ""])
	Sound.play("bad" if late else "jingle_good")
	await get_tree().create_timer(2.0).timeout
	Story.on_drive_finished(cargo, stars)


# ---------------------------------------------------------------- traffic
func _spawn_traffic() -> void:
	var count: int = int(_easy.get("traffic", TRAFFIC))
	for i in count:
		var s := Sprite2D.new()
		s.texture = load(SPRITES + ("car_npc.png" if i % 3 == 0 else "car_rival.png")) as Texture2D
		if i % 3 != 0:
			s.modulate = TRAFFIC_COLORS[i % TRAFFIC_COLORS.size()]
		s.z_index = 5
		add_child(s)
		var warn := UiTheme.make_label("!", UiTheme.SIZE, UiTheme.COLOR_BAD, true)
		warn.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.15))
		warn.add_theme_constant_override("outline_size", 4)
		warn.z_index = 6
		warn.hide()
		add_child(warn)
		var c := {"node": s, "warn": warn, "offset": 0.0, "lateral": 0.0, "lat": 0.0, "speed": 0.0, "cd": 0.0}
		_traffic.append(c)
		_place_car(c, 450.0 + (_length - 800.0) * (i + 0.5) / count, _rng.randf() < ONCOMING_SHARE)


## Puts a car on the road near offset o: most drive our way (slower, right lane), some
## come the other way in the left lane. Moves it on until it is clear of other cars in
## its lane and of barricades.
func _place_car(c: Dictionary, o: float, oncoming: bool) -> void:
	var lateral := LANE if oncoming else -LANE
	for k in 8:
		if _spot_clear(c, o, lateral):
			break
		o += 160.0
	c["offset"] = o
	c["lateral"] = lateral
	c["lat"] = lateral
	c["speed"] = -_rng.randf_range(ONCOMING_SPEED.x, ONCOMING_SPEED.y) if oncoming \
			else _rng.randf_range(FORWARD_SPEED.x, FORWARD_SPEED.y)
	c["cd"] = 0.0


func _spot_clear(c: Dictionary, o: float, lateral: float) -> bool:
	for other: Dictionary in _traffic:
		if other != c and float(other["offset"]) >= 0.0 and is_equal_approx(float(other["lateral"]), lateral) \
				and absf(float(other["offset"]) - o) < CAR_GAP:
			return false
	for it: Dictionary in _items:
		if str(it["kind"]) == "barricade" and absf(float(it["offset"]) - o) < BARRICADE_CLEAR + 40.0:
			return false
	return true


## Signed distance of the player from the road center (+ = the oncoming lane).
func _player_lateral() -> float:
	return (_pos - _curve.sample_baked(_offset)).dot(_normal(_offset))


## The next barricade between the player and offset o (oncoming car) that the player is
## about to reach, or {}.
func _barricade_before(o: float) -> Dictionary:
	for it: Dictionary in _items:
		var bo := float(it["offset"])
		if str(it["kind"]) == "barricade" and bo > _offset - 40.0 and bo < o \
				and bo - _offset < BARRICADE_WATCH:
			return it
	return {}


## A barricade in the given lane within [o - behind, o + ahead], or {}.
func _barricade_in_lane(o: float, lateral: float, behind: float, ahead: float) -> Dictionary:
	for it: Dictionary in _items:
		var d := float(it["offset"]) - o
		if str(it["kind"]) == "barricade" and d > -behind and d < ahead \
				and signf(float(it["lateral"])) == signf(lateral):
			return it
	return {}


func _move_traffic(delta: float) -> void:
	if _state == State.COUNTDOWN:
		return
	var plat := _player_lateral()
	_warn_cd = maxf(0.0, _warn_cd - delta)
	for c: Dictionary in _traffic:
		if float(c["offset"]) < -1000.0:
			(c["warn"] as Label).hide()
			continue  # parked out of sight
		var o := float(c["offset"])
		var spd := float(c["speed"])
		var lane := float(c["lateral"])
		var want_lat := lane
		var ahead_of_player := o - _offset
		if spd < 0.0:
			# Head-on with a player overtaking in this lane: brake and pull onto the shoulder.
			if plat > 4.0 and ahead_of_player > -20.0 and ahead_of_player < YIELD_DIST:
				spd *= 0.25
				want_lat = SHOULDER
			# Wait before a barricade until the player has passed it.
			var b := _barricade_before(o)
			var new_o := o + spd * delta
			if not b.is_empty() and o >= float(b["offset"]) + BARRICADE_CLEAR:
				new_o = maxf(new_o, float(b["offset"]) + BARRICADE_CLEAR)
			c["offset"] = new_o
		else:
			# Ahead of the player near a barricade: hurry through so the zone is clear.
			var near := _barricade_in_lane(o, LANE, 260.0, 260.0)
			if near.is_empty():
				near = _barricade_in_lane(o, -LANE, 260.0, 260.0)
			if not near.is_empty() and ahead_of_player > -20.0 and ahead_of_player < BARRICADE_WATCH:
				spd = maxf(spd, 255.0)
			c["offset"] = o + spd * delta
		# Steer around a barricade in its own lane (after the player is past, or ahead of them).
		if not _barricade_in_lane(o, lane, 120.0, 140.0).is_empty():
			want_lat = -lane
		c["lat"] = move_toward(float(c["lat"]), want_lat, SIDE_STEP * delta)
		c["cd"] = maxf(0.0, float(c["cd"]) - delta)
		o = float(c["offset"])
		# cars left behind (or at the road ends) come back further ahead
		if o < _offset - 500.0 or o < 60.0 or o > _length - 120.0:
			var oncoming := _rng.randf() < ONCOMING_SHARE
			var span := ONCOMING_RESPAWN if oncoming else FORWARD_RESPAWN
			var ahead := _offset + _rng.randf_range(span.x, span.y)
			if ahead < _length - 200.0:
				_place_car(c, ahead, oncoming)
			else:
				c["offset"] = -10000.0
				continue
		# Blinking "!" over oncoming cars that are close ahead; a toast if the player is in their lane.
		var warn: Label = c["warn"]
		var d_ahead := float(c["offset"]) - _offset
		var show_warn := float(c["speed"]) < 0.0 and d_ahead > 0.0 and d_ahead < WARN_DIST
		warn.visible = show_warn and fmod(_t, 0.4) < 0.26
		if show_warn:
			warn.position = (_car_pos(c) + Vector2(-3, -26)).round()
			if plat > 4.0 and _warn_cd <= 0.0 and _state == State.DRIVING:
				_warn_cd = 4.0
				Sound.play("warn")
				_ui.flash("맞은편에서 차가 와요! 오른쪽 차선으로", UiTheme.COLOR_WARN)
		var cp := _car_pos(c)
		var dv := _pos - cp
		if _state == State.DRIVING and dv.length() < CAR_R * 2.0 + 2.0:
			_pos = cp + dv.normalized() * (CAR_R * 2.0 + 2.0)
			if float(c["cd"]) <= 0.0:
				c["cd"] = 1.5
				_speed *= 0.6
				_vel *= 0.6
				_damage("car")


func _car_pos(c: Dictionary) -> Vector2:
	var o := clampf(float(c["offset"]), 0.0, _length)
	return _curve.sample_baked(o) + _normal(o) * float(c["lat"])


func traffic_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for c: Dictionary in _traffic:
		if float(c["offset"]) >= 0.0:
			out.append(_car_pos(c))
	return out


# ---------------------------------------------------------------- items
## Barricades close one lane here and there (never both); stars and drinks are pickups.
func _place_items() -> void:
	var kinds: Array[String] = []
	for i in int(_easy.get("barricades", BARRICADES)) + (2 if Story.is_urgent() else 0):
		kinds.append("barricade")
	for i in STARS:
		kinds.append("star")
	for i in DRINKS:
		kinds.append("drink")
	kinds.shuffle()
	var span := _length - 700.0
	var tex := {"barricade": "barricade.png", "star": "pickup_star.png", "drink": "pickup_drink.png"}
	var last_barricade := -INF
	for i in kinds.size():
		var o := 350.0 + span * (i + _rng.randf_range(0.15, 0.85)) / kinds.size()
		if kinds[i] == "barricade":
			if o - last_barricade < BARRICADE_GAP:
				kinds[i] = "star"  # too close to the last one: a pickup instead
			else:
				last_barricade = o
		var lat := (LANE if _rng.randf() < 0.5 else -LANE) if kinds[i] == "barricade" \
				else _rng.randf_range(-ROAD_HALF + 14.0, ROAD_HALF - 14.0)
		var s := Sprite2D.new()
		s.texture = load(SPRITES + str(tex[kinds[i]])) as Texture2D
		s.position = _curve.sample_baked(o) + _normal(o) * lat
		if kinds[i] == "barricade":
			s.rotation = _tangent(o).angle() + PI / 2.0  # across the lane
		s.z_index = 3
		add_child(s)
		_items.append({"kind": kinds[i], "node": s, "offset": o, "lateral": lat})


func _check_items() -> void:
	for i in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		var node: Sprite2D = it["node"]
		var hit := false
		if str(it["kind"]) == "barricade":  # a bar across the lane, not a dot
			var across := Vector2.RIGHT.rotated(node.rotation) * 17.0
			hit = Geometry2D.get_closest_point_to_segment(_pos, node.position - across, node.position + across) \
					.distance_to(_pos) < CAR_R + 3.0
		else:
			hit = node.position.distance_to(_pos) < CAR_R + 9.0
		if not hit:
			continue
		_items.remove_at(i)
		match str(it["kind"]):
			"star":
				stars += 1
				GameState.add_money(Story.STAR_BONUS)
				GameState.log_add("money", Story.STAR_BONUS)
				Sound.play("star", 0.06)
				_ui.flash("반짝! +%d원" % Story.STAR_BONUS, UiTheme.COLOR_WARN)
				node.queue_free()
			"drink":
				_charges = mini(MAX_CHARGES, _charges + 1)
				Sound.play("repair")
				_ui.flash("에너지 드링크 획득! 부스터 +1", UiTheme.COLOR_GOOD)
				node.queue_free()
			_:
				_speed *= 0.6
				_vel *= 0.6
				_damage("barricade")
				_knock_away(node)


func _damage(kind: String) -> void:
	var dmg := roundi(int(DAMAGE.get(kind, 5)) * _damage_mult)
	if GameState.condition() == GameState.Condition.GOOD:
		dmg = roundi(dmg * 0.8)
	_hit_cd = 0.8
	stats[kind] = int(stats.get(kind, 0)) + 1
	_wear(float(dmg))
	Sound.play("crash", 0.1)
	var what := {"car": "다른 차", "barricade": "공사 울타리", "fence": "도로 밖 울타리"}
	_ui.flash("쿵! %s에 부딪혔어요 (화물 -%d)" % [what.get(kind, ""), dmg], UiTheme.COLOR_BAD)
	_truck.self_modulate = Color(1, 0.5, 0.5)
	create_tween().tween_property(_truck, "self_modulate", Color.WHITE, 0.35)
	var shake := create_tween()
	for k in 3:
		shake.tween_property(_cam, "offset", Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4)), 0.04)
	shake.tween_property(_cam, "offset", Vector2.ZERO, 0.04)


func _wear(amount: float) -> void:
	_cargo_f = maxf(0.0, _cargo_f - amount)
	cargo = roundi(_cargo_f)


func _knock_away(node: Sprite2D) -> void:
	var side := (node.position - _pos).normalized()
	if side == Vector2.ZERO:
		side = Vector2.RIGHT
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "position", node.position + side * 50.0 + _vel * 0.15, 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", node.rotation + TAU, 0.45)
	tw.tween_property(node, "modulate:a", 0.0, 0.45).set_delay(0.15)
	tw.chain().tween_callback(node.queue_free)


# ---------------------------------------------------------------- booster
func _boost() -> void:
	if _state != State.DRIVING:
		return
	if _charges > 0:
		_charges -= 1
	elif GameState.item_count("energybar") > 0:
		Story.use_quick_item(true)  # drinks one from the bag (also eases fatigue)
	else:
		_ui.flash("부스터가 없어요. 드리프트로 게이지를 채워요!", UiTheme.COLOR_DIM)
		return
	_boost_t = BOOST_TIME
	_drowsy_block = 8.0
	_speed = maxf(_speed, MAX_SPEED)
	Sound.play("repair")
	_ui.flash("부스터!", UiTheme.COLOR_WARN)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_item"):
		get_viewport().set_input_as_handled()
		_boost()


# ---------------------------------------------------------------- helpers
func _tangent(o: float) -> Vector2:
	var a := _curve.sample_baked(clampf(o - 4.0, 0.0, _length))
	var b := _curve.sample_baked(clampf(o + 4.0, 0.0, _length))
	return (b - a).normalized()


func _normal(o: float) -> Vector2:
	return _tangent(o).orthogonal()


func _sync_sprites() -> void:
	_truck.position = _pos
	_truck.rotation = _heading
	for c: Dictionary in _traffic:
		var s: Sprite2D = c["node"]
		var o := float(c["offset"])
		s.visible = o >= 0.0
		if not s.visible:
			continue
		s.position = _car_pos(c)
		s.rotation = _tangent(o).angle() + PI / 2.0 + (PI if float(c["speed"]) < 0.0 else 0.0)
	_fx.update(_pos, _heading, _boost_t > 0.0, _drifting)
	_cam.position = _pos + _vel * 0.3


func progress() -> float:
	return clampf(_offset / _length, 0.0, 1.0)


func time_left() -> float:
	return time_limit - maxf(_t, 0.0)


func charges() -> int:
	return _charges


func gauge() -> float:
	return _gauge


func elapsed() -> float:
	return maxf(_t, 0.0)


func curve() -> Curve2D:
	return _curve


func player_pos() -> Vector2:
	return _pos


# ================================================================ drawing helpers
## Paved yard in front of the start and destination buildings.
class Yard:
	extends Node2D
	var radius := 80.0

	func _ready() -> void:
		z_index = -6

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius + 4.0, Color("261e2c"))
		draw_circle(Vector2.ZERO, radius, Color("d8d2c4"))
		var y := -radius + 10.0
		while y < radius:
			var w := sqrt(maxf(radius * radius - y * y, 0.0))
			draw_line(Vector2(-w, y), Vector2(w, y), Color("c8c2b4"), 1.0)
			y += 12.0


## The road and its surroundings for the course theme, drawn once.
class TrackView:
	extends Node2D
	var _curve: Curve2D
	var _theme: Dictionary
	var _seed := 0
	const INK := Color("261e2c")

	func setup(c: Curve2D, theme: Dictionary, seed_value: int) -> void:
		_curve = c
		_theme = theme
		_seed = seed_value
		z_index = -10

	func _draw() -> void:
		var pts := _curve.get_baked_points()
		var r := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(p)
		draw_rect(r.grow(900), _theme["ground"])
		if _theme.has("band"):
			_draw_band()
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + _seed
		_draw_decor(rng)
		if _theme.has("sidewalk"):
			_thick(pts, _theme["sidewalk"], RaceGame.ROAD_HALF + 22.0)
		_thick(pts, _theme["edge"], RaceGame.ROAD_HALF + 4.0)
		_thick(pts, _theme["road"], RaceGame.ROAD_HALF)
		if _theme.has("fence"):
			_draw_fences(_theme["fence"])
		var total := _curve.get_baked_length()
		var o := 40.0
		while o < total - 40.0:  # center line
			draw_line(_curve.sample_baked(o), _curve.sample_baked(o + 16.0), Color("f0d060"), 3.0)
			o += 40.0
		if _theme.has("sidewalk"):  # crosswalks now and then
			o = 500.0
			while o < total - 300.0:
				_crosswalk(o)
				o += 900.0

	func _thick(pts: PackedVector2Array, col: Color, half: float) -> void:
		draw_polyline(pts, col, half * 2.0)
		for i in range(0, pts.size(), 2):
			draw_circle(pts[i], half, col)
		draw_circle(pts[pts.size() - 1], half, col)

	func _tangent(o: float) -> Vector2:
		var total := _curve.get_baked_length()
		return (_curve.sample_baked(minf(o + 6.0, total)) - _curve.sample_baked(maxf(o - 6.0, 0.0))).normalized()

	## A river (or the sea, wider with a beach) along the left side of the road.
	func _draw_band() -> void:
		var col: Color = _theme["band"]
		var sea := _theme.has("sea")
		var width := 260.0 if sea else 110.0
		var total := _curve.get_baked_length()
		var line := PackedVector2Array()
		var o := 0.0
		var dist := RaceGame.ROAD_HALF + 70.0 + width / 2.0
		while o <= total:
			line.append(_curve.sample_baked(o) + _tangent(o).orthogonal() * dist)
			o += 16.0
		draw_polyline(line, col.lightened(0.55) if sea else Color("6fae4f"), width + 40.0)
		draw_polyline(line, col, width)
		draw_polyline(line, col.lightened(0.18), width * 0.35)

	## Wooden post-and-rail fences along both sides of a country road.
	func _draw_fences(col: Color) -> void:
		var total := _curve.get_baked_length()
		var o := 20.0
		while o < total - 44.0:
			var o2 := o + 24.0
			for side: float in [-1.0, 1.0]:
				var p := _curve.sample_baked(o) + _tangent(o).orthogonal() * side * (RaceGame.ROAD_HALF + 12.0)
				var q := _curve.sample_baked(o2) + _tangent(o2).orthogonal() * side * (RaceGame.ROAD_HALF + 12.0)
				draw_line(p, q, col, 2.0)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), col.darkened(0.3))
			o = o2

	func _crosswalk(o: float) -> void:
		var c := _curve.sample_baked(o)
		var t := _tangent(o)
		var n := t.orthogonal()
		for k in 7:
			var a := c + n * (-RaceGame.ROAD_HALF + 6.0 + k * 13.0)
			draw_colored_polygon(PackedVector2Array([a - t * 8.0, a - t * 8.0 + n * 7.0, a + t * 8.0 + n * 7.0, a + t * 8.0]),
					Color(1, 1, 1, 0.85))

	func _draw_decor(rng: RandomNumberGenerator) -> void:
		var table: Array = _theme["decor"]
		var weight := 0
		for e: Array in table:
			weight += int(e[1])
		var colors: Array = _theme["colors"]
		var total := _curve.get_baked_length()
		var start := _curve.sample_baked(0.0)
		var end := _curve.sample_baked(total)
		var near_road := RaceGame.ROAD_HALF + (52.0 if _theme.has("sidewalk") else 30.0)
		var band_far := RaceGame.ROAD_HALF + 70.0 + (300.0 if _theme.has("sea") else 140.0)
		var tries := int(_theme.get("density", 1))
		var o := 0.0
		while o < total:
			var c := _curve.sample_baked(o)
			var t := _tangent(o)
			var n := t.orthogonal()
			var sides: Array[float] = []
			for k in tries:
				sides.append_array([-1.0, 1.0])
			for side: float in sides:
				var lo := near_road
				if _theme.has("band") and side > 0.0:
					lo = band_far  # the water side: things go past the water
				var p := c + n * side * (lo + rng.randf_range(10.0, 230.0)) + t * rng.randf_range(-25, 25)
				if _curve.get_closest_point(p).distance_to(p) < near_road:
					continue  # too close to another part of the road
				if p.distance_to(start) < 190.0 or p.distance_to(end) < 230.0:
					continue  # room for the buildings
				var pick := rng.randi() % weight
				var kind := ""
				for e: Array in table:
					pick -= int(e[1])
					if pick < 0:
						kind = str(e[0])
						break
				_decor(kind, p, colors[rng.randi() % colors.size()], rng)
			o += 64.0

	func _decor(kind: String, p: Vector2, col: Color, rng: RandomNumberGenerator) -> void:
		match kind:
			"tower":  # downtown building from above: roof, rooftop unit, window strips
				var s := Vector2(rng.randf_range(48, 78), rng.randf_range(44, 70))
				var rect := Rect2(p - s / 2.0, s)
				draw_rect(Rect2(rect.position + Vector2(4, 4), s), Color(0, 0, 0, 0.18))
				draw_rect(rect, col)
				draw_rect(rect.grow(-4), col.lightened(0.12))
				var y := rect.position.y + 8.0
				while y < rect.end.y - 8.0:
					draw_rect(Rect2(rect.position.x + 7, y, s.x - 14, 3), Color("8ec8f0"))
					y += 9.0
				draw_rect(Rect2(p - Vector2(8, 6), Vector2(16, 12)), col.darkened(0.25))
				draw_rect(rect, INK, false, 2.0)
			"apartment":  # long apartment block
				var s := Vector2(rng.randf_range(80, 110), 34)
				var rect := Rect2(p - s / 2.0, s)
				draw_rect(Rect2(rect.position + Vector2(4, 4), s), Color(0, 0, 0, 0.18))
				draw_rect(rect, col)
				draw_rect(Rect2(rect.position, Vector2(s.x, 8)), Color("c86a5a"))
				var x := rect.position.x + 5.0
				while x < rect.end.x - 6.0:
					draw_rect(Rect2(x, rect.position.y + 13, 5, 5), Color("8ec8f0"))
					draw_rect(Rect2(x, rect.position.y + 23, 5, 5), Color("8ec8f0"))
					x += 9.0
				draw_rect(rect, INK, false, 2.0)
			"shop":
				var rect := Rect2(p - Vector2(24, 16), Vector2(48, 32))
				draw_rect(rect, Color("f4ead8"))
				draw_rect(Rect2(rect.position, Vector2(48, 10)), col)
				draw_rect(Rect2(rect.position + Vector2(8, 16), Vector2(14, 12)), Color("8ec8f0"))
				draw_rect(Rect2(rect.position + Vector2(28, 16), Vector2(12, 16)), Color("8a5a36"))
				draw_rect(rect, INK, false, 2.0)
			"stall":  # market stall with a striped awning and produce
				var rect := Rect2(p - Vector2(18, 12), Vector2(36, 24))
				draw_rect(rect, Color("f4ead8"))
				for k in 4:
					draw_rect(Rect2(rect.position.x + k * 9, rect.position.y, 9, 9), col if k % 2 == 0 else Color.WHITE)
				for k in 3:
					draw_circle(rect.position + Vector2(8 + k * 10, 17), 3, [Color("e05050"), Color("f0c040"), Color("5fbf6f")][k])
				draw_rect(rect, INK, false, 2.0)
			"crowd":
				for k in 5:
					var q := p + Vector2(rng.randf_range(-14, 14), rng.randf_range(-10, 10))
					draw_circle(q, 4, [Color("e05050"), Color("4f8fe0"), Color("f0c040"), Color("5fbf6f")][k % 4])
					draw_circle(q + Vector2(0, -3), 2.5, Color("ffe2c8"))
			"house":  # farmhouse from above: colored roof with a ridge, a little yard
				draw_rect(Rect2(p - Vector2(30, 24), Vector2(60, 48)), Color("d8c8a0"))
				var roof := Rect2(p - Vector2(22, 14), Vector2(44, 28))
				draw_rect(roof, col)
				draw_line(Vector2(roof.position.x, p.y), Vector2(roof.end.x, p.y), col.darkened(0.35), 2.0)
				draw_rect(roof, INK, false, 2.0)
			"paddy":  # rice paddy with rows of seedlings (green, or ripe gold)
				var gold := rng.randf() < 0.4
				var s := Vector2(rng.randf_range(70, 100), rng.randf_range(50, 70))
				var rect := Rect2(p - s / 2.0, s)
				draw_rect(rect, Color("e0c860") if gold else Color("6fbf5a"))
				var y := rect.position.y + 5.0
				while y < rect.end.y - 3.0:
					draw_line(Vector2(rect.position.x + 3, y), Vector2(rect.end.x - 3, y), Color("c8a840") if gold else Color("4f9f45"), 2.0)
					y += 7.0
				draw_rect(rect, Color("8a6a40"), false, 3.0)
			"haystack":
				draw_circle(p, 11, Color("e8d080"))
				draw_arc(p, 11, 0, TAU, 14, INK, 2.0)
				draw_arc(p, 6, 0, TAU, 10, Color("c8a850"), 1.0)
			"persimmon":
				_tree(p, Color("5f9f45"), 12)
				for k in 4:
					draw_circle(p + Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7)), 2.2, Color("f08a30"))
			"pine":
				draw_circle(p + Vector2(3, 4), 12, Color(0, 0, 0, 0.15))
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -16), p + Vector2(13, 8), p + Vector2(-13, 8)]), col)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -22), p + Vector2(9, -2), p + Vector2(-9, -2)]), col.lightened(0.15))
				draw_polyline(PackedVector2Array([p + Vector2(0, -22), p + Vector2(13, 8), p + Vector2(-13, 8), p + Vector2(0, -22)]), INK, 2.0)
			"rock":
				draw_circle(p, 10, Color("9a9aa4"))
				draw_circle(p + Vector2(-3, -3), 4, Color("b8b8c0"))
				draw_arc(p, 10, 0, TAU, 12, INK, 2.0)
			"reeds":
				for k in 5:
					var q := p + Vector2(k * 4 - 8, 0)
					draw_line(q, q + Vector2(rng.randf_range(-3, 3), -14), Color("6f8f3a"), 2.0)
					draw_rect(Rect2(q + Vector2(-1, -16), Vector2(3, 5)), Color("8a6a40"))
			"palm":
				draw_line(p, p + Vector2(4, -6), Color("8a6a40"), 3.0)
				for k in 5:
					draw_line(p + Vector2(4, -6), p + Vector2(4, -6) + Vector2.from_angle(k * TAU / 5.0) * 14.0, Color("3f9f45"), 4.0)
				draw_circle(p + Vector2(4, -6), 3, Color("8a6a40"))
			"parasol":
				draw_circle(p, 13, col)
				for k in 4:
					draw_line(p, p + Vector2.from_angle(k * TAU / 4.0 + 0.4) * 13.0, Color.WHITE, 2.0)
				draw_arc(p, 13, 0, TAU, 16, INK, 2.0)
				draw_rect(Rect2(p + Vector2(10, 4), Vector2(14, 7)), Color("f4f0e0"))
			"bench":
				draw_rect(Rect2(p - Vector2(12, 4), Vector2(24, 8)), Color("b07a48"))
				draw_rect(Rect2(p - Vector2(12, 4), Vector2(24, 8)), INK, false, 1.5)
			"flowers":
				draw_circle(p, 10, Color("5fa045"))
				for k in 6:
					draw_circle(p + Vector2.from_angle(k * 1.05) * 6.0, 2.2, [Color("ff8fb0"), Color("fff0a0"), Color.WHITE][k % 3])
			"pond":
				draw_circle(p, 26, Color("8a6a40"))
				draw_circle(p, 23, Color("5aa0e0"))
				draw_circle(p + Vector2(-6, -6), 6, Color("8ec8f0"))
			"lamp":  # street light by the sidewalk
				draw_circle(p, 9, Color(1.0, 0.95, 0.6, 0.35))
				draw_circle(p, 3, INK)
			"street_tree":
				_tree(p, Color("4f9f45"), 10)
			"playground":
				draw_rect(Rect2(p - Vector2(28, 20), Vector2(56, 40)), Color("e8d0a0"))
				draw_rect(Rect2(p - Vector2(20, 12), Vector2(14, 6)), Color("e05050"))
				draw_circle(p + Vector2(10, 4), 7, Color("4f8fe0"))
				draw_rect(Rect2(p - Vector2(28, 20), Vector2(56, 40)), INK, false, 2.0)
			_:  # tree
				_tree(p, col, 13)

	func _tree(p: Vector2, col: Color, r: float) -> void:
		draw_circle(p + Vector2(3, 4), r, Color(0, 0, 0, 0.15))
		draw_circle(p, r, col)
		draw_arc(p, r, 0, TAU, 14, INK, 2.0)
		draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, col.lightened(0.25))


## Tire marks left while drifting (a short ring buffer).
class Skids:
	extends Node2D
	const MAX := 160
	var _marks: Array[PackedVector2Array] = []

	func _init() -> void:
		z_index = -5

	func add(a: Vector2, b: Vector2) -> void:
		_marks.append(PackedVector2Array([a, b]))
		if _marks.size() > MAX:
			_marks.pop_front()
		queue_redraw()

	func _draw() -> void:
		for m in _marks:
			draw_line(m[0], m[0] + (m[1] - m[0]).normalized() * 2.0, Color(0.1, 0.1, 0.12, 0.5), 3.0)


## Booster flame and drift sparks behind the player.
class Effects:
	extends Node2D
	var _boost := false
	var _drift := false
	var _t := 0.0

	func update(pos: Vector2, heading: float, boosting: bool, drifting: bool) -> void:
		position = pos
		rotation = heading
		_boost = boosting
		_drift = drifting
		_t += get_process_delta_time()
		queue_redraw()

	func _draw() -> void:
		if _boost:
			var l := 14.0 + sin(_t * 40.0) * 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(-5, 14), Vector2(5, 14), Vector2(0, 14 + l)]), Color("ff9a3c"))
			draw_colored_polygon(PackedVector2Array([Vector2(-2, 14), Vector2(2, 14), Vector2(0, 14 + l * 0.6)]), Color("fff0a0"))
		if _drift:
			for k in 4:
				var a := _t * 30.0 + k * 1.7
				var side := -8.0 if k % 2 == 0 else 8.0
				draw_rect(Rect2(Vector2(side + sin(a) * 2.0, 15 + fmod(a, 6.0)), Vector2(2, 2)), Color("ffd060"))


## HUD: course, time left, cargo, boosters, drift gauge, minimap, touch buttons.
class RaceHud:
	extends CanvasLayer
	var game: RaceGame
	var _progress: ProgressBar
	var _cargo: Label
	var _time: Label
	var _boost: Label
	var _gauge: ProgressBar
	var _center: Label
	var _map: Minimap

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
		vb.add_child(UiTheme.make_label("%s 납품 중" % Korean.ro(Story.destination_name()), UiTheme.SIZE, UiTheme.COLOR_BORDER, true))
		vb.add_child(UiTheme.make_label("코스: " + track_name, UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))
		_time = UiTheme.make_label("", UiTheme.SIZE_LARGE, UiTheme.COLOR_TEXT, true)
		vb.add_child(_time)
		_progress = ProgressBar.new()
		_progress.custom_minimum_size = Vector2(130, 8)
		_progress.show_percentage = false
		vb.add_child(_progress)
		_cargo = UiTheme.make_label("", UiTheme.SIZE_SMALL)
		vb.add_child(_cargo)
		var tags := PackedStringArray()
		if Story.is_urgent():
			tags.append("긴급")
		if bool(Story.current_task().get("fragile", false)):
			tags.append("파손 주의")
		if not tags.is_empty():
			vb.add_child(UiTheme.make_label("[" + " · ".join(tags) + "]", UiTheme.SIZE_SMALL, UiTheme.COLOR_BAD))

		_map = Minimap.new()
		_map.game = game
		_map.anchor_left = 1.0
		_map.anchor_right = 1.0
		_map.offset_left = -m - 110
		_map.offset_right = -m
		_map.offset_top = 6
		_map.offset_bottom = 96
		_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_map)

		var bp := PanelContainer.new()
		bp.anchor_left = 1.0
		bp.anchor_right = 1.0
		bp.offset_left = -m - 110
		bp.offset_right = -m
		bp.offset_top = 100
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bp.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8))
		root.add_child(bp)
		var bvb := VBoxContainer.new()
		bp.add_child(bvb)
		_boost = UiTheme.make_label("", UiTheme.SIZE_SMALL, UiTheme.COLOR_WARN, true)
		bvb.add_child(_boost)
		bvb.add_child(UiTheme.make_label("드리프트 게이지", UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM))
		_gauge = ProgressBar.new()
		_gauge.custom_minimum_size = Vector2(96, 7)
		_gauge.show_percentage = false
		var fill := (UiTheme.theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat).duplicate() as StyleBoxFlat
		fill.bg_color = Color("ff9a3c")
		_gauge.add_theme_stylebox_override("fill", fill)
		bvb.add_child(_gauge)

		var hint_text := "← → 핸들 / ↓ 감속 / Shift 드리프트 / Q 에너지 드링크 부스터 (가속은 자동)"
		if GameState.is_touch_device():
			hint_text = "◀ ▶ 핸들 / 감속 / 드리프트 / 부스터 버튼 (가속은 자동)"
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
			["move_left", "◀", Vector2(m + 4, view.y - 64)], ["move_right", "▶", Vector2(m + 66, view.y - 64)],
			["move_down", "감속", Vector2(view.x - m - 194, view.y - 64)],
			["run", "드리프트", Vector2(view.x - m - 128, view.y - 64)], ["quick_item", "부스터", Vector2(view.x - m - 62, view.y - 64)],
		]
		var tex := load("res://assets/sprites/placeholder/touch_a.png") as Texture2D
		for sp: Array in specs:
			var b := TouchScreenButton.new()
			b.texture_normal = tex
			b.action = str(sp[0])
			b.scale = Vector2(1.3, 1.3)
			b.position = sp[2]
			add_child(b)
			var l := UiTheme.make_label(str(sp[1]), UiTheme.SIZE_SMALL, UiTheme.COLOR_TEXT, true)
			l.position = Vector2(-6, 20)  # 12 px text (11/18) is wider than the button
			l.size = Vector2(56, 12)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			l.add_theme_constant_override("outline_size", 4)
			b.add_child(l)

	func refresh() -> void:
		_progress.value = game.progress() * 100.0
		_cargo.text = "화물 상태 %d%%" % game.cargo
		var left := game.time_left()
		if left >= 0.0:
			_time.text = "남은 시간 %d초" % ceili(left)
			_time.add_theme_color_override("font_color", UiTheme.COLOR_BAD if left < 8.0 else UiTheme.COLOR_TEXT)
		else:
			_time.text = "기한 초과 +%d초" % ceili(-left)
			_time.add_theme_color_override("font_color", UiTheme.COLOR_BAD)
		var cans := ""
		for i in RaceGame.MAX_CHARGES:
			cans += "●" if i < game.charges() else "○"
		var bag := GameState.item_count("energybar")
		_boost.text = "부스터 %s" % cans + ("  가방 %d" % bag if bag > 0 else "")
		_gauge.value = game.gauge()
		_map.queue_redraw()

	func set_center(text: String) -> void:
		_center.text = text

	## Popup before the countdown: title, lines (the first one big), key caps on
	## keyboards, and a button. Space / Enter / Esc or the button close it.
	func show_guide(data: Dictionary, on_close: Callable) -> void:
		var layer_root := Control.new()
		layer_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		UiTheme.apply(layer_root)
		add_child(layer_root)
		var dim := ColorRect.new()
		dim.color = Color(0.04, 0.04, 0.08, 0.5)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer_root.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer_root.add_child(center)
		var panel := PanelContainer.new()
		var sb := UiTheme.panel_box(0.97)
		sb.set_content_margin_all(12)
		panel.add_theme_stylebox_override("panel", sb)
		center.add_child(panel)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		panel.add_child(vb)
		var title := UiTheme.make_label(str(data.get("title", "")), UiTheme.SIZE, UiTheme.COLOR_BORDER, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(title)
		if not GameState.is_touch_device():
			var caps := KeyCaps.new()
			caps.custom_minimum_size = Vector2(150, 30)
			caps.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vb.add_child(caps)
		var lines: Array = data.get("lines", [])
		for i in lines.size():
			var l := UiTheme.make_label(str(lines[i]), UiTheme.SIZE_LARGE if i == 0 else UiTheme.SIZE,
					UiTheme.COLOR_WARN if i == 0 else UiTheme.COLOR_TEXT, i == 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(l)
		var btn := Button.new()
		btn.text = str(data.get("btn", ""))
		btn.custom_minimum_size = Vector2(120, 26)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(btn)
		btn.grab_focus()  # Space / Enter press it
		var close := func() -> void:
			if is_instance_valid(layer_root):
				layer_root.queue_free()
				on_close.call()
		btn.pressed.connect(close)
		_guide_close = close

	var _guide_close := Callable()

	func _unhandled_input(event: InputEvent) -> void:
		if _guide_close.is_valid() and event.is_action_pressed("cancel"):
			var c := _guide_close
			_guide_close = Callable()
			c.call()
			get_viewport().set_input_as_handled()

	func flash(text: String, color: Color) -> void:
		Dialogue.toast(text, color)


## Whole course in the corner: road, the destination, traffic, the player.
class Minimap:
	extends Control
	var game: RaceGame
	var _pts := PackedVector2Array()
	var _rect := Rect2()

	func _draw() -> void:
		var c := game.curve()
		if _pts.is_empty():
			_pts = c.get_baked_points()
			_rect = Rect2(_pts[0], Vector2.ZERO)
			for p in _pts:
				_rect = _rect.expand(p)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.14, 0.75))
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_BORDER, false, 1.0)
		var sc := minf((size.x - 12) / maxf(_rect.size.x, 1.0), (size.y - 12) / maxf(_rect.size.y, 1.0))
		var off := (size - _rect.size * sc) / 2.0
		var mp := func(p: Vector2) -> Vector2: return (p - _rect.position) * sc + off
		var line := PackedVector2Array()
		for i in range(0, _pts.size(), 4):
			line.append(mp.call(_pts[i]))
		line.append(mp.call(_pts[_pts.size() - 1]))
		draw_polyline(line, Color("a0a4b4"), 3.0)
		var goal: Vector2 = mp.call(_pts[_pts.size() - 1])
		draw_rect(Rect2(goal - Vector2(4, 4), Vector2(8, 8)), Color("ef6b5b"))
		draw_rect(Rect2(goal - Vector2(4, 4), Vector2(8, 8)), Color.WHITE, false, 1.0)
		for p in game.traffic_positions():
			draw_circle(mp.call(p), 1.6, Color("d0d0d8"))
		draw_circle(mp.call(game.player_pos()), 3.5, Color("ffe08a"))
		draw_arc(mp.call(game.player_pos()), 3.5, 0, TAU, 10, Color.BLACK, 1.0)


## Guide popup picture: the ← → keys lit, ↑ ↓ dimmed and crossed out.
class KeyCaps:
	extends Control

	func _draw() -> void:
		var cap := Vector2(28, 26)
		var font := UiTheme.FONT_BOLD
		var keys := [["←", 0.0, true], ["↑", 46.0, false], ["↓", 76.0, false], ["→", 122.0, true]]
		for k: Array in keys:
			var r := Rect2(Vector2(float(k[1]), (size.y - cap.y) / 2.0), cap)
			var on := bool(k[2])
			draw_rect(r, Color("f2c14e") if on else Color(1, 1, 1, 0.1))
			draw_rect(r, Color("261e2c") if on else Color(1, 1, 1, 0.3), false, 1.0)
			var glyph := str(k[0])
			var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE).x
			draw_string(font, Vector2(r.position.x + (cap.x - w) / 2.0, r.position.y + 17), glyph,
					HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE, Color("261e2c") if on else Color(1, 1, 1, 0.8))
			if not on:  # a thin cross so the arrow stays readable
				var x := Color(UiTheme.COLOR_BAD, 0.85)
				draw_line(r.position + Vector2(2, 2), r.end - Vector2(2, 2), x, 1.0)
				draw_line(Vector2(r.end.x - 2, r.position.y + 2), Vector2(r.position.x + 2, r.end.y - 2), x, 1.0)
