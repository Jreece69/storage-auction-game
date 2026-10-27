class_name RivalDef
extends Resource
## A rival bidder, from game/data/rivals.json. Display name RIVAL_<ID> and
## personality label PERSONALITY_<PERSONALITY> in strings.csv.
##
## At each locker a rival forms a private estimate (true value × skill noise ×
## category bias) and bids up to estimate × risk appetite, within what is
## left of the day's budget.

const PERSONALITIES: Array[StringName] = [&"rookie", &"shark", &"collector", &"bluffer", &"grudge"]

@export var id: StringName
@export var personality: StringName
## Daily budget range in dollars, before the zone's budget factor.
@export var budget_min: int
@export var budget_max: int
## Spread of the estimate around the true value (a standard deviation as a
## share of it). Low is sharp, high is guessing.
@export var estimate_noise: float
## Max bid as a share of the estimate. Above 1.0 overpays.
@export var risk_min: float
@export var risk_max: float
## Chance of dropping out when someone makes a jump bid.
@export var jump_fold_chance: float
## Seconds before answering a new high bid.
@export var reaction_min: float
@export var reaction_max: float
## Category this rival overpays for, if any.
@export var favorite_category: StringName = &""
## Multiplier on the estimate for a locker made entirely of the favorite
## category; mixed lockers get a share of it.
@export var favorite_bias: float = 1.0

var name_key: String:
	get:
		return "RIVAL_" + String(id).to_upper()

var personality_key: String:
	get:
		return "PERSONALITY_" + String(personality).to_upper()


static func from_dict(data: Dictionary) -> RivalDef:
	var def := RivalDef.new()
	def.id = JsonValue.as_name(data["id"])
	def.personality = JsonValue.as_name(data["personality"])
	def.budget_min = JsonValue.int_at(data["budget"], 0)
	def.budget_max = JsonValue.int_at(data["budget"], 1)
	def.estimate_noise = JsonValue.as_float(data["estimate_noise"])
	def.risk_min = JsonValue.float_at(data["risk_appetite"], 0)
	def.risk_max = JsonValue.float_at(data["risk_appetite"], 1)
	def.jump_fold_chance = JsonValue.as_float(data["jump_fold_chance"])
	def.reaction_min = JsonValue.float_at(data["reaction_seconds"], 0)
	def.reaction_max = JsonValue.float_at(data["reaction_seconds"], 1)
	def.favorite_category = JsonValue.as_name(data.get("favorite_category", ""))
	def.favorite_bias = JsonValue.as_float(data.get("favorite_bias", 1.0))
	return def
