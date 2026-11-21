extends SceneTree
## Plays a scripted first day at a watchable pace for the 1-minute trailer, with
## captions on top. Recorded with Godot's Movie Maker; tools/make_trailer.py runs it
## and cuts the marked segments together. Not a test: nothing is checked.
##
##   godot --path . --fixed-fps 30 --write-movie <dir>/raw.avi \
##         --script res://tests/trailer_rec.gd -- --markers=<dir>/markers.txt
##
## Each segment prints "SEG <name> <first frame> <last frame>" (process frames = movie frames) into the
## markers file. Everything between segments (loading, skipped lines) is cut out.
## Deletes user://save.json (a new game). Music is muted; the editor adds it back.

const LEADER := Vector2i(13, 4)
const PC := Vector2i(13, 7)
const CAR := Vector2i(31, 20)
const RACE_SCRIPT := "res://scripts/minigames/race_game.gd"
const QC_SCRIPT := "res://scripts/minigames/qc_game.gd"
const FPS := 30
const HOLD := 32  # frames a fully typed line stays before the next one

var _markers: Array[String] = []
var _markers_path := ""
var _seg_name := ""
var _seg_start := 0
var _cap_layer: CanvasLayer
var _cap_panel: PanelContainer
var _cap_label: Label
var _cap_tween: Tween


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--markers="):
			_markers_path = arg.trim_prefix("--markers=")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	await _frames(3)
	var gs := _a("GameState")
	(gs.get("rng") as RandomNumberGenerator).seed = 20261121
	var snd := _a("Sound")
	snd.set("_silent", false)  # Movie Maker forces the Dummy driver; it still records what plays
	snd.set("music_volume", 0)  # the editor lays one continuous track over the cuts
	load(RACE_SCRIPT).set("autopilot", true)
	load(QC_SCRIPT).set("autoplay", true)
	_build_caption()

	# ---- title
	change_scene_to_file("res://scenes/title/title.tscn")
	await _frames(20)
	_seg("title")
	await _frames(60)
	_tap(Vector2(320, 180))
	await _frames(45)
	_end()

	# ---- 출입증 발급
	_a("SceneRouter").call("goto", "res://scenes/character_create/character_create.tscn")
	await _wait_router()
	var cc := current_scene
	(cc.get("_name_edit") as LineEdit).text = "나신입"
	_seg("create")
	_caption("출입증을 만들고 조달청 신입으로 첫 출근!")
	for change: Array in [["hair_color", 1], ["outfit_color", 1], ["gender", 1], ["hair_style", 1], ["outfit_color", 1]]:
		await _frames(16)
		cc.call("_change", change[0], change[1])
	await _frames(14)
	_caption_off()
	_end()
	cc.call("_on_confirm")
	await _wait_router()

	# ---- home: alarm intro
	await _until_dialogue()
	_seg("home")
	_caption("아침 7시 30분, 신입 주무관의 하루가 시작돼요")
	await _slow_lines(2)
	_caption_off()
	_end()
	await _fast_drain()
	await _walk_out(Vector2i(8, 6))

	# ---- office lobby: 달이 intro
	await _until_dialogue()
	_seg("lobby")
	_caption("정부청사에서 나르미·달이와 함께")
	await _slow_lines(2)
	_caption_off()
	_end()
	await _fast_drain()

	# ---- team leader: the request
	var p := current_scene.get("player") as Node2D
	p.position = _cell(LEADER + Vector2i(4, 0))  # row 4 is open floor up to the leader's desk
	await _frames(4)
	_seg("leader")
	_caption("수요기관의 조달 요청을 접수하고")
	Input.action_press("move_left")
	await _until(func() -> bool: return p.position.x <= _cell(LEADER).x, 120)
	Input.action_release("move_left")
	p.position = _cell(LEADER)
	p.set("facing", "up")
	await _frames(3)
	_press("interact")
	await _until_dialogue()
	await _slow_lines(2)
	_caption_off()
	_end()
	await _fast_drain()

	# ---- 나라장터 PC
	await _interact_at(PC, "up")
	var dlg := _a("Dialogue")
	for k in 600:  # a sale notice may come before the monitor window
		if bool(dlg.get("overlay_open")):
			break
		if dlg.get("is_open"):
			_press("interact")
		await _frames(3)
	await _frames(12)
	_seg("pc")
	_caption("나라장터에서 기준을 넘는 가장 싼 업체를 골라요")
	await _frames(45)
	_press("move_down")  # 바른공방: the cheapest one above the standard (알뜰책상 is below it)
	await _frames(30)
	_press("interact")  # 계약하기
	await _frames(36)
	_press("interact")  # confirm
	await _frames(20)
	_caption_off()
	_end()
	# "…와 계약했어요" first, then the vendor tip with its picture (나라장터, 적격심사).
	var pic_root: Control = dlg.get("_pic_root")
	for k in 600:
		if dlg.get("is_open") and pic_root.visible:
			break
		if dlg.get("is_open") and not bool(dlg.get("_typing")):
			await _frames(6)
			if not pic_root.visible:
				_press("interact")
		await _frames(2)
	await _frames(8)
	_seg("tip")
	await _slow_lines(2, 30)
	_end()
	await _fast_drain()

	# ---- quality inspection
	await _walk_into(Vector2i(1, 16), "move_left")
	await _interact_at(Vector2i(8, 4), "up")
	var shown := false
	for k in 4000:
		if bool((gs.get("task") as Dictionary).get("qc_done", false)) and not dlg.get("overlay_open") and not dlg.get("is_open"):
			break
		if _qc_running():
			if not shown:
				shown = true
				await _frames(20)
				_seg("qc")
				_caption("품질 검사: 흠집·얼룩·금 간 불량품을 골라내요")
				await _frames(100)
				_caption_off()
				await _frames(50)
				_end()
		elif dlg.get("is_open"):
			var ch: Control = dlg.get("_choices")
			if ch.visible and ch.get_child_count() > 0:
				dlg.call("_on_choice", 0)
			else:
				_press("interact")
		elif dlg.get("overlay_open"):
			_press("interact")
		await _frames(2)
	await _fast_drain()
	await _walk_out(Vector2i(8, 6))

	# ---- delivery drive
	await _interact_at(CAR, "up")
	await _fast_drain()
	await _wait_router()
	for k in 3000:  # tutorial pages, then the countdown
		if int(current_scene.get("_state")) == 1:
			break
		if _tut_running():
			_press("interact")
		await _frames(2)
	await _frames(45)
	_seg("drive")
	_caption("납품 운전: 차선 변경·점프·터보로 안전하게!")
	await _frames(100)
	_caption_off()
	await _frames(200)
	_end()
	await _until(func() -> bool: return current_scene != null and current_scene.get("map_size_px") != null \
			and not _a("SceneRouter").get("busy"), 60 * 90)
	await _frames(5)

	# ---- arrival + inspection at the school
	await _fast_drain()
	_seg("arrive")
	_caption("수요기관에 도착하면 담당자가 검수해요")
	p = current_scene.get("player") as Node2D
	Input.action_press("move_up")
	await _frames(40)
	Input.action_release("move_up")
	_end()
	await _interact_at(_receiver_spot(), "up")
	_seg("inspect")
	await _slow_lines(3, 28)
	_caption_off()
	_end()
	await _fast_drain()
	await _walk_out(_exit_spot())
	await _fast_drain()

	# ---- report
	await _interact_at(LEADER, "up")
	_seg("report")
	_caption("보고하면 아낀 예산·평판·경험치를 받아요")
	await _slow_lines(3, 26)
	await _frames(10)
	_caption_off()
	_end()
	await _fast_drain()

	# ---- other demand agencies (a quick montage)
	_caption("소방서·병원·경찰서… 수요기관 7곳, 수습 업무 15건")
	for place: String in ["fire", "hospital", "police"]:
		var index := -1
		for k in TaskData.TASKS.size():
			if str((TaskData.TASKS[k] as Dictionary)["destination"]) == place:
				index = k
				break
		gs.call("recover_fatigue", 100)
		gs.call("set_task", {"index": index, "step": 3, "vendor": 1, "cargo": 95, "grade": "", "urgent": false,
				"discount": -1, "discount_rolled": true, "stars": 0})
		_a("SceneRouter").call("goto_map", place, "arrival")
		await _wait_router()
		await _fast_drain()
		_seg("place_" + place)
		Input.action_press("move_up")
		await _frames(40)
		Input.action_release("move_up")
		_end()
	_caption_off()

	# ---- evening at home
	_a("Story").call("_go_home_evening", false)
	await _until_dialogue(400)
	_seg("evening")
	_caption("퇴근하면 하루 정산, 내일도 출근!")
	await _slow_lines(2)
	_caption_off()
	_end()

	# ---- end card
	_seg("end")
	await _end_card()
	_end()

	_save_markers()
	_a("Sound").call("stop_all")
	await _frames(5)
	quit()


