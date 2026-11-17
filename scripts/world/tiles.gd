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
	GRASS_FLOWER, PATH, HEDGE, FACADE_SCHOOL, FACADE_FIRE, GARAGE_DOOR, FACADE_CLINIC,
	FACADE_CENTER, GLASS_DOOR, TILE_WHITE, HOSPITAL_BED, LOCKER, MED_CABINET, GARAGE_FLOOR,
	KIOSK, FLOWER_BED, CHALKBOARD,
	CONVEYOR, QC_STATION,
}

const SOLID := [
	WALL, DESK, PLANT, COUNTER, WINDOW_WALL, PC_DESK, VENDING, BOARD, MIRROR, TICKET_MACHINE,
	BOOKSHELF, WATER_COOLER, SOFA, PRINTER, TABLE, BED_HEAD, BED_FOOT, WARDROBE, HOME_WALL, FRIDGE,
	HEDGE, FACADE_SCHOOL, FACADE_FIRE, GARAGE_DOOR, FACADE_CLINIC, FACADE_CENTER, HOSPITAL_BED, LOCKER,
	MED_CABINET, KIOSK, FLOWER_BED, CHALKBOARD, CONVEYOR, QC_STATION,
]

## ASCII character -> tile.
const LEGEND := {
	".": FLOOR, "#": WALL, "D": DESK, ",": CARPET, "P": PLANT, "=": COUNTER,
	"a": ASPHALT, "|": PARKING_LINE, "g": GRASS, "E": ENTRANCE, "W": WINDOW_WALL,
	"w": WOOD_FLOOR, "C": PC_DESK, "V": VENDING, "B": BOARD, "M": MIRROR, "K": TICKET_MACHINE,
	"S": BOOKSHELF, "O": WATER_COOLER, "F": SOFA, "r": RUG, "R": PRINTER, "T": TABLE,
	"b": BED_HEAD, "n": BED_FOOT, "Z": WARDROBE, "h": HOME_FLOOR, "H": HOME_WALL, "f": FRIDGE,
	"m": DOOR_MAT,
	# 수요기관: 앞마당(q 꽃 잔디, p 길, Y 울타리, u 화단), 건물 외관(1 학교, 2 소방서, 3 차고 문,
	# 4 보건소, 5 행정복지센터, G 유리문), 실내(i 흰 타일, x 병상, k 사물함, + 약품장, c 차고 바닥,
	# N 번호표 발급기, A 칠판)
	"q": GRASS_FLOWER, "p": PATH, "Y": HEDGE, "1": FACADE_SCHOOL, "2": FACADE_FIRE, "3": GARAGE_DOOR,
	"4": FACADE_CLINIC, "5": FACADE_CENTER, "G": GLASS_DOOR, "i": TILE_WHITE, "x": HOSPITAL_BED,
	"k": LOCKER, "+": MED_CABINET, "c": GARAGE_FLOOR, "N": KIOSK, "u": FLOWER_BED, "A": CHALKBOARD,
	# 품질검사실: v 컨베이어, J 검사대
	"v": CONVEYOR, "J": QC_STATION,
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
	"N": "number_kiosk",
	"A": "chalkboard",
	"+": "med_cabinet",
	"J": "qc_station",
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
