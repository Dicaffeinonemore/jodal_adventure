class_name Npc
extends CharacterBody2D
## NPC. What it says is decided by Story.talk(npc_id); the NPC itself only knows how it
## looks and where it walks. NPC ids and sprites are listed in Story.NPCS.
##
## Wandering (11/18): unless Story.npc_wanders(id) says no (team leader, cafeteria cook,
## inspector, receivers), the NPC strolls one cell at a time, 4 directions only, within
## WANDER_RADIUS cells of its home cell. MapBase.npc_can_enter() keeps it off walls,
## doors, spawn points and the cells around objects (the PC, the car...), so it never
## stands between the player and something to use. Everyone freezes while a dialogue
## or a full-screen window is open.
##
## People have a full walking sheet (3 rows x 4 columns, like the player); the mascots
## (one row, 2 idle frames) just flip toward where they walk.

const WALK_SPEED := 26.0
const WANDER_RADIUS := 3
const WAIT_MIN := 1.2
const WAIT_MAX := 3.8
const STUCK_TIME := 0.6
const PLAYER_GAP := 18.0  # never step onto a cell this close to the player

## Tests can turn wandering off everywhere.
static var wander_enabled := true

var npc_id := ""
var interact_radius := 16.0
var wander := false
var home := Vector2i.ZERO
var map: MapBase
var _sprite: AnimatedSprite2D
var _marker: Label
var _full_sheet := false
var _facing := "down"
var _target := Vector2.INF
var _from := Vector2.ZERO
var _wait := 0.0
var _stuck := 0.0
var _rng := RandomNumberGenerator.new()


func setup(id: String) -> Npc:
	npc_id = id
	name = "Npc_" + id
	return self


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 1 | 2  # walls, objects, other NPCs and the player
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 8)
	shape.shape = rect
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.offset = CharacterVisual.FEET_OFFSET
	var tex := load(Story.npc_sprite(npc_id)) as Texture2D
	if tex != null:
		_full_sheet = tex.get_height() >= SpriteUtil.CHAR_FRAME.y * 3
		_sprite.sprite_frames = SpriteUtil.character_frames(tex) if _full_sheet else SpriteUtil.idle_frames(tex)
	add_child(_sprite)
	_animate(false)

	# "!" above the head when Story says this NPC has something for the player.
	_marker = UiTheme.make_label("!", UiTheme.SIZE, UiTheme.COLOR_WARN, true)
	_marker.position = Vector2(-3, -44)
	_marker.hide()
	add_child(_marker)
	GameState.task_changed.connect(_refresh_marker)
	_refresh_marker()

	_rng.seed = hash(npc_id) ^ hash(GameState.day)
	_wait = _rng.randf_range(0.3, WAIT_MAX)


func interact(player: Player) -> void:
	player.face_toward(global_position)
	_face_toward(player.global_position)
	Story.talk(npc_id)


func _refresh_marker() -> void:
	_marker.visible = Story.npc_has_news(npc_id)


# ---------------------------------------------------------------- wandering
func _physics_process(delta: float) -> void:
	if not wander or not wander_enabled or map == null:
		return
	if Dialogue.is_open or Dialogue.overlay_open or Story.is_busy() or SceneRouter.busy:
		velocity = Vector2.ZERO
		_animate(false)
		return
	if _target == Vector2.INF:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target()
		return
	var to := _target - position
	var step := WALK_SPEED * delta
	if to.length() <= step:
		position = _target
		_target = Vector2.INF
		_stuck = 0.0
		# Sometimes keep walking for another cell or two, otherwise stand a while.
		_wait = 0.05 if _rng.randf() < 0.45 else _rng.randf_range(WAIT_MIN, WAIT_MAX)
		_animate(false)
		return
	velocity = to.normalized() * WALK_SPEED
	var before := position
	move_and_slide()
	if position.distance_to(before) < step * 0.3:
		_stuck += delta
		if _stuck > STUCK_TIME:  # someone is in the way: go back to where we came from
			_stuck = 0.0
			_target = _from
			_from = before
	else:
		_stuck = 0.0
	_facing = _dir_name(to)
	_animate(true)


func _pick_target() -> void:
	var cell := Vector2i(floori(position.x / Tiles.TILE), floori(position.y / Tiles.TILE))
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for i in range(dirs.size() - 1, 0, -1):  # shuffle with our own rng (repeatable per day)
		var j := _rng.randi_range(0, i)
		var tmp := dirs[i]
		dirs[i] = dirs[j]
		dirs[j] = tmp
	var player := get_tree().get_first_node_in_group("player") as Node2D
	for d: Vector2i in dirs:
		var c := cell + d
		if absi(c.x - home.x) > WANDER_RADIUS or absi(c.y - home.y) > WANDER_RADIUS:
			continue
		if not map.npc_can_enter(c):
			continue
		var center := Tiles.cell_center(c)
		if player != null and player.global_position.distance_to(center) < PLAYER_GAP:
			continue
		_from = Tiles.cell_center(cell)
		_target = center
		return
	_wait = _rng.randf_range(WAIT_MIN, WAIT_MAX)


# ---------------------------------------------------------------- looks
func _face_toward(target: Vector2) -> void:
	_facing = _dir_name(target - global_position)
	_animate(false)


func _dir_name(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"


func _animate(walking: bool) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var anim := "idle"
	if _full_sheet:
		var row := "side" if _facing == "left" or _facing == "right" else _facing
		anim = ("walk_" if walking else "idle_") + row
	_sprite.flip_h = _facing == "left"
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
