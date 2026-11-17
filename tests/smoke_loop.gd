extends SceneTree
## Headless smoke test: plays the day cycle and the core loop through the real
## scenes, input actions and dialogue, and fails loudly if anything gets stuck.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/smoke_loop.gd
##
## Prints "SMOKE OK" at the end. Any SCRIPT ERROR in the output is a failure too.
## Deletes user://save.json before starting (the test saves on its own).
## Screenshots: run without --headless and add  -- --shots=<absolute dir>
## Other random events: add  -- --seed=<n>

const TIMEOUT_FRAMES := 60 * 120
const LEADER := Vector2i(13, 4)
const PC := Vector2i(13, 7)
const CAR := Vector2i(31, 20)
const TICKET := Vector2i(36, 3)  # below the cafeteria ticket machine
const PLACES := ["school", "fire", "clinic", "center"]

var _failed := false
var _step := ""
var _shots := ""
var _seed := 20261117


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
		if arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	await _frames(5)
	var gs := _a("GameState")
	(gs.get("rng") as RandomNumberGenerator).seed = _seed

	# ---- title -> character create -> home (alarm intro)
	_step = "title"
	change_scene_to_file("res://scenes/title/title.tscn")
	await _frames(10)
	_tap(Vector2(320, 180))
	await _frames(5)
	_check(current_scene.get("_started") == true, "title did not react to a tap")

	_step = "character create"
	_a("SceneRouter").goto("res://scenes/character_create/character_create.tscn")
	await _wait_router()
	var cc := current_scene
	(cc.get("_name_edit") as LineEdit).text = "테스트"
	cc.call("_change", "gender", 1)  # -> female defaults: long hair, skirt suit
	cc.call("_change", "hair_style", 1)  # -> ponytail
	cc.call("_change", "skin", -1)
	cc.call("_change", "outfit_style", 1)  # -> knit vest
	cc.call("_on_confirm")
	await _wait_router()
	_check(_map() == "home", "new game should start at home, got %s" % _map())
	var look: Dictionary = gs.call("get_look")
	_check(int(look["gender"]) == 1 and int(look["hair_style"]) == 4 and int(look["skin"]) == 3 			and int(look["outfit_style"]) == 2, "look not saved: %s" % look)

	_step = "home intro"
	await _until(func() -> bool: return _a("Dialogue").get("is_open") == true, "home intro never opened")
	await _shot("01_home_intro", 60)
	await _drain_dialogue()
	_check(gs.call("has_flag", "home_intro"), "home_intro flag missing")

	_step = "run"
	var walked := await _move_for("move_right", false, 20)
	var ran := await _move_for("move_right", true, 20)
	_check(walked > 10.0 and ran > walked * 1.5, "running not faster: walk %.1f px, run %.1f px" % [walked, ran])

	_step = "fridge"
	var bars := int(gs.call("item_count", "energybar"))
	await _walk_and_interact(Vector2i(15, 3), "up")
	await _drain_dialogue()
	_check(int(gs.call("item_count", "energybar")) == bars + 1, "fridge gave no energy bar")

	_step = "commute"
	await _walk_out(Vector2i(8, 6))
	_check(_map() == "office", "home door did not lead to the office")
	await _until(func() -> bool: return _a("Dialogue").get("is_open") == true, "office intro never opened")
	await _drain_dialogue()
	_check(gs.call("has_flag", "intro_done"), "intro_done flag missing")
	await _shot("02_lobby", 20)

	_step = "leave early"
	await _walk_out(Vector2i(11, 22), false)
	_check(_map() == "office", "office door let the player leave before work was done")

	# ---- tasks until the day ends (forced leave or 3 tasks + door)
	var day := int(gs.get("day"))
	for i in 4:
		if _failed or int(gs.get("day")) != day or bool(gs.get("day_over")):
			break
		if int(gs.get("tasks_done_today")) >= 3:
			_step = "leave after work"
			await _walk_out(Vector2i(11, 22))
			await _drain_dialogue()
			break
		await _one_task(i)

	if not _failed:
		_step = "evening"
		await _until(func() -> bool: return _map() == "home" and bool(gs.get("day_over")), "never got home in the evening")
		await _drain_dialogue()
		await _walk_out(Vector2i(8, 6), false)
		_check(_map() == "home", "could leave home after the day was over")

	if not _failed:
		_step = "sleep"
		await _walk_and_interact(Vector2i(2, 2), "left")
		await _drain_dialogue([0])
		await _wait_router()
		_check(int(gs.get("day")) == day + 1, "sleeping did not start the next day")
		_check(not bool(gs.get("day_over")), "day_over still set in the morning")

	if not _failed:
		_step = "day 2"
		await _walk_out(Vector2i(8, 6))
		await _drain_dialogue()
		_check(_map() == "office", "day 2 commute failed")
		if int(_a("Story").call("step")) == 4:
			var done := int(gs.get("tasks_completed"))
			await _walk_and_interact(LEADER, "up")
			await _drain_dialogue()
			_check(int(gs.get("tasks_completed")) == done + 1, "pending report failed on day 2")

	for place: String in PLACES:
		if _failed:
			break
		_step = "visit " + place
		await _visit(place)

	if not _failed:
		_step = "cafeteria"
		gs.set("fatigue", 60)
		gs.set("meals_today", 0)
		var money := int(gs.get("money"))
		await _walk_and_interact(TICKET, "up")
		await _drain_dialogue([0])  # 든든 국밥
		var dlg := _a("Dialogue")
		await _until(func() -> bool: return bool(dlg.get("overlay_open")), "meal window never opened")
		await _shot("12_meal_eating", 70)
		_press("interact")  # skip to the result
		await _shot("13_meal_result", 20)
		_press("interact")  # close
		await _until(func() -> bool: return not bool(dlg.get("overlay_open")), "meal window did not close")
		_check(int(gs.get("fatigue")) == 20, "meal did not recover 40 fatigue: %d" % int(gs.get("fatigue")))
		_check(int(gs.get("money")) == money - 8000, "meal not paid")
		_check(int(gs.get("meals_today")) == 1, "meal not counted")
		gs.set("meals_today", 2)
		await _walk_and_interact(TICKET, "up")
		await _drain_dialogue()
		_check(int(gs.get("money")) == money - 8000 and not bool(dlg.get("overlay_open")), "meal limit not applied")

	if not _failed:
		_step = "growth"
		gs.set("budget", 1000)
		_a("Story").call("open_panel", "growth")
		await _shot("10_growth", 60)
		await _drain_dialogue([0, 0, 3])  # truck -> upgrade -> close
		_check(int(gs.call("upgrade_level", "truck")) == 1, "truck upgrade not bought")
		_check(int(gs.get("budget")) == 880, "upgrade cost not paid")

	if not _failed:
		_step = "menu + items"
		gs.call("add_item", "gukbap")
		gs.set("fatigue", 0)
		gs.call("add_fatigue", 50)
		_press("cancel")
		await _until(func() -> bool: return _a("Dialogue").get("is_open") == true, "menu did not open")
		await _drain_dialogue([1, 0])  # 가방 -> first item
		_check(int(gs.get("fatigue")) < 50, "item from the bag did not reduce fatigue")

	if not _failed:
		_step = "save / load"
		gs.call("save_game")
		var budget := int(gs.get("budget"))
		gs.set("budget", 0)
		gs.set("map_id", "school")
		_check(gs.call("load_game"), "load_game failed")
		_check(int(gs.get("budget")) == budget, "budget not restored by load")
		_check(str(gs.get("map_id")) == "office", "map not restored by load")
		_check(int(gs.call("upgrade_level", "truck")) == 1, "upgrades not restored by load")

	print("SMOKE OK" if not _failed else "SMOKE FAILED at: " + _step)
	quit(1 if _failed else 0)


