extends RefCounted
## Small, fixed content for unit tests, so rebalancing the real data never
## breaks a test. The numbers are picked to make the arithmetic easy to check
## by hand: no estimate noise, fixed reaction times, round values.
##
## Usage: const Fixture := preload("res://tests/helpers/fixture.gd")


static func data() -> Dictionary:
	return {
		"items": {
			"items/fixture.json": [
				{"id": "chair", "category": "furniture", "rarity": "common", "value": [100, 100], "weight": 30, "size": 2, "condition": ["broken", "mint"]},
				{"id": "lamp", "category": "furniture", "rarity": "rare", "value": [400, 400], "weight": 10, "size": 1, "condition": ["good", "good"]},
				{"id": "doll", "category": "toys", "rarity": "common", "value": [50, 50], "weight": 2, "size": 1, "condition": ["worn", "mint"]},
				{"id": "robot", "category": "toys", "rarity": "legendary", "value": [1000, 1000], "weight": 5, "size": 1, "condition": ["mint", "mint"]},
				{"id": "anvil", "category": "tools", "rarity": "common", "value": [200, 200], "weight": 150, "size": 3, "condition": ["good", "good"]},
			],
		},
		"lockers": [
			{"id": "mixed", "categories": {"furniture": 1, "toys": 1, "tools": 1}, "item_count": [4, 6], "junk_weight": [100, 100]},
			{"id": "toybox", "categories": {"toys": 1}, "item_count": [3, 3], "junk_weight": [0, 0]},
		],
		"zones": [
			{
				"id": "yard",
				"unlock_net_worth": 0,
				"lockers_per_day": 3,
				"opening_factor": 0.5,
				"opening_noise": [1.0, 1.0],
				"themes": {"mixed": 1},
				"rarity_weights": {"common": 1, "rare": 1, "legendary": 0},
				"rivals": ["rook", "shark", "collector"],
				"rival_budget_factor": 1.0,
			},
		],
		"rivals": [
			{"id": "rook", "personality": "rookie", "budget": [500, 500], "estimate_noise": 0.0, "risk_appetite": [1.2, 1.2], "jump_fold_chance": 1.0, "reaction_seconds": [1.0, 1.0]},
			{"id": "shark", "personality": "shark", "budget": [2000, 2000], "estimate_noise": 0.0, "risk_appetite": [0.7, 0.7], "jump_fold_chance": 0.0, "reaction_seconds": [2.0, 2.0]},
			{"id": "collector", "personality": "collector", "budget": [1000, 1000], "estimate_noise": 0.0, "risk_appetite": [0.8, 0.8], "jump_fold_chance": 0.0, "reaction_seconds": [1.5, 1.5], "favorite_category": "toys", "favorite_bias": 2.0},
		],
		"customers": [
			{"id": "haggler", "will_pay": [1.0, 1.0], "walk_away_ratio": 2.0, "opening_offer": [0.5, 0.5], "patience": 2, "raise_share": 0.5, "interest_chance": 1.0},
		],
		"vehicles": [
			{"id": "van", "max_weight": 100, "max_volume": 4, "price": 0},
		],
		"economy": {
			"starting_cash": 1000,
			"starting_vehicle": "van",
			"starting_zone": "yard",
			"rent": {"amount": 100, "every_days": 7},
			"scrap": {"per_pound": 0.1, "job_pay": 50},
			"conditions": {
				"order": ["broken", "worn", "good", "mint"],
				"multipliers": {"broken": 0.25, "worn": 0.5, "good": 1.0, "mint": 2.0},
				"weights": {"broken": 1, "worn": 1, "good": 1, "mint": 1},
			},
			"dirty": {"chance": 0.5, "multiplier": 0.5},
			"auction": {
				"peek_seconds": 20,
				"visible_share": 0.34,
				"countdown_seconds": 6,
				"raise_share": 0.05,
				"min_raise": 5,
				"jump_share": 0.25,
				"jump_min_raises": 3,
				"min_opening": 10,
			},
			"shop": {"shelves": 2, "slots_per_shelf": 3, "customers_per_day": 4, "price_step": 5, "customers": {"haggler": 1}},
		},
	}


static func catalog() -> Catalog:
	var built := Catalog.from_data(data())
	if not built.errors.is_empty():
		push_error("Test fixture content is invalid: %s" % [built.errors])
	return built


## A hand-built item, ignoring the definition's ranges.
static func item(uid: int, def_id: StringName, base_value: int, condition: StringName = &"good", dirty: bool = false) -> ItemInstance:
	return ItemInstance.new(uid, def_id, base_value, condition, dirty)


## A hand-built locker holding [param items] and [param junk_weight] pounds of junk.
static func locker(items: Array[ItemInstance], junk_weight: int = 0) -> Locker:
	var built := Locker.new()
	built.lot_number = 1
	built.zone_id = &"yard"
	built.theme_id = &"mixed"
	built.items = items
	built.junk_weight = junk_weight
	for one in items:
		built.visible_uids.append(one.uid)
	return built
