class_name EconomyDef
extends Resource
## Game-wide tuning numbers, from game/data/economy.json.

@export var starting_cash: int
@export var starting_vehicle: StringName
@export var starting_zone: StringName
## Shop rent, charged every rent_every_days days.
@export var rent_amount: int
@export var rent_every_days: int
## Dollars per pound for junk and for anything left behind at a locker.
@export var scrap_per_pound: float
## What a scrap job pays a player who can't afford to bid.
@export var scrap_job_pay: int
## The scrap job is offered when cash is under this.
@export var scrap_job_below: int
## Worst to best.
@export var condition_order: Array[StringName] = []
@export var condition_multipliers: Dictionary[StringName, float] = {}
@export var condition_weights: Dictionary[StringName, float] = {}
@export var dirty_chance: float
@export var dirty_multiplier: float
@export var auction: AuctionRules
@export var shop: ShopRules


## Position of [param condition] from worst (0) to best, or -1 if unknown.
func condition_index(condition: StringName) -> int:
	return condition_order.find(condition)


func condition_multiplier(condition: StringName) -> float:
	if condition_multipliers.has(condition):
		return condition_multipliers[condition]
	return 1.0


static func from_dict(data: Dictionary) -> EconomyDef:
	var def := EconomyDef.new()
	def.starting_cash = JsonValue.as_int(data["starting_cash"])
	def.starting_vehicle = JsonValue.as_name(data["starting_vehicle"])
	def.starting_zone = JsonValue.as_name(data["starting_zone"])
	var rent: Dictionary = data["rent"]
	def.rent_amount = JsonValue.as_int(rent["amount"])
	def.rent_every_days = JsonValue.as_int(rent["every_days"])
	var scrap: Dictionary = data["scrap"]
	def.scrap_per_pound = JsonValue.as_float(scrap["per_pound"])
	def.scrap_job_pay = JsonValue.as_int(scrap["job_pay"])
	def.scrap_job_below = JsonValue.as_int(scrap["job_when_cash_below"])
	var conditions: Dictionary = data["conditions"]
	def.condition_order = JsonValue.as_names(conditions["order"])
	def.condition_multipliers = JsonValue.as_weights(conditions["multipliers"])
	def.condition_weights = JsonValue.as_weights(conditions["weights"])
	var dirty: Dictionary = data["dirty"]
	def.dirty_chance = JsonValue.as_float(dirty["chance"])
	def.dirty_multiplier = JsonValue.as_float(dirty["multiplier"])
	var auction_data: Dictionary = data["auction"]
	def.auction = AuctionRules.from_dict(auction_data)
	var shop_data: Dictionary = data["shop"]
	def.shop = ShopRules.from_dict(shop_data)
	return def
