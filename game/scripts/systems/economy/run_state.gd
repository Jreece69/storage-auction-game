class_name RunState
extends RefCounted
## Everything a save holds: the day, the money, what the player owns and
## where it sits, and running totals. The game saves at the start of each day.

var day: int = 1
var cash: int = 0
var zone_id: StringName = &""
var vehicle_id: StringName = &""
var uids: UidCounter = UidCounter.new()
## Every item the player owns, by uid, whether shelved or in the back room.
var items: Dictionary[int, ItemInstance] = {}
var shop: Shop = Shop.new()
## Lifetime totals.
var lockers_won: int = 0
var best_find_def: StringName = &""
var best_find_value: int = 0


## A fresh run on day 1 with the starting cash, vehicle, zone and shop.
static func fresh(economy: EconomyDef) -> RunState:
	var run := RunState.new()
	run.cash = economy.starting_cash
	run.zone_id = economy.starting_zone
	run.vehicle_id = economy.starting_vehicle
	run.shop = Shop.new(economy.shop.shelves, economy.shop.slots_per_shelf)
	return run


## Owned items not on a shelf, in a stable order.
func backroom_uids() -> Array[int]:
	var found: Array[int] = []
	for uid: int in items:
		if not shop.is_shelved(uid):
			found.append(uid)
	found.sort()
	return found


func to_dict() -> Dictionary:
	var owned: Array = []
	var sorted_uids: Array[int] = []
	for uid: int in items:
		sorted_uids.append(uid)
	sorted_uids.sort()
	for uid in sorted_uids:
		owned.append(items[uid].to_dict())
	return {
		"day": day,
		"cash": cash,
		"zone": String(zone_id),
		"vehicle": String(vehicle_id),
		"next_uid": uids.next_uid,
		"items": owned,
		"shop": shop.to_dict(),
		"lockers_won": lockers_won,
		"best_find": {"def": String(best_find_def), "value": best_find_value},
	}


## Restores what [method to_dict] wrote. Anything missing (an older save)
## falls back to the starting values in [param economy].
static func from_dict(data: Dictionary, economy: EconomyDef) -> RunState:
	var run := fresh(economy)
	run.day = JsonValue.as_int(data.get("day", 1))
	run.cash = JsonValue.as_int(data.get("cash", economy.starting_cash))
	run.zone_id = JsonValue.as_name(data.get("zone", economy.starting_zone))
	run.vehicle_id = JsonValue.as_name(data.get("vehicle", economy.starting_vehicle))
	run.uids.next_uid = JsonValue.as_int(data.get("next_uid", 1))
	var owned: Array = data.get("items", [])
	for entry: Dictionary in owned:
		var item := ItemInstance.from_dict(entry)
		run.items[item.uid] = item
	if data.has("shop"):
		var shop_data: Dictionary = data["shop"]
		run.shop = Shop.from_dict(shop_data)
	run.lockers_won = JsonValue.as_int(data.get("lockers_won", 0))
	var best: Dictionary = data.get("best_find", {})
	run.best_find_def = JsonValue.as_name(best.get("def", ""))
	run.best_find_value = JsonValue.as_int(best.get("value", 0))
	return run
