class_name TrackData
## Racing minigame courses (RaceGame). Each course is an open road from the 청사 to
## the destination: "points" are smoothed into a Catmull-Rom curve (Curve2D).
## Rules for new courses (tests/drive_bot.gd checks them):
##   - neighbouring points 350-600 px apart, turns of 90 degrees or less are easy,
##   - parts of the road that are not neighbours stay 260+ px apart (no overlaps),
##   - length about 5000-6500 px (a race of about 25-30 seconds).
## Each destination uses two courses (DESTINATION_TRACKS), picked at random.

const TRACKS := [
	{
		"name": "한빛로 도심 대로", "theme": "city",
		"points": [[0, 0], [0, -600], [150, -1000], [600, -1150], [1100, -1100], [1300, -800], [1700, -650],
				[2100, -800], [2300, -1200], [2200, -1700], [1700, -1900], [1300, -2200], [1400, -2700]],
	},
	{
		"name": "벚꽃 공원길", "theme": "park",
		"points": [[0, 0], [-300, -450], [-150, -900], [300, -1050], [700, -900], [1000, -1200], [900, -1650],
				[450, -1800], [150, -2150], [350, -2600], [850, -2700], [1250, -2450]],
	},
	{
		"name": "소방서 언덕길", "theme": "hills",
		"points": [[0, 0], [0, -700], [400, -950], [800, -800], [850, -400], [1250, -200], [1650, -400],
				[1650, -900], [1350, -1300], [1600, -1700], [2100, -1700], [2300, -2200]],
	},
	{
		"name": "강변 도로", "theme": "river",
		"points": [[0, 0], [500, -200], [1000, -150], [1500, -400], [1700, -900], [1500, -1400], [1000, -1550],
				[600, -1800], [700, -2300], [1200, -2500], [1800, -2400], [2200, -2700]],
	},
	{
		"name": "해안 도로", "theme": "coast",
		"points": [[0, 0], [0, -500], [300, -900], [800, -1000], [1200, -1300], [1100, -1800], [600, -2000],
				[200, -2400], [400, -2900], [900, -3000], [1400, -2800]],
	},
	{
		"name": "단풍 산길", "theme": "autumn",
		"points": [[0, 0], [600, -100], [900, -400], [500, -700], [100, -900], [150, -1350], [650, -1450],
				[1050, -1700], [800, -2100], [300, -2250], [350, -2700], [900, -2800]],
	},
	{
		"name": "시장 골목", "theme": "market",
		"points": [[0, 0], [0, -500], [450, -550], [500, -1000], [950, -1050], [1000, -1500], [550, -1550],
				[500, -2000], [950, -2100], [1450, -2050], [1500, -2550]],
	},
	{
		"name": "신도시 순환로", "theme": "newtown",
		"points": [[0, 0], [-400, -400], [-400, -1000], [0, -1400], [600, -1450], [1100, -1150], [1150, -600],
				[800, -300], [700, 200], [1200, 500], [1700, 300]],
	},
]

const DESTINATION_TRACKS := {"school": [0, 1], "fire": [2, 3], "clinic": [4, 5], "center": [6, 7]}

## ground: off-road color, road / edge: asphalt and curb, decor: what lines the road,
## decor_colors: picked at random for each decor item.
const THEMES := {
	"city": {"ground": Color("c9c3b4"), "road": Color("4f5160"), "edge": Color("f0f0f0"),
			"decor": "building", "decor_colors": [Color("e8c9a0"), Color("b8c8e0"), Color("e0b0a8"), Color("d8d8d0")]},
	"park": {"ground": Color("7cc35a"), "road": Color("5a5c68"), "edge": Color("f4f0e0"),
			"decor": "tree", "decor_colors": [Color("f4a6c0"), Color("f8c4d4"), Color("6fb24f")]},
	"hills": {"ground": Color("8fbf5f"), "road": Color("5c5a62"), "edge": Color("e8e0c8"),
			"decor": "rock", "decor_colors": [Color("9a9aa4"), Color("3f7f3a"), Color("4f8f45")]},
	"river": {"ground": Color("86c160"), "road": Color("54566a"), "edge": Color("f0f0f0"),
			"decor": "water", "decor_colors": [Color("5aa0e0"), Color("6fb24f"), Color("7cc35a")]},
	"coast": {"ground": Color("e9d6a0"), "road": Color("5a5868"), "edge": Color("ffffff"),
			"decor": "water", "decor_colors": [Color("4f9fe0"), Color("5ab4e8"), Color("6fb24f")]},
	"autumn": {"ground": Color("b7b06a"), "road": Color("58565e"), "edge": Color("f0e8d0"),
			"decor": "tree", "decor_colors": [Color("e8823c"), Color("d84f3c"), Color("f0b43c")]},
	"market": {"ground": Color("c98e6a"), "road": Color("6a5a58"), "edge": Color("f0d8b0"),
			"decor": "stall", "decor_colors": [Color("e05050"), Color("4f8fe0"), Color("f0c040"), Color("5fbf6f")]},
	"newtown": {"ground": Color("8fd06a"), "road": Color("4c5060"), "edge": Color("f0f0f0"),
			"decor": "building", "decor_colors": [Color("f0f4f8"), Color("a8d0f0"), Color("c8e8d8")]},
}


static func count() -> int:
	return TRACKS.size()


static func for_destination(place: String, rng: RandomNumberGenerator) -> int:
	var options: Array = DESTINATION_TRACKS.get(place, [0])
	return int(options[rng.randi() % options.size()])


## The smoothed road (Catmull-Rom through the points).
static func build_curve(index: int) -> Curve2D:
	var pts: Array = (TRACKS[index] as Dictionary)["points"]
	var c := Curve2D.new()
	c.bake_interval = 8.0
	for i in pts.size():
		var p := Vector2(float(pts[i][0]), float(pts[i][1]))
		var prev := Vector2(float(pts[maxi(i - 1, 0)][0]), float(pts[maxi(i - 1, 0)][1]))
		var next := Vector2(float(pts[mini(i + 1, pts.size() - 1)][0]), float(pts[mini(i + 1, pts.size() - 1)][1]))
		var handle := (next - prev) * 0.2
		c.add_point(p, -handle, handle)
	return c