# ---------------------------------------------------------------- segments
func _seg(seg_name: String) -> void:
	_seg_name = seg_name
	_seg_start = Engine.get_process_frames()


func _end() -> void:
	var line := "SEG %s %d %d" % [_seg_name, _seg_start, Engine.get_process_frames()]
	print(line)
	_markers.append(line)
	_save_markers()


func _save_markers() -> void:
	if _markers_path == "":
		return
	var f := FileAccess.open(_markers_path, FileAccess.WRITE)
	f.store_string("\n".join(_markers) + "\n")
	f.close()


# ---------------------------------------------------------------- captions
func _build_caption() -> void:
	_cap_layer = CanvasLayer.new()
	_cap_layer.layer = 120
	root.add_child(_cap_layer)
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap_layer.add_child(box)
	_cap_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.2, 0.88)
	sb.border_color = Color("ffd866")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	_cap_panel.add_theme_stylebox_override("panel", sb)
	_cap_panel.anchor_left = 0.5
	_cap_panel.anchor_right = 0.5
	_cap_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cap_panel.offset_top = 52
	_cap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_cap_panel)
	_cap_label = _a("UiTheme").call("make_label", "", 16, Color("fff6dc"), true)
	_cap_label.add_theme_color_override("font_outline_color", Color("1b1530"))
	_cap_label.add_theme_constant_override("outline_size", 4)
	_cap_panel.add_child(_cap_label)
	_cap_panel.modulate.a = 0.0


