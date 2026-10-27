class_name LockerThemeDef
extends Resource
## What kind of stuff a locker holds, from game/data/lockers.json. Display
## name: THEME_<ID> in strings.csv.

@export var id: StringName
## Relative chance of each item category, per item rolled.
@export var category_weights: Dictionary[StringName, float] = {}
@export var item_count_min: int
@export var item_count_max: int
## Pounds of low-value junk, sold for scrap by weight.
@export var junk_weight_min: int
@export var junk_weight_max: int

var name_key: String:
	get:
		return "THEME_" + String(id).to_upper()


static func from_dict(data: Dictionary) -> LockerThemeDef:
	var def := LockerThemeDef.new()
	def.id = JsonValue.as_name(data["id"])
	def.category_weights = JsonValue.as_weights(data["categories"])
	def.item_count_min = JsonValue.int_at(data["item_count"], 0)
	def.item_count_max = JsonValue.int_at(data["item_count"], 1)
	def.junk_weight_min = JsonValue.int_at(data["junk_weight"], 0)
	def.junk_weight_max = JsonValue.int_at(data["junk_weight"], 1)
	return def
