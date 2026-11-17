class_name CharacterVisual
extends Node2D
## Layered player sprite, bottom to top:
##   skin (head, hands)       white/gray, tinted with the skin tone
##   outfit_<n>_base          shirt, tie, pants, shoes, outline (as drawn)
##   outfit_<n>               jacket / vest / jumper / skirt, tinted with the outfit color
##   face_<gender>            eyes, blush, mouth (as drawn)
##   hair_<n>                 tinted with the hair color
## One sheet per option covers every color (self_modulate). The node's origin is at the
## character's feet (for y-sorting). Sheets come from tools/gen_placeholders.py.

const SHEET_DIR := "res://assets/sprites/placeholder/"
const FEET_OFFSET := Vector2(0, -12)
const RUN_ANIM_SPEED := 1.7

static var _frames_cache: Dictionary = {}  # file -> SpriteFrames

var _layers: Array[AnimatedSprite2D] = []
var _skin: AnimatedSprite2D
var _outfit_base: AnimatedSprite2D
var _outfit: AnimatedSprite2D
var _face: AnimatedSprite2D
var _hair: AnimatedSprite2D
var _anim := ""
var _flip := false


func _init() -> void:
	_skin = _make_layer("player_skin.png")
	_outfit_base = _make_layer("player_outfit_0_base.png")
	_outfit = _make_layer("player_outfit_0.png")
	_face = _make_layer("player_face_0.png")
	_hair = _make_layer("player_hair_0.png")


## look: GameState.get_look() shape. Out-of-range values wrap around.
func set_look(look: Dictionary) -> void:
	var v := {}
	for key in GameState.LOOK_KEYS:
		v[key] = posmod(int(look.get(key, 0)), GameState.look_option_count(key))
	_skin.sprite_frames = _frames("player_skin.png")
	_outfit_base.sprite_frames = _frames("player_outfit_%d_base.png" % v["outfit_style"])
	_outfit.sprite_frames = _frames("player_outfit_%d.png" % v["outfit_style"])
	_face.sprite_frames = _frames("player_face_%d.png" % v["gender"])
	_hair.sprite_frames = _frames("player_hair_%d.png" % v["hair_style"])
	_skin.self_modulate = GameState.SKIN_TONES[v["skin"]]
	_outfit.self_modulate = GameState.OUTFIT_COLORS[v["outfit_color"]]
	_hair.self_modulate = GameState.HAIR_COLORS[v["hair_color"]]
	var keep := _anim
	_anim = ""
	play(keep if keep != "" else "idle_down", _flip)


## dir: "down" | "up" | "left" | "right". Running plays the walk cycle faster.
func face(dir: String, moving: bool, running: bool = false) -> void:
	var sheet_dir := "side" if dir == "left" or dir == "right" else dir
	var speed := RUN_ANIM_SPEED if moving and running else 1.0
	for layer in _layers:
		layer.speed_scale = speed
	play(("walk_" if moving else "idle_") + sheet_dir, dir == "left")


func play(anim: String, flip: bool) -> void:
	if anim == _anim and flip == _flip:
		return
	_anim = anim
	_flip = flip
	for layer in _layers:
		layer.flip_h = flip
		if layer.sprite_frames != null and layer.sprite_frames.has_animation(anim):
			layer.play(anim)
			layer.frame = 0


func _make_layer(file: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.offset = FEET_OFFSET
	s.sprite_frames = _frames(file)
	add_child(s)
	_layers.append(s)
	return s


static func _frames(file: String) -> SpriteFrames:
	if not _frames_cache.has(file):
		_frames_cache[file] = SpriteUtil.character_frames(load(SHEET_DIR + file) as Texture2D)
	return _frames_cache[file]
