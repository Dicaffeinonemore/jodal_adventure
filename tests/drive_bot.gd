extends SceneTree
## Plays the driving minigame with a dodging bot that reacts like a person (it acts
## REACTION seconds after it decides) and with no input, a few times each.
##   godot --headless --path . --fixed-fps 60 --script res://tests/drive_bot.gd
## Prints one line per run and "DRIVE OK" when the bot averages >= 85% cargo.

const RUNS := 5
const LOOK_AHEAD := 120.0  # px above the truck the bot reacts to
const REACTION := 0.35  # seconds between seeing a hazard and steering

var _pending_dir := 0
var _pending_t := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs := root.get_node("/root/GameState")
	var bot_total := 0
	for mode: String in ["bot", "idle"]:
		for r in RUNS:
			gs.call("set_task", {"index": 0, "step": 2, "vendor": 0, "cargo": 0, "grade": "", "urgent": r == 0,
					"discount": -1, "discount_rolled": true, "stars": 0})
			gs.set("fatigue", 0)
			change_scene_to_file("res://scenes/minigames/drive.tscn")
			for i in 5:
				await process_frame
			var drive := current_scene
			var hits := 0
			var last_cargo := 100
			while current_scene == drive and int(drive.get("_state")) != 2:
				if mode == "bot" and int(drive.get("_state")) == 1:
					_steer(drive, 1.0 / 60.0)
				var c := int(drive.get("cargo"))
				if c < last_cargo:
					hits += 1
				last_cargo = c
				await process_frame
			var cargo := int(drive.get("cargo"))
			print("  %s run %d%s: cargo %d%%, hits %d" % [mode, r + 1, " (urgent)" if r == 0 else "", cargo, hits])
			if mode == "bot":
				bot_total += cargo
			for i in 120:  # let the finish timer move on to the destination map
				await process_frame
	var avg := bot_total / float(RUNS)
	print("bot average cargo %.0f%%" % avg)
	print("DRIVE OK" if avg >= 85.0 else "DRIVE TOO HARD")
	root.get_node("/root/Sound").call("stop_all")
	await process_frame
	quit(0 if avg >= 85.0 else 1)


## Moves to the safest lane (nearest hazard ahead farthest away), REACTION seconds
## after deciding.
func _steer(drive: Node, delta: float) -> void:
	if _pending_dir != 0:
		_pending_t -= delta
		if _pending_t <= 0.0:
			drive.call("_change_lane", _pending_dir)
			_pending_dir = 0
		return
	var truck: Sprite2D = drive.get("_truck")
	var lane := int(drive.get("_lane"))
	var nearest := [INF, INF, INF]
	for ob: Dictionary in drive.get("_obstacles"):
		var kind := str(ob["kind"])
		if kind == "star" or kind == "repair":
			continue
		var dy := truck.position.y - (ob["node"] as Sprite2D).position.y
		if dy > -20.0:
			var l := int(ob["lane"])
			nearest[l] = minf(nearest[l], dy)
	if nearest[lane] > LOOK_AHEAD:
		return
	var best := lane
	for l in 3:
		if absi(l - lane) == 1 and nearest[l] > nearest[best]:
			best = l
	if best != lane:
		_pending_dir = best - lane
		_pending_t = REACTION