func _caption(text: String) -> void:
	_cap_label.text = text
	_cap_panel.reset_size()
	_cap_panel.offset_left = -_cap_panel.size.x / 2.0
	_cap_panel.offset_right = _cap_panel.size.x / 2.0
	_fade_caption(1.0)


func _caption_off() -> void:
	_fade_caption(0.0)


func _fade_caption(to: float) -> void:
	if _cap_tween != null:
		_cap_tween.kill()
	_cap_tween = _cap_panel.create_tween()
	_cap_tween.tween_property(_cap_panel, "modulate:a", to, 0.25)


func _end_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 121
	root.add_child(layer)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.modulate.a = 0.0
	layer.add_child(holder)
	var art := TextureRect.new()
	art.texture = load("res://assets/title/opening.png") as Texture2D
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	holder.add_child(art)
	var band := ColorRect.new()
	band.color = Color(0.06, 0.08, 0.16, 0.82)
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.anchor_right = 1.0
	band.offset_top = -64
	holder.add_child(band)
	var lines := VBoxContainer.new()
	lines.anchor_top = 1.0
	lines.anchor_bottom = 1.0
	lines.anchor_right = 1.0
	lines.offset_top = -60
	lines.offset_bottom = -6
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_child(lines)
	for spec: Array in [["PC · WEB 브라우저에서 설치 없이 바로 플레이", 20, Color("ffd866")],
			["2026 조달청 AI 게임·콘텐츠 공모전 출품작", 13, Color("fff6dc")]]:
		var l: Label = _a("UiTheme").call("make_label", spec[0], spec[1], spec[2], true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", Color("1b1530"))
		l.add_theme_constant_override("outline_size", 4)
		lines.add_child(l)
	holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.5)
	await _frames(FPS * 5)


