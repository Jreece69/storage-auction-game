class_name RivalRoster
extends RefCounted
## The day's rivals at one zone and what's left of each one's budget.
## Budgets carry through the morning, so draining a rival on an early locker
## lets you snipe a later one cheaply.

var rivals: Array[RivalDef] = []
var budgets: Dictionary[StringName, int] = {}


## The rivals who turn up at [param zone] today, each with a fresh budget.
static func for_day(zone: ZoneDef, catalog: Catalog, rng: RandomNumberGenerator) -> RivalRoster:
	var roster := RivalRoster.new()
	for rival_id in zone.rivals:
		var def: RivalDef = catalog.rivals[rival_id]
		roster.rivals.append(def)
		roster.budgets[def.id] = roundi(rng.randi_range(def.budget_min, def.budget_max) * zone.rival_budget_factor)
	return roster


## Each rival sizes up [param locker]: an estimate of its value (true value ×
## skill noise × category bias) and a max bid (estimate × risk appetite,
## capped by their remaining budget).
func bidders_for(locker: Locker, pricing: Pricing, rng: RandomNumberGenerator) -> Array[RivalBidder]:
	var value := pricing.locker_value(locker)
	var bidders: Array[RivalBidder] = []
	for def in rivals:
		var bidder := RivalBidder.new(def)
		var noise := clampf(rng.randfn(1.0, def.estimate_noise), 0.3, 2.0)
		bidder.estimate = roundi(value * noise * category_bias(def, locker, pricing))
		var appetite := rng.randf_range(def.risk_min, def.risk_max)
		bidder.max_bid = mini(roundi(bidder.estimate * appetite), budget_of(def.id))
		bidders.append(bidder)
	return bidders


## How much more [param def] values [param locker] for holding their favorite
## category: the full favorite_bias if it's all that, none if there's none.
static func category_bias(def: RivalDef, locker: Locker, pricing: Pricing) -> float:
	if def.favorite_category == &"":
		return 1.0
	var total := 0
	var favorite := 0
	for item in locker.items:
		var value := pricing.market_value(item)
		total += value
		if pricing.def_of(item).category == def.favorite_category:
			favorite += value
	if total == 0:
		return 1.0
	return 1.0 + (def.favorite_bias - 1.0) * (float(favorite) / total)


func budget_of(rival_id: StringName) -> int:
	return budgets[rival_id] if budgets.has(rival_id) else 0


## The rivals and their budgets as plain data, for sending to other players.
func to_dict() -> Dictionary:
	var ids: Array = []
	var left: Dictionary = {}
	for def in rivals:
		ids.append(String(def.id))
		left[String(def.id)] = budget_of(def.id)
	return {"rivals": ids, "budgets": left}


static func from_dict(data: Dictionary, catalog: Catalog) -> RivalRoster:
	var roster := RivalRoster.new()
	var ids: Array = data.get("rivals", [])
	var left: Dictionary = data.get("budgets", {})
	for rival_id: Variant in ids:
		var def: RivalDef = catalog.rivals[JsonValue.as_name(rival_id)]
		roster.rivals.append(def)
		roster.budgets[def.id] = JsonValue.as_int(left.get(String(def.id), 0))
	return roster


## Charges a rival for a locker they won.
func spend(rival_id: StringName, amount: int) -> void:
	budgets[rival_id] = maxi(0, budget_of(rival_id) - amount)
