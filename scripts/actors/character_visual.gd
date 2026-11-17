class_name CharacterVisual
extends Node2D
## Layered player sprite: base (skin, legs) + outfit + hair. Outfit and hair are
## drawn in light gray and tinted with self_modulate, so one sheet covers every
## color option. The node's origin is at the character's feet (for y-sorting).

const SHEET_DIR := "res://assets/sprites/placeholder/"
const FEET_OFFSET := Vector2(0, -12)

var _layers: Array[AnimatedSprite2D] = []
var _base: AnimatedSprite2D
var _outfit: AnimatedSprite2D
var _hair: AnimatedSprite2D
var _anim := ""
var _flip := false


func _init() -> void:
	_base = _make_layer("player_base.png")
	_outfit = _make_layer("player_outfit.png")
	_hair = _make_layer("player_hair_0.png")


func set_look(style: int, hair_color_index: int, outfit_color_index: int) -> void:
	var hair_tex := load(SHEET_DIR + "player_hair_%d.png" % clampi(style, 0, GameState.HAIR_STYLE_COUNT - 1)) as Texture2D
	_hair.sprite_frames = SpriteUtil.character_frames(hair_tex)
	_hair.self_modulate = GameState.HAIR_COLORS[clampi(hair_color_index, 0, GameState.HAIR_COLORS.size() - 1)]
	_outfit.self_modulate = GameState.OUTFIT_COLORS[clampi(outfit_color_index, 0, GameState.OUTFIT_COLORS.size() - 1)]
	var keep := _anim
	_anim = ""
	play(keep if keep != "" else "idle_down", _flip)


## dir: "down" | "up" | "left" | "right"
func face(dir: String, moving: bool) -> void:
	var sheet_dir := "side" if dir == "left" or dir == "right" else dir
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
	s.sprite_frames = SpriteUtil.character_frames(load(SHEET_DIR + file) as Texture2D)
	add_child(s)
	_layers.append(s)
	return s
