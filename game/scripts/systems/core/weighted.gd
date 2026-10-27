class_name Weighted
extends RefCounted
## Weighted random choice. Keys are walked in alphabetical order, so a pick
## depends only on the seed and the weights, never on how the dictionary was
## built. (Sorting StringNames directly would compare memory addresses.)


## A key of [param weights] chosen with probability proportional to its
## weight. Returns null when no weight is above zero.
static func pick(weights: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var keys := sorted_keys(weights)
	var total := 0.0
	for key: Variant in keys:
		total += maxf(JsonValue.as_float(weights[key]), 0.0)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	for key: Variant in keys:
		roll -= maxf(JsonValue.as_float(weights[key]), 0.0)
		if roll < 0.0:
			return key
	# Floating-point leftovers land on the last key with any weight.
	for i in range(keys.size() - 1, -1, -1):
		if JsonValue.as_float(weights[keys[i]]) > 0.0:
			return keys[i]
	return null


## The keys of [param weights] in alphabetical order of their text.
static func sorted_keys(weights: Dictionary) -> Array:
	var keys := weights.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	return keys
