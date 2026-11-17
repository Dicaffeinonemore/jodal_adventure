class_name RaceGame
extends Node2D
## 납품 레이싱: drive from the 청사 to the destination on one of TrackData's courses,
## against three other delivery trucks. Cargo condition (hits, rough ground) becomes
## the delivery quality at inspection; finishing place and stars pay a bonus.
##
## Controls (actions only): move_left / move_right steer, acceleration is automatic,
## "run" (Shift) drifts (sharper turn, fills the drift gauge: full gauge = +1 booster),
## "quick_item" (Q) drinks an energy drink = booster (a drift charge first, else one
## from the bag). Touch devices get on-screen buttons for the same actions.
## Bad condition makes the wheel jerk now and then (drowsy); a drink stops it a while.
## Story.cargo_damage_mult() scales damage (fragile cargo, truck upgrade).

## Tests: drive by itself (follows the road, drifts, boosts) / pick the course.
static var autopilot := false
static var force_track := -1

const ROAD_HALF := 46.0
const MAX_SPEED := 240.0
const BOOST_SPEED := 350.0
const OFFROAD_SPEED := 115.0
const ACCEL := 230.0
const BRAKE := 420.0
const TURN := 2.5  # rad/s at full grip
const DRIFT_TURN := 3.5
const GRIP := 9.0
const DRIFT_GRIP := 2.0
const BOOST_TIME := 1.4
const DRIFT_FILL := 45.0  # gauge per second of drifting (100 = one booster)
const START_CHARGES := 1
const MAX_CHARGES := 3
const TIME_LIMIT := 75.0
const OFFROAD_DAMAGE := 2.0  # cargo per second on rough ground
const FENCE := 150.0  # past the curb, an invisible fence stops the truck
const COUNTDOWN := 3.0
const CAR_R := 9.0
const OBSTACLES := 9
const STARS := 8
const DRINKS := 2
const DAMAGE := {"cone": 5, "crate": 7, "rival": 3, "fence": 4}
const PLACE_BONUS := [3, 2, 1, 0]  # stars for 1st..4th
const RIVAL_COLORS := [Color("ef6b5b"), Color("7ed37e"), Color("b38cff")]
const RIVAL_SKILL := [0.9, 0.86, 0.82]
const DROWSY_MIN := 4.0
const DROWSY_MAX := 6.5
const SPRITES := "res://assets/sprites/placeholder/"

enum State { COUNTDOWN, RACING, FINISHED }

var cargo := 100
var stars := 0
var track_index := 0
var finished_late := false  # hit the time limit
var stats := {"offroad_s": 0.0}  # damage count by cause + seconds off the road (tests print it)

var _state := State.COUNTDOWN
var _t := -COUNTDOWN
var _curve: Curve2D
var _length := 0.0
var _theme: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _damage_mult := 1.0
var _cargo_f := 100.0  # fractional cargo (rough ground wears it down slowly)

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
var _place := 4

var _truck: Sprite2D
var _rivals: Array[Dictionary] = []  # {sprite, offset, lateral, phase, skill, speed, finished, time}
var _items: Array[Dictionary] = []  # {kind, pos, node}
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
	_damage_mult = Story.cargo_damage_mult()
	_drowsy_timer = _rng.randf_range(DROWSY_MIN, DROWSY_MAX)

	var view := TrackView.new()
	view.setup(_curve, _theme, track_index, Story.destination_name())
	add_child(view)
	_skids = Skids.new()
	add_child(_skids)
	_place_items()
	_spawn_rivals()
	_truck = Sprite2D.new()
	_truck.texture = load(SPRITES + "car_player.png") as Texture2D
	_truck.z_index = 5
	add_child(_truck)
	_fx = Effects.new()
	_fx.z_index = 4
	add_child(_fx)
	_offset = 30.0
	_pos = _curve.sample_baked(_offset)
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
				_state = State.RACING
				_t = 0.0
		State.RACING:
			_t += delta
			if _t > 0.8:
				_ui.set_center("")
			_drive(delta)
			_move_rivals(delta)
			_check_items()
			_check_finish()
		State.FINISHED:
			_move_rivals(delta)
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
	_speed = move_toward(_speed, target, (ACCEL if _speed < target else BRAKE) * delta)
	var dir := Vector2.UP.rotated(_heading)
	_vel = _vel.lerp(dir * _speed, 1.0 - exp(-(DRIFT_GRIP if _drifting else GRIP) * delta))
	_pos += _vel * delta
	_update_offset()

	if offroad:
		stats["offroad_s"] = float(stats["offroad_s"]) + delta
	if offroad and _speed > 40.0:
		_wear(OFFROAD_DAMAGE * delta)
	_hit_cd = maxf(0.0, _hit_cd - delta)
	# invisible fence a little past the curb
	var center := _curve.sample_baked(_offset)
	var away := _pos - center
	if away.length() > ROAD_HALF + FENCE:
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
	# wrong way
	var along := Vector2.UP.rotated(_heading).dot(_tangent(_offset))
	_wrong_way_t = _wrong_way_t + delta if along < -0.3 and _speed > 60.0 else 0.0
	if _wrong_way_t > 1.2:
		_wrong_way_t = -3.0
		_ui.flash("반대 방향이에요! 돌아가요", UiTheme.COLOR_BAD)
	if autopilot and _charges > 0 and _boost_t <= 0.0 and absf(steer) < 0.15 and _t > 2.0:
		_boost()


