class_name TrackData
## Delivery driving courses (RaceGame, 11/20 highway run). Each course is a straight
## 5-lane road from the 청사 to the destination building: "length" in px (the finish
## line is at -length), "theme" decides the scenery on both sides of the road.
## A clean run cruises at about 230-270 px/s, so 7600-8800 px is a 30-35 second trip
## (tests/drive_bot.gd drives every course).
## Each destination uses two courses (DESTINATION_TRACKS), picked at random.

const TRACKS := [
	{"name": "한빛로 도심 대로", "theme": "city", "length": 7600.0},
	{"name": "벚꽃 공원길", "theme": "park", "length": 7600.0},
	{"name": "솔숲 언덕길", "theme": "forest", "length": 8200.0},
	{"name": "강변 도로", "theme": "river", "length": 8400.0},
	{"name": "바닷가 해안 도로", "theme": "coast", "length": 8800.0},
	{"name": "논밭 시골 마을길", "theme": "village", "length": 8200.0},
	{"name": "전통시장 골목", "theme": "market", "length": 8000.0},
	{"name": "신도시 아파트 단지", "theme": "newtown", "length": 8400.0},
]

const DESTINATION_TRACKS := {
	"school": [0, 1], "fire": [2, 3], "clinic": [4, 5], "center": [6, 7],
	"nursing": [1, 5], "police": [0, 6], "hospital": [3, 7],
}

## ground: off-road color, road / edge: asphalt and curb, sidewalk: a paved strip along
## the road (towns), band: a river or the sea along the left side of the road,
## density: decor tries per spot (forests are thick), sea: the band is the wide sea with a beach, fence: wooden fences along the road (countryside), decor: [kind, weight] picked for
## each spot beside the road (see RaceGame.Decor), colors: their tints.
const THEMES := {
	"city": {"ground": Color("b4afa4"), "road": Color("4f5160"), "edge": Color("f0f0f0"), "sidewalk": Color("d8d2c4"),
			"decor": [["tower", 5], ["lamp", 3], ["street_tree", 2]],
			"colors": [Color("e8c9a0"), Color("b8c8e0"), Color("e0b0a8"), Color("d0d0d8"), Color("a8c0b8")]},
	"park": {"ground": Color("7cc35a"), "road": Color("5a5c68"), "edge": Color("f4f0e0"), "density": 2,
			"decor": [["tree", 6], ["bench", 1], ["flowers", 2], ["pond", 1]],
			"colors": [Color("f4a6c0"), Color("f8c4d4"), Color("f2b4c8")]},
	"forest": {"ground": Color("4f8f45"), "road": Color("5c5a62"), "edge": Color("e8e0c8"), "density": 4,
			"decor": [["pine", 6], ["tree", 3], ["rock", 1]],
			"colors": [Color("2f6f3a"), Color("3f7f3a"), Color("356f30"), Color("4f9f45")]},
	"river": {"ground": Color("86c160"), "road": Color("54566a"), "edge": Color("f0f0f0"), "band": Color("5aa0e0"), "density": 2,
			"decor": [["tree", 4], ["reeds", 3], ["flowers", 1]],
			"colors": [Color("6fb24f"), Color("5fa045"), Color("7cc35a")]},
	"coast": {"ground": Color("ecd9a4"), "road": Color("5a5868"), "edge": Color("ffffff"), "band": Color("4f9fe0"), "sea": true,
			"decor": [["palm", 4], ["parasol", 2], ["rock", 1]],
			"colors": [Color("e05050"), Color("4f8fe0"), Color("f0c040")]},
	"village": {"ground": Color("a9c46a"), "road": Color("6a6458"), "edge": Color("e8dcc0"), "fence": Color("8a5a36"),
			"decor": [["paddy", 5], ["house", 3], ["haystack", 2], ["persimmon", 2]],
			"colors": [Color("d84f3c"), Color("3f6fb0"), Color("4f8f6f"), Color("e0a040")]},
	"market": {"ground": Color("c98e6a"), "road": Color("6a5a58"), "edge": Color("f0d8b0"), "sidewalk": Color("dcb898"), "density": 2,
			"decor": [["stall", 5], ["shop", 3], ["crowd", 2]],
			"colors": [Color("e05050"), Color("4f8fe0"), Color("f0c040"), Color("5fbf6f")]},
	"newtown": {"ground": Color("8fd06a"), "road": Color("4c5060"), "edge": Color("f0f0f0"), "sidewalk": Color("dcdcd4"),
			"decor": [["apartment", 5], ["street_tree", 3], ["playground", 1]],
			"colors": [Color("f0f4f8"), Color("e8eef8"), Color("f8f0e4")]},
}

## Easier trips (11/18 playtest: the school run felt hard for a first delivery):
## traffic: seconds between rows x this, barricades: count, fuel_rate: per second.
const EASY := {"school": {"traffic": 1.5, "barricades": 4, "fuel_rate": 4.0}}


static func count() -> int:
	return TRACKS.size()


## {} for a normal trip, else EASY's settings for the destination.
static func easy_for(place: String) -> Dictionary:
	return EASY.get(place, {})


static func for_destination(place: String, rng: RandomNumberGenerator) -> int:
	var options: Array = DESTINATION_TRACKS.get(place, [0])
	return int(options[rng.randi() % options.size()])
