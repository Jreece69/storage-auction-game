extends GutTest
## JSON numbers arrive as floats; JsonValue turns them into the types the
## game uses.


func test_whole_floats_become_ints() -> void:
	var parsed: Dictionary = JSON.parse_string('{"weight": 35}')
	assert_eq(JsonValue.as_int(parsed["weight"]), 35)
	assert_eq(typeof(JsonValue.as_int(parsed["weight"])), TYPE_INT)


func test_ints_written_in_code_also_work() -> void:
	assert_eq(JsonValue.as_int(12), 12)
	assert_eq(JsonValue.as_float(3), 3.0)


func test_names_and_weights() -> void:
	var parsed: Dictionary = JSON.parse_string('{"ids": ["a", "b"], "weights": {"toys": 3, "books": 1.5}}')
	assert_eq(JsonValue.as_names(parsed["ids"]), [&"a", &"b"] as Array[StringName])
	var weights := JsonValue.as_weights(parsed["weights"])
	assert_eq(weights[&"toys"], 3.0)
	assert_eq(weights[&"books"], 1.5)


func test_range_elements() -> void:
	var parsed: Variant = JSON.parse_string("[5, 9.5]")
	assert_eq(JsonValue.int_at(parsed, 0), 5)
	assert_eq(JsonValue.float_at(parsed, 1), 9.5)