func _one_task(i: int) -> void:
	var gs := _a("GameState")
	var story := _a("Story")
	_step = "task %d: leader" % (i + 1)
	await _walk_and_interact(LEADER, "up")
	if i == 0:
		await _shot("03_leader", 60)
	await _drain_dialogue()
	_check(int(story.call("step")) == 1, "task not accepted")

	_step = "task %d: pc" % (i + 1)
	await _walk_and_interact(PC, "up")
	var dlg := _a("Dialogue")
	for k in 600:  # a sale notice may come before the monitor window
		if bool(dlg.get("overlay_open")):
			break
		if dlg.get("is_open"):
			_press("interact")
		await _frames(3)
	_check(bool(dlg.get("overlay_open")), "나라장터 window never opened")
	if i == 0:
		await _shot("04_pc_vendor", 30)
	_press("interact")  # 계약하기 -> confirm popup (first vendor)
	await _frames(5)
	if i == 0:
		await _shot("04b_pc_confirm", 10)
	_press("interact")  # confirm
	await _until(func() -> bool: return not bool(dlg.get("overlay_open")), "나라장터 window did not close")
	await _drain_dialogue()
	_check(int(story.call("step")) == 2, "vendor not chosen")
	_check(int((gs.get("task") as Dictionary)["vendor"]) == 0, "PC picked the wrong vendor")

	_step = "task %d: car" % (i + 1)
	await _walk_and_interact(CAR, "up")
	await _drain_dialogue()  # option 0 = 출발
	await _wait_router()
	_check(current_scene.has_method("_drive"), "drive scene not loaded")

	_step = "task %d: drive" % (i + 1)
	if i == 0:
		await _shot("05_drive", 60 * 8)
	await _until(func() -> bool: return current_scene != null and current_scene.get("map_size_px") != null \
			and not _a("SceneRouter").get("busy"), "drive never finished", 60 * 40)
	_check(int(story.call("step")) == 3, "not ARRIVED after drive")
	var t: Dictionary = gs.get("task")
	print("  task %d (#%d urgent=%s sale=%d) cargo=%d stars=%d fatigue=%d" % [
		i + 1, int(t["index"]), str(t.get("urgent", false)), int(t.get("discount", -1)), int(t["cargo"]),
		int(t.get("stars", 0)), int(gs.get("fatigue"))])

	_step = "task %d: inspection at %s" % [i + 1, _map()]
	if i == 0:
		await _shot("06_school", 10)
	await _walk_and_interact(_receiver_spot(), "up")
	if i == 0:
		for k in 5:
			_press("interact")
			await _frames(25)
		await _shot("07_inspection", 40)
	await _drain_dialogue()  # a help request, if any, is accepted (option 0)
	_check(int(story.call("step")) == 4, "not DELIVERED after inspection")

	_step = "task %d: return" % (i + 1)
	await _walk_out(_exit_spot())
	await _frames(5)
	if _a("Dialogue").get("is_open") or bool(gs.get("day_over")):
		# forced leave: Narumi talks, then the evening summary at home
		for k in 900:
			if _map() == "home" and _a("Dialogue").get("is_open"):
				break
			if _a("Dialogue").get("is_open"):
				_press("interact")
			await _frames(3)
		await _frames(20)
		_press("interact")
		await _shot("09_evening_summary", 60)
		await _drain_dialogue()
		await _wait_router()
		print("  forced leave after task %d (fatigue limit)" % (i + 1))
		return

	_step = "task %d: report" % (i + 1)
	var done := int(gs.get("tasks_completed"))
	await _walk_and_interact(LEADER, "up")
	await _drain_dialogue()
	if i == 0:
		await _shot("08_after_report", 8)
	_check(int(gs.get("tasks_completed")) == done + 1, "report did not complete the task")
	print("  task %d done: budget=%d rep=%d exp=%d money=%d clock=%s" % [i + 1, int(gs.get("budget")),
		int(gs.get("reputation")), int(gs.get("experience")), int(gs.get("money")), str(gs.call("clock_text"))])


