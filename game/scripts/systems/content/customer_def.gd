class_name CustomerDef
extends Resource
## A kind of shop customer, from game/data/customers.json. Display name
## CUSTOMER_<ID> in strings.csv.

@export var id: StringName
## The most they'll pay, as a share of the item's market value.
@export var pay_min: float
@export var pay_max: float
## They don't bother offering when the tag is this many times their limit.
@export var walk_away_ratio: float
## First offer, as a share of their limit (or the tag, if lower).
@export var offer_min: float
@export var offer_max: float
## Counters they'll sit through before leaving.
@export var patience: int
## How much of the gap to their limit they close after each counter.
@export var raise_share: float
## Chance they find something they want to make an offer on.
@export var interest_chance: float

var name_key: String:
	get:
		return "CUSTOMER_" + String(id).to_upper()


static func from_dict(data: Dictionary) -> CustomerDef:
	var def := CustomerDef.new()
	def.id = JsonValue.as_name(data["id"])
	def.pay_min = JsonValue.float_at(data["will_pay"], 0)
	def.pay_max = JsonValue.float_at(data["will_pay"], 1)
	def.walk_away_ratio = JsonValue.as_float(data["walk_away_ratio"])
	def.offer_min = JsonValue.float_at(data["opening_offer"], 0)
	def.offer_max = JsonValue.float_at(data["opening_offer"], 1)
	def.patience = JsonValue.as_int(data["patience"])
	def.raise_share = JsonValue.as_float(data["raise_share"])
	def.interest_chance = JsonValue.as_float(data["interest_chance"])
	return def