func _steer_input(delta: float) -> float:
	var s := 0.0
	if autopilot:
		s = _autopilot_steer()
	else:
		s = Input.get_axis("move_left", "move_right")
	# drowsiness: the wheel jerks to one side now and then
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


var _auto_drift := false


## Like a careful player: follows the road and moves over for obstacles ahead.
func _autopilot_steer() -> float:
	var ahead := minf(_offset + 70.0 + _speed * 0.3, _length)
	var lane := 0.0
	for it: Dictionary in _items:
		var k := str(it["kind"])
		if k == "star" or k == "drink":
			continue
		var d := float(it["offset"]) - _offset
		if d > 0.0 and d < 170.0:
			var lat := float(it["lateral"])
			lane = lat - 30.0 if lat > 0.0 else lat + 30.0
			break
	var look := _curve.sample_baked(ahead) + _normal(ahead) * clampf(lane, -ROAD_HALF + 10.0, ROAD_HALF - 10.0)
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
	if _offset >= _length - 20.0:
		_finish(false)
	elif _t >= TIME_LIMIT:
		_finish(true)


func _finish(late: bool) -> void:
	_state = State.FINISHED
	finished_late = late
	var ahead := 0
	for r: Dictionary in _rivals:
		if bool(r["finished"]) or (late and float(r["offset"]) > _offset):
			ahead += 1
	_place = 4 if late else ahead + 1
	var bonus: int = PLACE_BONUS[_place - 1]
	stars += bonus
	var msg := "시간 초과! 늦게 도착했어요" if late else "%d위로 도착!" % _place
	_ui.set_center("%s\n화물 상태 %d%%%s" % [msg, cargo, (" / 순위 보너스 별 +%d" % bonus) if bonus > 0 else ""])
	Sound.play("jingle_good" if _place <= 2 else "pop")
	await get_tree().create_timer(2.0).timeout
	Story.on_drive_finished(cargo, stars)


# ---------------------------------------------------------------- rivals
func _spawn_rivals() -> void:
	var tex := load(SPRITES + "car_rival.png") as Texture2D
	for i in 3:
		var s := Sprite2D.new()
		s.texture = tex
		s.modulate = RIVAL_COLORS[i]
		s.z_index = 5
		add_child(s)
		_rivals.append({
			"sprite": s, "offset": 130.0 - i * 30.0,
			"lateral": [26.0, -26.0, 26.0][i], "phase": _rng.randf() * TAU,
			"skill": RIVAL_SKILL[i] * _rng.randf_range(0.97, 1.03), "speed": 0.0, "finished": false,
		})


