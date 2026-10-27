class_name ItemDef
extends Resource
## One kind of item that can turn up in a locker, from game/data/items/.
## The display name and flavor text live in strings.csv under
## ITEM_<ID> and ITEM_<ID>_DESC.

const RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]

@export var id: StringName
@export var category: StringName
@export var rarity: StringName
## Base value range in dollars, before condition.
@export var value_min: int
@export var value_max: int
## Pounds.
@export var weight: int
## Space it takes on a shelf or in a vehicle, in slots.
@export var size: int
## The worst and best condition this item can turn up in.
@export var condition_min: StringName
@export var condition_max: StringName
## Collection sets this item belongs to (for collections, a v1.0 feature).
@export var sets: Array[StringName] = []

var name_key: String:
	get:
		return "ITEM_" + String(id).to_upper()

var desc_key: String:
	get:
		return name_key + "_DESC"


static func from_dict(data: Dictionary) -> ItemDef:
	var def := ItemDef.new()
	def.id = JsonValue.as_name(data["id"])
	def.category = JsonValue.as_name(data["category"])
	def.rarity = JsonValue.as_name(data["rarity"])
	def.value_min = JsonValue.int_at(data["value"], 0)
	def.value_max = JsonValue.int_at(data["value"], 1)
	def.weight = JsonValue.as_int(data["weight"])
	def.size = JsonValue.as_int(data["size"])
	var condition: Array = data["condition"]
	def.condition_min = JsonValue.as_name(condition[0])
	def.condition_max = JsonValue.as_name(condition[1])
	def.sets = JsonValue.as_names(data.get("sets", []))
	return def
