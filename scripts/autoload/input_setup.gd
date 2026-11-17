extends Node
## Registers every input action in code, so the keyboard and the touch controls
## share one action map. Touch controls (scripts/ui/touch_controls.gd) press
## these same actions, which means gameplay code only ever reads actions.
##
## To add a key: add it here. Nothing in project.godot needs to change.

const KEYS := {
	"move_up": [KEY_UP, KEY_W],
	"move_down": [KEY_DOWN, KEY_S],
	"move_left": [KEY_LEFT, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	"interact": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z],
	"cancel": [KEY_ESCAPE, KEY_X],
	"quick_item": [KEY_Q],
	"run": [KEY_SHIFT],
	# Bottom menu bar shortcuts (Hud): 업무 B, 가방 I, 성장 C, 저장 U
	"menu_task": [KEY_B],
	"menu_bag": [KEY_I],
	"menu_growth": [KEY_C],
	"menu_save": [KEY_U],
	"debug_touch_ui": [KEY_F2],
}


func _enter_tree() -> void:
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for keycode: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode as Key
			InputMap.action_add_event(action, ev)
