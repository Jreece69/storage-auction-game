extends GutTest
## The schema checker catches each kind of mistake and says where it is.

const ITEM_SCHEMA: Dictionary = {
	"type": "object",
	"additionalProperties": false,
	"required": ["id", "weight"],
	"properties": {
		"id": {"type": "string", "pattern": "^[a-z_]+$"},
		"weight": {"type": "integer", "minimum": 0, "maximum": 500},
		"rarity": {"enum": ["common", "rare"]},
		"value": {"type": "array", "minItems": 2, "maxItems": 2, "items": {"type": "integer"}},
		"share": {"type": "number", "exclusiveMinimum": 0},
		"categories": {
			"type": "object",
			"minProperties": 1,
			"propertyNames": {"pattern": "^[a-z]+$"},
			"additionalProperties": {"type": "number", "exclusiveMinimum": 0},
		},
	},
}


func test_valid_data_has_no_errors() -> void:
	var item: Variant = JSON.parse_string('{"id": "lamp", "weight": 14, "rarity": "rare", "value": [5, 9], "categories": {"toys": 2}}')
	assert_eq(JsonSchema.validate(item, ITEM_SCHEMA), PackedStringArray())


func test_wrong_type_names_the_field() -> void:
	var errors := JsonSchema.validate({"id": "lamp", "weight": "heavy"}, ITEM_SCHEMA)
	assert_eq(errors, PackedStringArray(["$.weight: expected integer, got string"]))


func test_integer_accepts_whole_floats_only() -> void:
	assert_eq(JsonSchema.validate({"id": "a", "weight": 14.0}, ITEM_SCHEMA).size(), 0)
	assert_eq(JsonSchema.validate({"id": "a", "weight": 14.5}, ITEM_SCHEMA).size(), 1)


func test_missing_required_field() -> void:
	assert_eq(JsonSchema.validate({"id": "lamp"}, ITEM_SCHEMA), PackedStringArray(["$: missing \"weight\""]))


func test_unknown_field_is_rejected() -> void:
	var errors := JsonSchema.validate({"id": "lamp", "weight": 1, "colour": "red"}, ITEM_SCHEMA)
	assert_eq(errors, PackedStringArray(["$.colour: unexpected field"]))


func test_enum() -> void:
	var errors := JsonSchema.validate({"id": "lamp", "weight": 1, "rarity": "mythic"}, ITEM_SCHEMA)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "\"mythic\" is not one of")


func test_number_limits() -> void:
	assert_string_contains(JsonSchema.validate({"id": "a", "weight": -1}, ITEM_SCHEMA)[0], "below the minimum 0")
	assert_string_contains(JsonSchema.validate({"id": "a", "weight": 501}, ITEM_SCHEMA)[0], "above the maximum 500")
	assert_string_contains(JsonSchema.validate({"id": "a", "weight": 1, "share": 0}, ITEM_SCHEMA)[0], "must be above 0")


func test_array_size_and_items_have_paths() -> void:
	assert_string_contains(JsonSchema.validate({"id": "a", "weight": 1, "value": [5]}, ITEM_SCHEMA)[0], "expected at least 2 items")
	assert_string_contains(JsonSchema.validate({"id": "a", "weight": 1, "value": [5, 6, 7]}, ITEM_SCHEMA)[0], "expected at most 2 items")
	assert_eq(JsonSchema.validate({"id": "a", "weight": 1, "value": [5, "x"]}, ITEM_SCHEMA), PackedStringArray(["$.value[1]: expected integer, got string"]))


func test_pattern() -> void:
	assert_string_contains(JsonSchema.validate({"id": "Lamp!", "weight": 1}, ITEM_SCHEMA)[0], "does not match")


func test_weight_maps_check_names_and_values() -> void:
	var bad_name := JsonSchema.validate({"id": "a", "weight": 1, "categories": {"Toys": 1}}, ITEM_SCHEMA)
	assert_string_contains(bad_name[0], "$.categories.Toys (name)")
	var bad_value := JsonSchema.validate({"id": "a", "weight": 1, "categories": {"toys": 0}}, ITEM_SCHEMA)
	assert_eq(bad_value, PackedStringArray(["$.categories.toys: 0 must be above 0"]))
	var empty := JsonSchema.validate({"id": "a", "weight": 1, "categories": {}}, ITEM_SCHEMA)
	assert_string_contains(empty[0], "expected at least 1 entries")


func test_custom_root_path() -> void:
	var errors := JsonSchema.validate([{"id": "a"}], {"type": "array", "items": ITEM_SCHEMA}, "items/toys.json")
	assert_eq(errors, PackedStringArray(["items/toys.json[0]: missing \"weight\""]))
