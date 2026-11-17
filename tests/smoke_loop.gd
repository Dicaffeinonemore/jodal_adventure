extends SceneTree
## Headless smoke test: plays the core loop through the real scenes, input
## actions and dialogue, and fails loudly if anything gets stuck.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/smoke_loop.gd
##
## Prints "SMOKE OK" at the end. Any SCRIPT ERROR in the output is a failure too.
## Deletes user://save.json before starting (the test saves on its own).

const TIMEOUT_FRAMES := 60 * 120

var _failed := false
var _step := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	await _frames(5)
	var gs := _a("GameState")
	var story := _a("Story")
	var router := _a("SceneRouter")

	# ---- title -> character create -> office (intro)
	_step = "title"
	change_scene_to_file("res://scenes/title/title.tscn")
	await _frames(10)
	_tap(Vector2(320, 180))
	await _frames(5)
	_check(current_scene.get("_started") == true, "title did not react to a tap")

	_step = "character create"
	router.goto("res://scenes/character_create/character_create.tscn")
	await _wait_router()
	var cc := current_scene
	var name_edit: LineEdit = cc.get("_name_edit")
	name_edit.text = "테스트"
	cc.call("_change", "hair_style", 1)
	cc.call("_change", "hair_color", -1)
	cc.call("_on_confirm")
	await _wait_router()
	_check(str(gs.get("player_name")) == "테스트", "name not saved")
	_check(current_scene.get("map_size_px") != null, "office map not loaded")

	_step = "intro"
	await _until(func() -> bool: return _a("Dialogue").get("is_open") == true, "intro dialogue never opened")
	await _drain_dialogue()
	_check(gs.call("has_flag", "intro_done"), "intro_done flag missing")

	# ---- three tasks; the third one should trigger a forced leave on the way back
	for i in 3:
		await _one_task(i)
		if _failed:
			break

	if not _failed:
		_step = "end of day"
		# Task 3 hit 100 fatigue on return -> forced leave -> day 2, report pending.
		_check(int(gs.get("day")) == 2, "expected forced leave to start day 2, day=%d" % int(gs.get("day")))
		_check(int(story.call("step")) == 4, "task 3 report should still be pending")
		await _walk_and_interact(Vector2i(13, 5), "up")
		await _drain_dialogue()
		_check(int(gs.get("tasks_completed")) == 3, "task 3 report failed")

	if not _failed:
		_step = "menu + items"
		gs.call("add_item", "gukbap")
		gs.call("add_fatigue", 50)
		_press("cancel")
		await _until(func() -> bool: return _a("Dialogue").get("is_open") == true, "menu did not open")
		await _drain_dialogue()  # picks option 0 = 아이템, then option 0 = first item
		_check(int(gs.get("fatigue")) < 50, "item from menu did not reduce fatigue")
		gs.call("add_item", "coffee")
		_press("quick_item")
		await _frames(3)

	if not _failed:
		_step = "save / load"
		gs.call("save_game")
		var budget := int(gs.get("budget"))
		gs.set("budget", 0)
		_check(gs.call("load_game"), "load_game failed")
		_check(int(gs.get("budget")) == budget, "budget not restored by load")

	if not _failed:
		_step = "day end via team leader"
		gs.set("tasks_done_today", 3)
		var day := int(gs.get("day"))
		await _walk_and_interact(Vector2i(13, 5), "up")
		await _drain_dialogue()
		await _wait_router()
		_check(int(gs.get("day")) == day + 1, "leader did not end the day")

	print("SMOKE OK" if not _failed else "SMOKE FAILED at: " + _step)
	quit(1 if _failed else 0)


func _one_task(i: int) -> void:
	var gs := _a("GameState")
	var story := _a("Story")
	_step = "task %d: leader" % (i + 1)
	await _walk_and_interact(Vector2i(13, 5), "up")
	await _drain_dialogue()
	_check(int(story.call("step")) == 1, "task not accepted")

	_step = "task %d: pc" % (i + 1)
	await _walk_and_interact(Vector2i(9, 10), "up")
	await _drain_dialogue()  # option 0 = best vendor
	_check(int(story.call("step")) == 2, "vendor not chosen")

	_step = "task %d: car" % (i + 1)
	await _walk_and_interact(Vector2i(40, 22), "up")
	await _drain_dialogue()  # option 0 = 출발
	await _wait_router()
	_check(current_scene.has_method("_drive"), "drive scene not loaded")

	_step = "task %d: drive" % (i + 1)
	await _until(func() -> bool: return current_scene != null and current_scene.get("map_size_px") != null \
			and not _a("SceneRouter").get("busy"),
			"drive never finished", 60 * 70)
	_check(int(story.call("step")) == 3, "not ARRIVED after drive")
	print("  task %d cargo=%d fatigue=%d" % [i + 1, int(gs.get("task")["cargo"]), int(gs.get("fatigue"))])

	_step = "task %d: inspection" % (i + 1)
	await _walk_and_interact(Vector2i(6, 6), "up")
	await _drain_dialogue()
	_check(int(story.call("step")) == 4, "not DELIVERED after inspection")

	_step = "task %d: return" % (i + 1)
	(current_scene.get("player") as Node2D).position = Vector2(15 * 16 + 8, 18 * 16 + 8)
	Input.action_press("move_down")
	await _until(func() -> bool: return _a("SceneRouter").get("busy") == true, "exit never triggered", 120)
	Input.action_release("move_down")
	await _wait_router()
	await _frames(5)
	if int(gs.get("fatigue")) >= 100 or _a("Dialogue").get("is_open"):
		# forced leave: narumi talks, then the day restarts at the entrance
		await _drain_dialogue()
		await _wait_router()
		print("  forced leave -> day %d" % int(gs.get("day")))
		return

	_step = "task %d: report" % (i + 1)
	var done := int(gs.get("tasks_completed"))
	await _walk_and_interact(Vector2i(13, 5), "up")
	await _drain_dialogue()
	_check(int(gs.get("tasks_completed")) == done + 1, "report did not complete the task")
	print("  task %d done: budget=%d rep=%d exp=%d" % [i + 1, int(gs.get("budget")), int(gs.get("reputation")), int(gs.get("experience"))])


# ---------------------------------------------------------------- helpers
func _a(autoload_name: String) -> Node:
	return root.get_node("/root/" + autoload_name)


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


## Advances every line and picks choice 0 until no dialogue is open for 30 frames.
func _drain_dialogue() -> void:
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
				dlg.call("_on_choice", 0)
			else:
				_press("interact")
		elif not _a("SceneRouter").get("busy"):
			quiet += 1
		await _frames(2)


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
	await _until(func() -> bool: return _a("Dialogue").get("is_open") == true, "interaction opened no dialogue", 60)


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