## Rivals follow the road; they speed up when far behind the player and ease off
## when far ahead, so the race stays close.
func _move_rivals(delta: float) -> void:
	for r: Dictionary in _rivals:
		if bool(r["finished"]) or _state == State.COUNTDOWN:
			continue
		var gap := _offset - float(r["offset"])
		var skill := float(r["skill"]) + clampf(gap / 4000.0, -0.08, 0.08)
		var target := MAX_SPEED * skill
		r["speed"] = move_toward(float(r["speed"]), target, ACCEL * 0.8 * delta)
		r["offset"] = float(r["offset"]) + float(r["speed"]) * delta
		r["bump_cd"] = maxf(0.0, float(r.get("bump_cd", 0.0)) - delta)
		# weave in its lane, but move over when the player is alongside
		var want := sin(_t * 0.6 + float(r["phase"])) * 22.0
		var o := float(r["offset"])
		if absf(o - _offset) < 70.0:
			var player_lat := (_pos - _curve.sample_baked(o)).dot(_normal(o))
			want = player_lat - 34.0 if player_lat > 0.0 else player_lat + 34.0
		want = clampf(want, -ROAD_HALF + 10.0, ROAD_HALF - 10.0)
		r["lateral"] = move_toward(float(r["lateral"]), want, 60.0 * delta)
		if float(r["offset"]) >= _length:
			r["offset"] = _length
			r["finished"] = true
		# bumping the player: they separate and the rival drops back for a moment
		var rp := _rival_pos(r)
		var dv := _pos - rp
		if _state == State.RACING and dv.length() < CAR_R * 2.0 + 2.0:
			_pos = rp + dv.normalized() * (CAR_R * 2.0 + 2.0)
			if float(r["bump_cd"]) <= 0.0:
				r["bump_cd"] = 1.5
				r["speed"] = float(r["speed"]) * 0.6
				_speed *= 0.9
				if _hit_cd <= 0.0:
					_damage("rival")


func _rival_pos(r: Dictionary) -> Vector2:
	var o := float(r["offset"])
	return _curve.sample_baked(o) + _normal(o) * float(r["lateral"])


func rank_now() -> int:
	var ahead := 0
	for r: Dictionary in _rivals:
		if float(r["offset"]) > _offset:
			ahead += 1
	return ahead + 1


# ---------------------------------------------------------------- items
func _place_items() -> void:
	var extra := 3 if Story.is_urgent() else 0
	var kinds: Array[String] = []
	for i in OBSTACLES + extra:
		kinds.append("cone" if i % 2 == 0 else "crate")
	for i in STARS:
		kinds.append("star")
	for i in DRINKS:
		kinds.append("drink")
	kinds.shuffle()
	var span := _length - 600.0
	for i in kinds.size():
		var o := 350.0 + span * (i + _rng.randf_range(0.1, 0.9)) / kinds.size()
		var lat := _rng.randf_range(-ROAD_HALF + 14.0, ROAD_HALF - 14.0)
		var tex := {"cone": "cone.png", "crate": "race_crate.png", "star": "pickup_star.png", "drink": "pickup_drink.png"}
		var s := Sprite2D.new()
		s.texture = load(SPRITES + str(tex[kinds[i]])) as Texture2D
		s.position = _curve.sample_baked(o) + _normal(o) * lat
		s.z_index = 3
		add_child(s)
		_items.append({"kind": kinds[i], "node": s, "offset": o, "lateral": lat})


func _check_items() -> void:
	for i in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		var node: Sprite2D = it["node"]
		if node.position.distance_to(_pos) > CAR_R + 9.0:
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
				_speed *= 0.7
				_vel *= 0.7
				_damage(str(it["kind"]))
				_knock_away(node)


