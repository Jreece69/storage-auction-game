class_name ZoneDef
extends Resource
## A storage facility the player can bid at, from game/data/zones.json.
## Display name: ZONE_<ID> in strings.csv.

@export var id: StringName
## Net worth needed before the zone opens up.
@export var unlock_net_worth: int
@export var lockers_per_day: int
## The auctioneer opens at contents value × opening_factor × noise, so a high
## opener is a hint, not a promise.
@export var opening_factor: float
@export var opening_noise_min: float
@export var opening_noise_max: float
@export var theme_weights: Dictionary[StringName, float] = {}
@export var rarity_weights: Dictionary[StringName, float] = {}
@export var rivals: Array[StringName] = []
## Multiplies every rival's daily budget here.
@export var rival_budget_factor: float = 1.0

var name_key: String:
	get:
		return "ZONE_" + String(id).to_upper()


static func from_dict(data: Dictionary) -> ZoneDef:
	var def := ZoneDef.new()
	def.id = JsonValue.as_name(data["id"])
	def.unlock_net_worth = JsonValue.as_int(data["unlock_net_worth"])
	def.lockers_per_day = JsonValue.as_int(data["lockers_per_day"])
	def.opening_factor = JsonValue.as_float(data["opening_factor"])
	def.opening_noise_min = JsonValue.float_at(data["opening_noise"], 0)
	def.opening_noise_max = JsonValue.float_at(data["opening_noise"], 1)
	def.theme_weights = JsonValue.as_weights(data["themes"])
	def.rarity_weights = JsonValue.as_weights(data["rarity_weights"])
	def.rivals = JsonValue.as_names(data["rivals"])
	def.rival_budget_factor = JsonValue.as_float(data.get("rival_budget_factor", 1.0))
	return def
