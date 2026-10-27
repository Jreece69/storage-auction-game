class_name JsonSchema
extends RefCounted
## Checks parsed JSON against a schema written in a small subset of JSON
## Schema: type, enum, properties, required, additionalProperties,
## propertyNames, minProperties, items, minItems, maxItems, minimum, maximum,
## exclusiveMinimum, exclusiveMaximum, minLength and pattern. Other keywords
## ($schema, title, description) are ignored.
##
## Godot parses every JSON number as a float, so "integer" accepts any number
## with no fractional part.

static var _patterns: Dictionary[String, RegEx] = {}


## Readable error lines such as "$[2].weight: expected integer, got string".
## An empty result means [param value] is valid.
static func validate(value: Variant, schema: Dictionary, path: String = "$") -> PackedStringArray:
	var errors: Array[String] = []
	_check(value, schema, path, errors)
	return PackedStringArray(errors)


static func _check(value: Variant, schema: Dictionary, path: String, errors: Array[String]) -> void:
	if schema.has("type") and not _type_matches(value, schema["type"]):
		errors.append("%s: expected %s, got %s" % [path, _type_label(schema["type"]), json_type(value)])
		return
	if schema.has("enum"):
		var allowed: Array = schema["enum"]
		if not _in_enum(value, allowed):
			errors.append("%s: %s is not one of %s" % [path, JSON.stringify(value), JSON.stringify(allowed)])
	if value is int or value is float:
		_check_number(JsonValue.as_float(value), schema, path, errors)
	elif value is String or value is StringName:
		_check_string(str(value), schema, path, errors)
	elif value is Array:
		var array: Array = value
		_check_array(array, schema, path, errors)
	elif value is Dictionary:
		var object: Dictionary = value
		_check_object(object, schema, path, errors)


static func _check_number(number: float, schema: Dictionary, path: String, errors: Array[String]) -> void:
	if schema.has("minimum") and number < JsonValue.as_float(schema["minimum"]):
		errors.append("%s: %s is below the minimum %s" % [path, format_number(number), format_number(JsonValue.as_float(schema["minimum"]))])
	if schema.has("maximum") and number > JsonValue.as_float(schema["maximum"]):
		errors.append("%s: %s is above the maximum %s" % [path, format_number(number), format_number(JsonValue.as_float(schema["maximum"]))])
	if schema.has("exclusiveMinimum") and number <= JsonValue.as_float(schema["exclusiveMinimum"]):
		errors.append("%s: %s must be above %s" % [path, format_number(number), format_number(JsonValue.as_float(schema["exclusiveMinimum"]))])
	if schema.has("exclusiveMaximum") and number >= JsonValue.as_float(schema["exclusiveMaximum"]):
		errors.append("%s: %s must be below %s" % [path, format_number(number), format_number(JsonValue.as_float(schema["exclusiveMaximum"]))])


static func _check_string(text: String, schema: Dictionary, path: String, errors: Array[String]) -> void:
	if schema.has("minLength") and text.length() < JsonValue.as_int(schema["minLength"]):
		errors.append("%s: \"%s\" is shorter than %d characters" % [path, text, JsonValue.as_int(schema["minLength"])])
	if schema.has("pattern"):
		var pattern := str(schema["pattern"])
		if _regex(pattern).search(text) == null:
			errors.append("%s: \"%s\" does not match %s" % [path, text, pattern])


static func _check_array(array: Array, schema: Dictionary, path: String, errors: Array[String]) -> void:
	if schema.has("minItems") and array.size() < JsonValue.as_int(schema["minItems"]):
		errors.append("%s: expected at least %d items, got %d" % [path, JsonValue.as_int(schema["minItems"]), array.size()])
	if schema.has("maxItems") and array.size() > JsonValue.as_int(schema["maxItems"]):
		errors.append("%s: expected at most %d items, got %d" % [path, JsonValue.as_int(schema["maxItems"]), array.size()])
	if schema.has("items"):
		var item_schema: Dictionary = schema["items"]
		for i in array.size():
			_check(array[i], item_schema, "%s[%d]" % [path, i], errors)


static func _check_object(object: Dictionary, schema: Dictionary, path: String, errors: Array[String]) -> void:
	var properties: Dictionary = schema.get("properties", {})
	var required: Array = schema.get("required", [])
	for key: Variant in required:
		if not object.has(key):
			errors.append("%s: missing \"%s\"" % [path, key])
	if schema.has("minProperties") and object.size() < JsonValue.as_int(schema["minProperties"]):
		errors.append("%s: expected at least %d entries, got %d" % [path, JsonValue.as_int(schema["minProperties"]), object.size()])
	var names_schema: Dictionary = schema.get("propertyNames", {})
	var extra: Variant = schema.get("additionalProperties", true)
	for key: Variant in object:
		var child_path := "%s.%s" % [path, key]
		if not names_schema.is_empty():
			_check(str(key), names_schema, "%s (name)" % child_path, errors)
		if properties.has(key):
			var property_schema: Dictionary = properties[key]
			_check(object[key], property_schema, child_path, errors)
		elif extra is bool and extra == false:
			errors.append("%s: unexpected field" % child_path)
		elif extra is Dictionary:
			var extra_schema: Dictionary = extra
			_check(object[key], extra_schema, child_path, errors)


static func _type_matches(value: Variant, type: Variant) -> bool:
	if type is Array:
		var types: Array = type
		for one: Variant in types:
			if _type_matches(value, one):
				return true
		return false
	match str(type):
		"object":
			return value is Dictionary
		"array":
			return value is Array
		"string":
			return value is String or value is StringName
		"boolean":
			return value is bool
		"null":
			return value == null
		"number":
			return value is int or value is float
		"integer":
			if value is int:
				return true
			if value is float:
				var number: float = value
				return is_finite(number) and number == floorf(number)
			return false
	return false


static func _in_enum(value: Variant, allowed: Array) -> bool:
	for option: Variant in allowed:
		if typeof(option) == typeof(value) and option == value:
			return true
		# Numbers compare by value whether they arrived as int or float.
		if (option is int or option is float) and (value is int or value is float) and JsonValue.as_float(option) == JsonValue.as_float(value):
			return true
	return false


## The JSON name for a parsed value's type, for error messages.
static func json_type(value: Variant) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "boolean"
	if value is int:
		return "integer"
	if value is float:
		var number: float = value
		return "integer" if number == floorf(number) else "number"
	if value is String or value is StringName:
		return "string"
	if value is Array:
		return "array"
	if value is Dictionary:
		return "object"
	return type_string(typeof(value))


static func _type_label(type: Variant) -> String:
	if type is Array:
		var names: PackedStringArray = []
		var types: Array = type
		for one: Variant in types:
			names.append(str(one))
		return " or ".join(names)
	return str(type)


static func format_number(number: float) -> String:
	return str(int(number)) if number == floorf(number) else str(number)


static func _regex(pattern: String) -> RegEx:
	if not _patterns.has(pattern):
		_patterns[pattern] = RegEx.create_from_string(pattern)
	return _patterns[pattern]
