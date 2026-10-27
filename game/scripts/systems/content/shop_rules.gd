class_name ShopRules
extends Resource
## How the shop works, from the "shop" block of game/data/economy.json.

@export var shelves: int = 4
## Space on each shelf, in the same slots as item size.
@export var slots_per_shelf: int = 3
@export var customers_per_day: int = 8
## Extra customers a day for each crew member after the first.
@export var crew_extra_customers: int = 4
## Price tags move in steps of this many dollars.
@export var price_step: int = 5
## Which kinds of customer walk in, and how often.
@export var customer_weights: Dictionary[StringName, float] = {}


static func from_dict(data: Dictionary) -> ShopRules:
	var rules := ShopRules.new()
	rules.shelves = JsonValue.as_int(data["shelves"])
	rules.slots_per_shelf = JsonValue.as_int(data["slots_per_shelf"])
	rules.customers_per_day = JsonValue.as_int(data["customers_per_day"])
	rules.crew_extra_customers = JsonValue.as_int(data["crew_extra_customers"])
	rules.price_step = JsonValue.as_int(data["price_step"])
	rules.customer_weights = JsonValue.as_weights(data["customers"])
	return rules
