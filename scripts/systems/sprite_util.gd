class_name SpriteUtil
## Builds SpriteFrames from sprite sheets so no .tres files are needed.
## Sheet layout is documented in tools/gen_placeholders.py.

const CHAR_FRAME := Vector2i(24, 32)
## Row of each direction in a character sheet.
const DIR_ROWS := {"down": 0, "up": 1, "side": 2}


## Creates "walk_<dir>" (looping, all columns) and "idle_<dir>" (column 0)
## for every direction in DIR_ROWS.
static func character_frames(tex: Texture2D, cols: int = 4, fps: float = 8.0) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for dir: String in DIR_ROWS:
		var row: int = DIR_ROWS[dir]
		var walk := "walk_" + dir
		var idle := "idle_" + dir
		sf.add_animation(walk)
		sf.set_animation_speed(walk, fps)
		sf.set_animation_loop(walk, true)
		for c in cols:
			sf.add_frame(walk, region(tex, Rect2(c * CHAR_FRAME.x, row * CHAR_FRAME.y, CHAR_FRAME.x, CHAR_FRAME.y)))
		sf.add_animation(idle)
		sf.set_animation_loop(idle, true)
		sf.add_frame(idle, region(tex, Rect2(0, row * CHAR_FRAME.y, CHAR_FRAME.x, CHAR_FRAME.y)))
	return sf


## Single-row sheet -> one looping "idle" animation (NPC placeholders).
static func idle_frames(tex: Texture2D, frame: Vector2i = CHAR_FRAME, fps: float = 2.0) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", fps)
	sf.set_animation_loop("idle", true)
	var count := maxi(1, int(tex.get_width() / float(frame.x)))
	for c in count:
		sf.add_frame("idle", region(tex, Rect2(c * frame.x, 0, frame.x, frame.y)))
	return sf


static func region(tex: Texture2D, rect: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = rect
	return at