# ---------------------------------------------------------------- pacing
## Shows `count` lines at reading pace (each fully typed, then HOLD frames), choosing
## option 0 when a choice comes up; windows (help scene, results) get a moment each.
func _slow_lines(count: int, hold: int = HOLD) -> void:
	var dlg := _a("Dialogue")
	var shown := 0
	var guard := 0
	while shown < count and guard < FPS * 30:
		guard += 1
		if dlg.get("is_open"):
			if bool(dlg.get("_typing")):
				await _frames(1)
				continue
			await _frames(hold)
			var ch: Control = dlg.get("_choices")
			if ch.visible and ch.get_child_count() > 0:
				dlg.call("_on_choice", 0)
			else:
				_press("interact")
			shown += 1
			await _frames(3)
		elif dlg.get("overlay_open"):
			await _frames(hold)
			_press("interact")
			shown += 1
		else:
			await _frames(1)


## Skips every remaining line and window quickly (between segments, so it is cut).
func _fast_drain() -> void:
	var quiet := 0
	var guard := 0
	while quiet < 20 and guard < FPS * 120:
		guard += 1
		var dlg := _a("Dialogue")
		if dlg.get("is_open"):
			quiet = 0
			var choices: Control = dlg.get("_choices")
			if choices.visible and choices.get_child_count() > 0:
				dlg.call("_on_choice", 0)
			else:
				_press("interact")
		elif dlg.get("overlay_open"):
			quiet = 0
			if not _qc_running():
				_press("interact")
		elif not _a("SceneRouter").get("busy"):
			quiet += 1
		await _frames(2)


func _until_dialogue(limit: int = 300) -> void:
	await _until(func() -> bool: return _a("Dialogue").get("is_open") == true, limit)


func _until(cond: Callable, limit: int, quiet_if_fail: bool = false) -> void:
	for i in limit:
		if cond.call():
			return
		await process_frame
	if not quiet_if_fail:
		push_warning("trailer: wait timed out (segment %s)" % _seg_name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_router() -> void:
	await _frames(2)
	await _until(func() -> bool: return not _a("SceneRouter").get("busy"), 600)
	await _frames(3)


# ---------------------------------------------------------------- moving around
func _cell(c: Vector2i) -> Vector2:
	return Vector2(c.x * 16 + 8, c.y * 16 + 8)


func _interact_at(cell: Vector2i, facing: String) -> void:
	var p := current_scene.get("player") as Node2D
	p.position = _cell(cell)
	p.set("facing", facing)
	await _frames(3)
	_press("interact")
	await _until(func() -> bool: return _a("Dialogue").get("is_open") == true or _a("Dialogue").get("overlay_open") == true, 60)


func _walk_into(cell: Vector2i, action: String) -> void:
	var p := current_scene.get("player") as Node2D
	p.position = _cell(cell)
	Input.action_press(action)
	await _until(func() -> bool: return _a("SceneRouter").get("busy") == true, 120)
	Input.action_release(action)
	await _wait_router()


func _walk_out(cell: Vector2i) -> void:
	await _walk_into(cell, "move_down")


func _receiver_spot() -> Vector2i:
	var dests: Dictionary = _a("Story").get("DESTINATIONS")
	var map_id := str(current_scene.call("map_id"))
	var receiver := str((dests[map_id] as Dictionary)["receiver"])
	for entry: Dictionary in current_scene.call("npcs"):
		if str(entry["id"]) == receiver:
			return entry.get("from", (entry["cell"] as Vector2i) + Vector2i(0, 1))
	return Vector2i.ZERO


func _exit_spot() -> Vector2i:
	var r: Rect2i = (current_scene.call("exits") as Array)[0]["rect"]
	return Vector2i(r.position.x, r.position.y - 1)


# ---------------------------------------------------------------- helpers
func _a(autoload_name: String) -> Node:
	return root.get_node("/root/" + autoload_name)


func _tut_running() -> bool:
	for n: Node in root.get_children():
		var sc: Script = n.get_script()
		if sc != null and sc.resource_path == "res://scripts/ui/tutorial_pages.gd":
			return true
	return false


func _qc_running() -> bool:
	var qc_script := load(QC_SCRIPT)
	for n: Node in root.get_children():
		if n.get_script() == qc_script:
			return true
	return false


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