# ---------------------------------------------------------------- helpers
func _shot(shot_name: String, wait_frames: int) -> void:
	if _shots == "":
		return
	await _frames(wait_frames)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join(shot_name + ".png"))


func _a(autoload_name: String) -> Node:
	return root.get_node("/root/" + autoload_name)


func _map() -> String:
	return str(current_scene.call("map_id")) if current_scene != null and current_scene.has_method("map_id") else ""


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, msg: String, limit: int = TIMEOUT_FRAMES) -> void:
	for i in limit:
		if _failed or cond.call():
			return
		await process_frame
	_fail(msg)


func _wait_router() -> void:
	await _frames(2)
	await _until(func() -> bool: return not _a("SceneRouter").get("busy"), "scene change stuck")
	await _frames(3)


## Advances every line until no dialogue is open for 30 frames. Choices take the
## next index from `picks`, then 0.
func _drain_dialogue(picks: Array = []) -> void:
	var queue := picks.duplicate()
	var quiet := 0
	var guard := 0
	while quiet < 30 and not _failed:
		guard += 1
		if guard > TIMEOUT_FRAMES:
			_fail("dialogue never closed")
			return
		var dlg := _a("Dialogue")
		if dlg.get("is_open"):
			quiet = 0
			var choices: Control = dlg.get("_choices")
			if choices.visible and choices.get_child_count() > 0:
				dlg.call("_on_choice", int(queue.pop_front()) if not queue.is_empty() else 0)
			else:
				_press("interact")
		elif not _a("SceneRouter").get("busy"):
			quiet += 1
		await _frames(2)


