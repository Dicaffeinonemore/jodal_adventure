class_name Player
extends CharacterBody2D
## 4-direction player movement (no diagonals), running, and interaction.
## Reads only input actions, so keyboard and touch work the same.

const SPEED := 72.0
const RUN_SPEED := 124.0  # holding "run" (Shift, or the joystick pushed all the way)
const PROBE_DIST := 12.0
const DIR_VECTORS := {
	"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT,
}

var facing := "down"
var visual: CharacterVisual
var _last_axis := "y"


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	add_child(shape)
	visual = CharacterVisual.new()
	add_child(visual)
	visual.set_look(GameState.get_look())


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if not GameState.is_input_locked():
		dir = _read_direction()
	var running := dir != Vector2.ZERO and Input.is_action_pressed("run")
	velocity = dir * (RUN_SPEED if running else SPEED)
	move_and_slide()
	if dir != Vector2.ZERO:
		facing = _dir_name(dir)
	visual.face(facing, dir != Vector2.ZERO, running)


## Keeps the most recently pressed axis when two are held, so movement stays
## on the four cardinal directions.
func _read_direction() -> Vector2:
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		_last_axis = "x"
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		_last_axis = "y"
	var x := Input.get_axis("move_left", "move_right")
	var y := Input.get_axis("move_up", "move_down")
	var has_x := absf(x) > 0.3
	var has_y := absf(y) > 0.3
	if has_x and has_y:
		if _last_axis == "x":
			has_y = false
		else:
			has_x = false
	if has_x:
		return Vector2(signf(x), 0)
	if has_y:
		return Vector2(0, signf(y))
	return Vector2.ZERO


func _dir_name(v: Vector2) -> String:
	if v.x < 0:
		return "left"
	if v.x > 0:
		return "right"
	if v.y < 0:
		return "up"
	return "down"


func face_toward(target: Vector2) -> void:
	var d := target - global_position
	if absf(d.x) > absf(d.y):
		facing = "right" if d.x > 0 else "left"
	else:
		facing = "down" if d.y > 0 else "up"
	visual.face(facing, false)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_input_locked():
		return
	if event.is_action_pressed("interact"):
		var target := find_interactable()
		if target != null:
			get_viewport().set_input_as_handled()
			target.call("interact", self)
	elif event.is_action_pressed("quick_item"):
		get_viewport().set_input_as_handled()
		Story.use_quick_item(false)


## Nearest node in group "interactable" in front of the player, or null.
## Interactables expose `interact_radius: float` and `interact(player)`.
func find_interactable() -> Node2D:
	var dir: Vector2 = DIR_VECTORS[facing]
	var probe := global_position + dir * PROBE_DIST
	var best: Node2D = null
	var best_dist := INF
	for n: Node in get_tree().get_nodes_in_group("interactable"):
		var n2 := n as Node2D
		if n2 == null or not n2.has_method("interact"):
			continue
		var radius := float(n2.get("interact_radius"))
		var d := n2.global_position.distance_to(probe)
		if d <= radius and d < best_dist:
			best = n2
			best_dist = d
	return best
