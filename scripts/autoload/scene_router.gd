extends Node
## Scene changes with a fade. Maps read `next_spawn` in their _ready to place
## the player.

const TITLE := "res://scenes/title/title.tscn"
const CHARACTER_CREATE := "res://scenes/character_create/character_create.tscn"
const HOME := "res://scenes/maps/home.tscn"
const OFFICE := "res://scenes/maps/office.tscn"
const SCHOOL := "res://scenes/maps/school.tscn"
const FIRE := "res://scenes/maps/fire.tscn"
const CLINIC := "res://scenes/maps/clinic.tscn"
const CENTER := "res://scenes/maps/center.tscn"
const DRIVE := "res://scenes/minigames/drive.tscn"

## Map id (used in task data and Story.DESTINATIONS) -> scene path.
const MAPS := {
	"home": HOME,
	"office": OFFICE,
	"school": SCHOOL,
	"fire": FIRE,
	"clinic": CLINIC,
	"center": CENTER,
}

var next_spawn := ""
var busy := false
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func goto(path: String, spawn: String = "") -> void:
	if busy:
		return
	busy = true
	next_spawn = spawn
	Sound.play("door")
	GameState.lock_input()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, 0.25)
	await out.finished
	get_tree().change_scene_to_file(path)
	# change_scene_to_file is deferred; wait until the new scene has run _ready.
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.unlock_input()
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.25)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false


func goto_map(map_id: String, spawn: String = "") -> void:
	await goto(str(MAPS.get(map_id, HOME)), spawn)
