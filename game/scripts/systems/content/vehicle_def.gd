class_name VehicleDef
extends Resource
## A vehicle for hauling lockers home, from game/data/vehicles.json. Display
## name VEHICLE_<ID> in strings.csv.

@export var id: StringName
## Pounds.
@export var max_weight: int
## Slots, the same unit as item size and shelf space.
@export var max_volume: int
## Upgrade price in dollars (vehicle upgrades come with the upgrade tree).
@export var price: int

var name_key: String:
	get:
		return "VEHICLE_" + String(id).to_upper()


static func from_dict(data: Dictionary) -> VehicleDef:
	var def := VehicleDef.new()
	def.id = JsonValue.as_name(data["id"])
	def.max_weight = JsonValue.as_int(data["max_weight"])
	def.max_volume = JsonValue.as_int(data["max_volume"])
	def.price = JsonValue.as_int(data["price"])
	return def
