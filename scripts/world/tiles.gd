class_name Tiles
## Placeholder tileset built in code from assets/sprites/placeholder/tiles.png
## (one row of 16x16 tiles) and the ASCII legend used by map layouts.
##
## Swapping in real art: keep the same tile order in tiles.png, or replace the
## ground layer with a TileMapLayer painted in the editor (see CLAUDE.md).

const TILE := 16
const TEXTURE_PATH := "res://assets/sprites/placeholder/tiles.png"

## Atlas column of each tile. Order must match TILE_COLORS in tools/gen_placeholders.py.
## Order must match TILES in tools/gen_placeholders.py (append only).
enum {
	FLOOR, WALL, DESK, CARPET, PLANT, COUNTER, ASPHALT, PARKING_LINE, GRASS,
	ENTRANCE, WINDOW_WALL, WOOD_FLOOR, PC_DESK, VENDING, BOARD, MIRROR, TICKET_MACHINE,
	BOOKSHELF, WATER_COOLER, SOFA, RUG, PRINTER, TABLE, BED_HEAD, BED_FOOT,
	WARDROBE, HOME_FLOOR, HOME_WALL, FRIDGE, DOOR_MAT,
}

const SOLID := [
	WALL, DESK, PLANT, COUNTER, WINDOW_WALL, PC_DESK, VENDING, BOARD, MIRROR, TICKET_MACHINE,
	BOOKSHELF, WATER_COOLER, SOFA, PRINTER, TABLE, BED_HEAD, BED_FOOT, WARDROBE, HOME_WALL, FRIDGE,
]

## ASCII character -> tile.
const LEGEND := {
	".": FLOOR, "#": WALL, "D": DESK, ",": CARPET, "P": PLANT, "=": COUNTER,
	"a": ASPHALT, "|": PARKING_LINE, "g": GRASS, "E": ENTRANCE, "W": WINDOW_WALL,
	"w": WOOD_FLOOR, "C": PC_DESK, "V": VENDING, "B": BOARD, "M": MIRROR, "K": TICKET_MACHINE,
	"S": BOOKSHELF, "O": WATER_COOLER, "F": SOFA, "r": RUG, "R": PRINTER, "T": TABLE,
	"b": BED_HEAD, "n": BED_FOOT, "Z": WARDROBE, "h": HOME_FLOOR, "H": HOME_WALL, "f": FRIDGE,
	"m": DOOR_MAT,
}

## Characters that also spawn an interactable object with this id.
const OBJECT_CHARS := {
	"C": "narajangteo_pc",
	"V": "vending",
	"K": "ticket_machine",
	"B": "notice_board",
	"M": "mirror",
	"b": "bed",
	"Z": "wardrobe",
	"f": "fridge",
	"O": "water_cooler",
}

static var _tileset: TileSet


static func get_tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = load(TEXTURE_PATH) as Texture2D
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var count := int(src.texture.get_width() / float(TILE))
	var h := TILE / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for i in count:
		var coords := Vector2i(i, 0)
		src.create_tile(coords)
		if i in SOLID:
			var data := src.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	_tileset = ts
	return ts


static func tile_for(ch: String) -> int:
	return int(LEGEND.get(ch, FLOOR))


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)
