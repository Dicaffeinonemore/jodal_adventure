extends SceneTree
## Checks the imported audio without playing it (headless has no real audio):
## every file referenced by the game loads, music loops, effects do not.
##   godot --headless --path . --script res://tests/audio_check.gd
## Prints "AUDIO OK" at the end.

const BGM := ["home", "town", "drive"]
const SFX := [
	"blip", "select", "confirm", "cancel", "pop", "coin", "bad", "warn", "levelup", "jingle_good",
	"jingle_bad", "stamp", "door", "crash", "star", "repair", "nom", "ticket", "alarm", "sleep", "engine",
]


func _initialize() -> void:
	var ok := true
	for id: String in BGM:
		var s := load("res://assets/audio/bgm_%s.wav" % id) as AudioStreamWAV
		if s == null or s.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			push_error("bgm_%s missing or not looping" % id)
			ok = false
		else:
			print("  bgm_%s  %.1fs  loop %d..%d  format %d" % [id, s.get_length(), s.loop_begin, s.loop_end, s.format])
	for id: String in SFX:
		var s := load("res://assets/audio/sfx_%s.wav" % id) as AudioStreamWAV
		if s == null or s.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			push_error("sfx_%s missing or looping" % id)
			ok = false
	print("AUDIO OK" if ok else "AUDIO FAILED")
	quit(0 if ok else 1)
