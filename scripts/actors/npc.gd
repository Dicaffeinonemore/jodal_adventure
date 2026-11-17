class_name Npc
extends StaticBody2D
## Standing NPC. What it says is decided by Story.talk(npc_id); the NPC itself
## only knows how it looks. NPC ids and sprites are listed in Story.NPCS.

var npc_id := ""
var interact_radius := 16.0
var _sprite: AnimatedSprite2D
var _marker: Label


func setup(id: String) -> Npc:
	npc_id = id
	name = "Npc_" + id
	return self


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 8)
	shape.shape = rect
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.offset = CharacterVisual.FEET_OFFSET
	var tex := load(Story.npc_sprite(npc_id)) as Texture2D
	if tex != null:
		_sprite.sprite_frames = SpriteUtil.idle_frames(tex)
		_sprite.play("idle")
	add_child(_sprite)

	# "!" above the head when Story says this NPC has something for the player.
	_marker = UiTheme.make_label("!", UiTheme.SIZE, UiTheme.COLOR_WARN, true)
	_marker.position = Vector2(-3, -44)
	_marker.hide()
	add_child(_marker)
	GameState.task_changed.connect(_refresh_marker)
	_refresh_marker()


func interact(player: Player) -> void:
	player.face_toward(global_position)
	Story.talk(npc_id)


func _refresh_marker() -> void:
	_marker.visible = Story.npc_has_news(npc_id)
