extends SceneTree
## Racing minigame check: the autopilot (RaceGame.autopilot) drives every course,
## then one race with no input checks that the time limit still ends it.
##   godot --headless --path . --fixed-fps 60 --script res://tests/drive_bot.gd
## Prints one line per course and "DRIVE OK" when every course is finished within
## 60 s with cargo >= 60% (a careful driver does at least as well), and the idle race
## ends at the time limit.
## RaceGame is loaded at run time: naming the class here would compile it before the
## autoloads exist and the test would never start.

const RACE_SCRIPT := "res://scripts/minigames/race_game.gd"
var _race_script: Script


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_race_script = load(RACE_SCRIPT)
	var ok := true
	for i in TrackData.count():
		var r := await _race(i, true)
		var good := not bool(r["late"]) and float(r["time"]) < 60.0 and int(r["cargo"]) >= 60
		ok = ok and good
		print("  course %d %-10s time %4.1fs cargo %3d%% place %d %s %s" % [i, str(TrackData.TRACKS[i]["name"]),
				float(r["time"]), int(r["cargo"]), int(r["place"]), str(r["stats"]), "" if good else "<- FAIL"])
	var idle := await _race(0, false)
	print("  idle (no input): time %.1fs, late=%s, cargo %d%%" % [float(idle["time"]), str(idle["late"]), int(idle["cargo"])])
	ok = ok and bool(idle["late"])
	print("DRIVE OK" if ok else "DRIVE FAILED")
	_race_script.set("autopilot", false)
	_race_script.set("force_track", -1)
	root.get_node("/root/Sound").call("stop_all")
	await process_frame
	quit(0 if ok else 1)


func _race(track: int, auto: bool) -> Dictionary:
	var gs := root.get_node("/root/GameState")
	gs.call("set_task", {"index": 0, "step": 2, "vendor": 0, "cargo": 0, "grade": "", "urgent": false,
			"discount": -1, "discount_rolled": true, "stars": 0, "qc_done": true})
	gs.set("fatigue", 0)
	_race_script.set("autopilot", auto)
	_race_script.set("force_track", track)
	change_scene_to_file("res://scenes/minigames/drive.tscn")
	for i in 5:
		await process_frame
	var race := current_scene
	while current_scene == race and int(race.get("_state")) != 2:
		await process_frame
	var result := {"time": float(race.call("elapsed")), "cargo": int(race.get("cargo")), "place": int(race.get("_place")),
			"late": bool(race.get("finished_late")), "stats": race.get("stats")}
	for i in 150:  # let it hand over to the destination map
		await process_frame
	return result
