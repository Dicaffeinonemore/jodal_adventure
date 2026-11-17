extends Node
## Music and sound effects (files from tools/gen_audio.py in assets/audio/).
##     Sound.play_bgm("town")      # crossfades; same id again does nothing
##     Sound.play("coin")          # one-shot from a small player pool
## Maps pick their music through MAP_BGM (MapBase calls play_bgm). Buttons play
## "confirm" automatically unless they carry the meta "sfx_off" (windows that
## make their own sounds). Reward popups (GameState.popup) pick a sound by text/color.
##
## Web: browsers start audio only after a user gesture, so the title screen starts
## the music after the first tap (unlocked = true from then on).
## The sound setting (all / effects only / off) lives in user://settings.json, not the save.

enum Mode { ALL, SFX_ONLY, OFF }

const DIR := "res://assets/audio/"
const SETTINGS_PATH := "user://settings.json"
const MUSIC_DB := -9.0
const SFX_DB := -5.0
const FADE := 0.6
const SILENT_DB := -40.0
const REPEAT_MS := 60  # the same effect is not restarted faster than this
const POOL := 8
const MAP_BGM := {
	"home": "home", "office": "town", "school": "town", "fire": "town", "clinic": "town", "center": "town",
}

var mode := Mode.ALL
var unlocked := false
## Headless runs use the Dummy driver, which never mixes: playbacks would pile up
## and leak at exit. Track the music id (tests read it) but play nothing.
var _silent := false
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _bgm := ""
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _last: Dictionary = {}  # effect id -> msec


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = AudioServer.get_driver_name() == "Dummy"
	_ensure_bus("Music", MUSIC_DB)
	_ensure_bus("SFX", SFX_DB)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		add_child(m)
		_music.append(m)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_load_settings()
	_apply_mode()
	GameState.popup.connect(_on_popup)
	get_tree().node_added.connect(_on_node_added)


## Stops everything and lets go of the streams. The headless test calls this a few
## frames before quitting, or Godot reports the playing streams as leaked.
func stop_all() -> void:
	_bgm = ""
	for p: AudioStreamPlayer in _music + _pool:
		p.stop()
		p.stream = null
	_cache.clear()


func _exit_tree() -> void:
	stop_all()


# ---------------------------------------------------------------- music
func play_bgm(id: String) -> void:
	if id == _bgm:
		return
	_bgm = id
	if _silent:
		return
	var old := _music[_active]
	_active = 1 - _active
	var cur := _music[_active]
	if old.playing:
		var out := create_tween()
		out.tween_property(old, "volume_db", SILENT_DB, FADE)
		out.tween_callback(old.stop)
	var stream := _stream("bgm_" + id)
	if stream == null:
		return
	cur.stream = stream
	cur.volume_db = SILENT_DB
	cur.play()
	create_tween().tween_property(cur, "volume_db", 0.0, FADE)


func bgm_for_map(map_id: String) -> String:
	return str(MAP_BGM.get(map_id, "town"))


func current_bgm() -> String:
	return _bgm


# ---------------------------------------------------------------- effects
func play(id: String, pitch_jitter: float = 0.0) -> void:
	if mode == Mode.OFF or _silent:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -100000)) < REPEAT_MS:
		return
	_last[id] = now
	var stream := _stream("sfx_" + id)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


# ---------------------------------------------------------------- settings
func set_mode(m: Mode) -> void:
	mode = m
	_apply_mode()
	_save_settings()


func _apply_mode() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), mode != Mode.ALL)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), mode == Mode.OFF)


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		var m: int = int((parsed as Dictionary).get("sound_mode", 0))
		mode = clampi(m, 0, Mode.OFF) as Mode


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"sound_mode": int(mode)}))


# ---------------------------------------------------------------- hooks
func _on_popup(text: String, color: Color) -> void:
	if text.begins_with("승진") or text.contains(" Lv"):
		play("levelup")
	elif text.begins_with("검수"):
		play("jingle_bad" if color == UiTheme.COLOR_BAD else "jingle_good")
	elif color == UiTheme.COLOR_GOOD:
		play("coin")
	elif color == UiTheme.COLOR_BAD:
		play("bad")
	else:
		play("pop")


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("sfx_off"):
		(node as BaseButton).pressed.connect(play.bind("confirm", 0.0))


func _ensure_bus(bus_name: String, db: float) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, db)


func _stream(file: String) -> AudioStream:
	if not _cache.has(file):
		var path := DIR + file + ".wav"
		_cache[file] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _cache[file]
