extends Node
## Item definitions, cafeteria meals, and the one place that applies their effects.
## Add an item: add an entry to ITEMS and an icon under assets/. The vending
## machine list is Story.VENDING_ITEMS.
## Add a meal: add an entry to MEALS (eaten on the spot at the cafeteria ticket
## machine, not carried) and a 3-frame food sheet (full / half / empty).

const ICON_DIR := "res://assets/sprites/placeholder/"

## gukbap and meal are no longer sold (meals are eaten at the cafeteria); they stay
## here so bags from older saves still work.
## fatigue: amount recovered. coffee: counts toward the daily coffee limit.
## meal_bonus: improves condition by one step until the day ends.
## drive: usable during the driving minigame.
const ITEMS := {
	"gukbap": {
		"name": "국밥", "price": 8000, "fatigue": 40, "icon": "item_gukbap.png",
		"desc": "뜨끈한 국밥 한 그릇. 든든해서 피로가 확 풀린다.",
		"coffee": false, "meal_bonus": false, "drive": false, "tier": "P0",
	},
	"coffee": {
		"name": "커피", "price": 1500, "fatigue": 15, "icon": "item_coffee.png",
		"desc": "바로 정신이 든다. 하루 3잔을 넘기면 컨디션이 나빠진다.",
		"coffee": true, "meal_bonus": false, "drive": false, "tier": "P0",
	},
	"meal": {
		"name": "구내식당 정식", "price": 6000, "fatigue": 25, "icon": "item_meal.png",
		"desc": "균형 잡힌 한 끼. 오늘 하루 컨디션이 한 단계 좋아진다.",
		"coffee": false, "meal_bonus": true, "drive": false, "tier": "P1",
	},
	"energybar": {
		"name": "에너지 드링크", "price": 2000, "fatigue": 10, "icon": "item_energybar.png",
		"desc": "운전 중 Q로 마시면 부스터!",
		"coffee": false, "meal_bonus": false, "drive": true, "tier": "P1",
	},
}


## Cafeteria menu (Story.TICKET_MEALS sets the order). fatigue: recovered.
## meal_bonus: condition one step better until the day ends.
const MEALS := {
	"gukbap": {
		"name": "든든 국밥", "price": 8000, "fatigue": 40, "meal_bonus": false,
		"food": "food_gukbap.png", "comment": "뜨끈한 국물에 속이 확 풀렸어요!",
	},
	"set_meal": {
		"name": "오늘의 정식", "price": 6000, "fatigue": 25, "meal_bonus": true,
		"food": "food_meal.png", "comment": "골고루 먹었더니 몸이 가벼워요!",
	},
	"curry": {
		"name": "카레라이스", "price": 4000, "fatigue": 20, "meal_bonus": false,
		"food": "food_curry.png", "comment": "가볍고 맛있게 한 끼 해결!",
	},
}
const MEALS_PER_DAY := 2


func get_meal(id: String) -> Dictionary:
	return MEALS.get(id, {})


## Applies a meal (money is paid by the caller). Returns the before/after state
## for the result screen: {fatigue_before, fatigue_after, cond_before, cond_after}.
func eat(id: String) -> Dictionary:
	var m := get_meal(id)
	var before := {"fatigue": GameState.fatigue, "cond": GameState.condition_label()}
	GameState.meals_today += 1
	if bool(m.get("meal_bonus", false)):
		GameState.meal_bonus_today = true
	GameState.recover_fatigue(int(m.get("fatigue", 0)))
	return {
		"fatigue_before": int(before["fatigue"]), "fatigue_after": GameState.fatigue,
		"cond_before": str(before["cond"]), "cond_after": GameState.condition_label(),
	}


func has_item(id: String) -> bool:
	return ITEMS.has(id)


func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


func item_name(id: String) -> String:
	return str(get_item(id).get("name", id))


func price(id: String) -> int:
	return int(get_item(id).get("price", 0))


func icon(id: String) -> Texture2D:
	var path := ICON_DIR + str(get_item(id).get("icon", ""))
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func usable_in_drive(id: String) -> bool:
	return bool(get_item(id).get("drive", false))


## Consumes one item and applies it. Returns a message for a toast, or "" when
## the player has none.
func use(id: String) -> String:
	if not GameState.remove_item(id):
		return ""
	var it := get_item(id)
	var amount := int(it.get("fatigue", 0))
	if bool(it.get("coffee", false)):
		GameState.coffee_today += 1
	if bool(it.get("meal_bonus", false)):
		GameState.meal_bonus_today = true
	GameState.recover_fatigue(amount)
	var msg := "%s 사용! 피로도 -%d" % [item_name(id), amount]
	if bool(it.get("coffee", false)) and GameState.coffee_today > GameState.COFFEE_LIMIT:
		msg += " (커피를 너무 많이 마셨다...)"
	return msg
