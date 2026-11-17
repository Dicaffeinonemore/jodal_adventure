class_name Interactable
extends Node2D
## An object the player can use (나라장터 PC, vending machine, the delivery car...).
## Behaviour lives in Story.interact_object(object_id). Give it a texture to
## draw it (the car), or leave the texture empty when the tile already shows it.

var object_id := ""
var interact_radius := 14.0
var _texture: Texture2D
var _solid := false


## solid: blocks the player with a body the size of the texture.
func setup(id: String, texture: Texture2D = null, radius: float = 14.0, solid: bool = false) -> Interactable:
	object_id = id
	name = "Obj_" + id
	_texture = texture
	interact_radius = radius
	_solid = solid
	return self


func _ready() -> void:
	add_to_group("interactable")
	if _texture != null:
		var s := Sprite2D.new()
		s.texture = _texture
		add_child(s)
		if _solid:
			var body := StaticBody2D.new()
			body.collision_layer = 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = _texture.get_size()
			shape.shape = rect
			body.add_child(shape)
			add_child(body)


func interact(player: Player) -> void:
	player.face_toward(global_position)
	Story.interact_object(object_id)
