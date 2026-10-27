class_name JsonValue
extends RefCounted
## Typed reads from parsed JSON and other untyped data. Godot parses every
## JSON number as a float, and the project's strict typing rules reject
## int(variant), so untyped values are converted here, in one place.
## Callers validate first (see JsonSchema); these assume the right shape.


## A whole number. JSON numbers arrive as floats; whole ones convert exactly.
static func as_int(value: Variant) -> int:
	var number: float = value
	return roundi(number)


static func as_float(value: Variant) -> float:
	var number: float = value
	return number


static func as_name(value: Variant) -> StringName:
	return StringName(str(value))


## A JSON array of ids.
static func as_names(value: Variant) -> Array[StringName]:
	var names: Array[StringName] = []
	var entries: Array = value
	for entry: Variant in entries:
		names.append(as_name(entry))
	return names


## A JSON object of id to weight, such as {"toys": 3, "books": 1}.
static func as_weights(value: Variant) -> Dictionary[StringName, float]:
	var weights: Dictionary[StringName, float] = {}
	var entries: Dictionary = value
	for key: Variant in entries:
		weights[as_name(key)] = as_float(entries[key])
	return weights


## Element [param index] of a JSON array, as an int.
static func int_at(value: Variant, index: int) -> int:
	var entries: Array = value
	return as_int(entries[index])


## Element [param index] of a JSON array, as a float.
static func float_at(value: Variant, index: int) -> float:
	var entries: Array = value
	return as_float(entries[index])