## Holds a move action (and "run") for some frames; returns the distance moved.
func _move_for(action: String, run: bool, frames: int) -> float:
	var p := current_scene.get("player") as Node2D
	var start := p.position
	if run:
		Input.action_press("run")
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	Input.action_release("run")
	await _frames(2)
	return p.position.distance_to(start)


func _walk_and_interact(cell: Vector2i, facing: String) -> void:
	var p := current_scene.get("player") as Node2D
	if p == null:
		_fail("no player in scene")
		return
	p.position = Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
	p.set("facing", facing)
	await _frames(3)
	if p.call("find_interactable") == null:
		_fail("nothing to interact with at %s facing %s" % [cell, facing])
		return
	_press("interact")
	await _until(func() -> bool: return _a("Dialogue").get("is_open") == true or _a("Dialogue").get("overlay_open") == true,
			"interaction opened no dialogue", 60)


## Where to stand to talk to this map's receiver (MapBase.npcs() "from", else the cell below).
func _receiver_spot() -> Vector2i:
	var dests: Dictionary = _a("Story").get("DESTINATIONS")
	var receiver := str((dests[_map()] as Dictionary)["receiver"])
	for entry: Dictionary in current_scene.call("npcs"):
		if str(entry["id"]) == receiver:
			return entry.get("from", (entry["cell"] as Vector2i) + Vector2i(0, 1))
	_fail("receiver %s not on map %s" % [receiver, _map()])
	return Vector2i.ZERO


## The cell just above this map's first exit (walk down from it to leave).
func _exit_spot() -> Vector2i:
	var r: Rect2i = (current_scene.call("exits") as Array)[0]["rect"]
	return Vector2i(r.position.x, r.position.y - 1)


## Jumps straight to a destination with a task in ARRIVED state, delivers, returns, reports.
func _visit(place: String) -> void:
	var gs := _a("GameState")
	var index := -1
	for k in TaskData.TASKS.size():
		if str((TaskData.TASKS[k] as Dictionary)["destination"]) == place:
			index = k
			break
	_check(index >= 0, "no task for %s" % place)
	gs.call("recover_fatigue", 100)  # keep a forced leave out of this check
	gs.call("set_task", {"index": index, "step": 3, "vendor": 1, "cargo": 95, "grade": "", "urgent": false,
			"discount": -1, "discount_rolled": true, "stars": 0})
	_a("SceneRouter").call("goto_map", place, "arrival")
	await _wait_router()
	_check(_map() == place, "could not open map %s" % place)
	await _drain_dialogue()
	await _shot("11_place_" + place, 20)
	await _walk_and_interact(_receiver_spot(), "up")
	await _drain_dialogue()
	_check(int(_a("Story").call("step")) == 4, "delivery at %s failed" % place)
	await _walk_out(_exit_spot())
	await _drain_dialogue()
	_check(_map() == "office", "%s exit did not lead to the office" % place)
	var done := int(gs.get("tasks_completed"))
	await _walk_and_interact(LEADER, "up")
	await _drain_dialogue()
	_check(int(gs.get("tasks_completed")) == done + 1, "report after %s failed" % place)


## Stands on `cell` and walks down into the exit below it. expect_change=false
## checks a blocked exit (only a toast, no scene change).
func _walk_out(cell: Vector2i, expect_change: bool = true) -> void:
	var p := current_scene.get("player") as Node2D
	p.position = Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
	Input.action_press("move_down")
	if expect_change:
		await _until(func() -> bool: return _a("SceneRouter").get("busy") == true, "exit never triggered", 120)
		Input.action_release("move_down")
		await _wait_router()
	else:
		await _frames(45)
		Input.action_release("move_down")
		await _frames(5)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _tap(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fail(msg)


func _fail(msg: String) -> void:
	if not _failed:
		push_error("SMOKE: [%s] %s" % [_step, msg])
	_failed = true