func _damage(kind: String) -> void:
	var dmg := roundi(int(DAMAGE.get(kind, 5)) * _damage_mult)
	if GameState.condition() == GameState.Condition.GOOD:
		dmg = roundi(dmg * 0.8)
	_hit_cd = 0.8
	stats[kind] = int(stats.get(kind, 0)) + 1
	_wear(float(dmg))
	Sound.play("crash", 0.1)
	var what := {"cone": "꼬깔", "crate": "상자", "rival": "다른 트럭", "fence": "울타리"}
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
	tw.tween_property(node, "position", node.position + side * 60.0 + _vel * 0.15, 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", TAU, 0.45)
	tw.tween_property(node, "modulate:a", 0.0, 0.45).set_delay(0.15)
	tw.chain().tween_callback(node.queue_free)


# ---------------------------------------------------------------- booster
func _boost() -> void:
	if _state != State.RACING:
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
	for r: Dictionary in _rivals:
		var s: Sprite2D = r["sprite"]
		var o := float(r["offset"])
		s.position = _rival_pos(r)
		s.rotation = _tangent(o).angle() + PI / 2.0
	_fx.update(_pos, _heading, _boost_t > 0.0, _drifting)
	_cam.position = _pos + _vel * 0.3


func progress() -> float:
	return clampf(_offset / _length, 0.0, 1.0)


func rival_progress() -> Array[float]:
	var out: Array[float] = []
	for r: Dictionary in _rivals:
		out.append(float(r["offset"]) / _length)
	return out


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


func rival_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r: Dictionary in _rivals:
		out.append(_rival_pos(r))
	return out


# ================================================================ drawing helpers
## The road and its surroundings, drawn once.
class TrackView:
	extends Node2D
	var _curve: Curve2D
	var _theme: Dictionary
	var _seed := 0

	func setup(c: Curve2D, theme: Dictionary, seed_value: int, finish_name: String) -> void:
		_curve = c
		_theme = theme
		_seed = seed_value
		z_index = -10
		var total := c.get_baked_length()
		var end := c.sample_baked(total)
		var board := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("8a5a36")
		sb.border_color = Color("261e2c")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		board.add_theme_stylebox_override("panel", sb)
		board.add_child(UiTheme.make_label("도착: " + finish_name, UiTheme.SIZE, Color("fbf3dc"), true))
		add_child(board)
		board.reset_size()
		board.position = (end + Vector2(-board.size.x / 2.0, -70)).round()

	func _draw() -> void:
		var pts := _curve.get_baked_points()
		var r := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(p)
		r = r.grow(900)
		draw_rect(r, _theme["ground"])
		_draw_decor(pts)
		var edge: Color = _theme["edge"]
		var road: Color = _theme["road"]
		draw_polyline(pts, edge, RaceGame.ROAD_HALF * 2.0 + 8.0)
		for p in pts:
			draw_circle(p, RaceGame.ROAD_HALF + 4.0, edge)
		draw_polyline(pts, road, RaceGame.ROAD_HALF * 2.0)
		for p in pts:
			draw_circle(p, RaceGame.ROAD_HALF, road)
		var total := _curve.get_baked_length()
		var o := 40.0
		while o < total - 40.0:  # center dashes
			var a := _curve.sample_baked(o)
			var b := _curve.sample_baked(o + 16.0)
			draw_line(a, b, Color("f0d060"), 3.0)
			o += 40.0
		_checkered(60.0)
		_checkered(total - 20.0)

	func _checkered(o: float) -> void:
		var a := _curve.sample_baked(maxf(o - 4.0, 0.0))
		var b := _curve.sample_baked(o + 4.0)
		var t := (b - a).normalized()
		var n := t.orthogonal()
		var c := _curve.sample_baked(o)
		for i in 12:
			for j in 2:
				var col := Color.WHITE if (i + j) % 2 == 0 else Color("202028")
				var p := c + n * (-RaceGame.ROAD_HALF + i * RaceGame.ROAD_HALF / 6.0) + t * (j * 6.0 - 6.0)
				draw_colored_polygon(PackedVector2Array([p, p + n * (RaceGame.ROAD_HALF / 6.0),
						p + n * (RaceGame.ROAD_HALF / 6.0) + t * 6.0, p + t * 6.0]), col)

	func _draw_decor(pts: PackedVector2Array) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + _seed
		var kind := str(_theme["decor"])
		var colors: Array = _theme["decor_colors"]
		var ink := Color("261e2c")
		var total := _curve.get_baked_length()
		var o := 0.0
		while o < total:
			var c := _curve.sample_baked(o)
			var t := (_curve.sample_baked(minf(o + 6.0, total)) - _curve.sample_baked(maxf(o - 6.0, 0.0))).normalized()
			var n := t.orthogonal()
			for side: float in [-1.0, 1.0]:
				var p := c + n * side * (RaceGame.ROAD_HALF + rng.randf_range(36.0, 260.0)) + t * rng.randf_range(-30, 30)
				if _curve.get_closest_point(p).distance_to(p) < RaceGame.ROAD_HALF + 28.0:
					continue  # too close to another part of the road
				var col: Color = colors[rng.randi() % colors.size()]
				match kind:
					"building":
						var s := Vector2(rng.randf_range(34, 60), rng.randf_range(30, 52))
						var rect := Rect2(p - s / 2.0, s)
						draw_rect(rect, col)
						draw_rect(rect, ink, false, 2.0)
						var y := rect.position.y + 6.0
						while y < rect.end.y - 8.0:
							var x := rect.position.x + 6.0
							while x < rect.end.x - 8.0:
								draw_rect(Rect2(x, y, 6, 6), Color("8ec8f0"))
								x += 11.0
							y += 11.0
					"rock":
						if rng.randf() < 0.5:
							draw_circle(p, 12, col)
							draw_arc(p, 12, 0, TAU, 14, ink, 2.0)
						else:
							draw_circle(p + Vector2(0, 6), 3, Color("7a5030"))
							draw_colored_polygon(PackedVector2Array([p + Vector2(0, -16), p + Vector2(12, 6), p + Vector2(-12, 6)]), col)
					"water":
						if rng.randf() < 0.35:
							draw_circle(p, rng.randf_range(26, 46), col)
						else:
							draw_circle(p, 10, colors[colors.size() - 1].darkened(0.2))
							draw_arc(p, 10, 0, TAU, 12, ink, 2.0)
					"stall":
						var rect := Rect2(p - Vector2(18, 12), Vector2(36, 24))
						draw_rect(rect, Color("f4ead8"))
						for k in 4:
							draw_rect(Rect2(rect.position.x + k * 9, rect.position.y, 9, 8), col if k % 2 == 0 else Color.WHITE)
						draw_rect(rect, ink, false, 2.0)
					_:  # tree
						draw_circle(p + Vector2(0, 8), 3, Color("7a5030"))
						draw_circle(p, 13, col)
						draw_arc(p, 13, 0, TAU, 14, ink, 2.0)
						draw_circle(p + Vector2(-4, -4), 4, col.lightened(0.25))
			o += 70.0


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


## HUD: course info, cargo, place, time, boosters, drift gauge, minimap, touch buttons.
class RaceHud:
	extends CanvasLayer
	var game: RaceGame
	var _progress: ProgressBar
	var _cargo: Label
	var _place: Label
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
		_progress = ProgressBar.new()
		_progress.custom_minimum_size = Vector2(130, 8)
		_progress.show_percentage = false
		vb.add_child(_progress)
		_cargo = UiTheme.make_label("", UiTheme.SIZE_SMALL)
		vb.add_child(_cargo)
		_place = UiTheme.make_label("", UiTheme.SIZE, UiTheme.COLOR_WARN, true)
		vb.add_child(_place)
		_time = UiTheme.make_label("", UiTheme.SIZE_SMALL, UiTheme.COLOR_DIM)
		vb.add_child(_time)
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

		var hint_text := "← → 핸들 / Shift 드리프트 / Q 에너지 드링크 부스터 (가속은 자동)"
		if GameState.is_touch_device():
			hint_text = "◀ ▶ 핸들 / 드리프트 / 부스터 버튼 (가속은 자동)"
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
			l.position = Vector2(4, 20)
			l.size = Vector2(36, 12)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			l.add_theme_constant_override("outline_size", 4)
			b.add_child(l)

	func refresh() -> void:
		_progress.value = game.progress() * 100.0
		_cargo.text = "화물 상태 %d%%" % game.cargo
		_place.text = "순위 %d / 4" % game.rank_now()
		var t := game.elapsed()
		_time.text = "%d:%02d / 제한 %d초" % [int(t) / 60, int(t) % 60, int(RaceGame.TIME_LIMIT)]
		var cans := ""
		for i in RaceGame.MAX_CHARGES:
			cans += "●" if i < game.charges() else "○"
		var bag := GameState.item_count("energybar")
		_boost.text = "부스터 %s" % cans + ("  가방 %d" % bag if bag > 0 else "")
		_gauge.value = game.gauge()
		_map.queue_redraw()

	func set_center(text: String) -> void:
		_center.text = text

	func flash(text: String, color: Color) -> void:
		Dialogue.toast(text, color)


## Whole course in the corner: road, rivals, the player.
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
		draw_circle(mp.call(_pts[_pts.size() - 1]), 3, Color("ef6b5b"))
		var rp := game.rival_positions()
		for i in rp.size():
			draw_circle(mp.call(rp[i]), 2.5, RaceGame.RIVAL_COLORS[i])
		draw_circle(mp.call(game.player_pos()), 3.5, Color("ffe08a"))
		draw_arc(mp.call(game.player_pos()), 3.5, 0, TAU, 10, Color.BLACK, 1.0)
