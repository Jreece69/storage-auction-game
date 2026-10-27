extends GutTest
## The real content loads cleanly and holds what Phase 1 needs; broken data
## is caught with a message that says exactly where.

## The real data, freshly read before each test so tests can break it.
var _data: Dictionary


func before_each() -> void:
	var problems: Array[String] = []
	_data = Catalog.read_data(Catalog.DATA_DIR, problems)
	assert_eq(problems.size(), 0, "every data file can be read")


func test_real_content_loads_without_errors() -> void:
	assert_eq(Catalog.load_from().errors, PackedStringArray())


func test_phase_one_content_is_all_there() -> void:
	var catalog := Catalog.load_from()
	assert_eq(catalog.items.size(), 30, "30 items")
	assert_eq(catalog.themes.size(), 3, "3 locker themes")
	assert_eq(catalog.zones.size(), 1, "1 zone")
	assert_eq(catalog.rivals.size(), 3, "3 rivals")
	var personalities: Array[StringName] = []
	for rival: RivalDef in catalog.rivals.values():
		personalities.append(rival.personality)
	for wanted: StringName in [&"rookie", &"shark", &"collector"]:
		assert_has(personalities, wanted)


func test_every_name_has_english_text() -> void:
	var catalog := Catalog.load_from()
	var keys: Array[String] = []
	for item: ItemDef in catalog.items.values():
		keys.append_array([item.name_key, item.desc_key])
	for theme: LockerThemeDef in catalog.themes.values():
		keys.append(theme.name_key)
	for zone: ZoneDef in catalog.zones.values():
		keys.append(zone.name_key)
	for rival: RivalDef in catalog.rivals.values():
		keys.append_array([rival.name_key, rival.personality_key])
	for customer: CustomerDef in catalog.customers.values():
		keys.append(customer.name_key)
	for vehicle: VehicleDef in catalog.vehicles.values():
		keys.append(vehicle.name_key)
	for category in catalog.categories():
		keys.append("CATEGORY_" + String(category).to_upper())
	for rarity in ItemDef.RARITIES:
		keys.append("RARITY_" + String(rarity).to_upper())
	for condition in catalog.economy.condition_order:
		keys.append("CONDITION_" + String(condition).to_upper())
	for key in keys:
		assert_ne(tr(key), key, "%s needs English text in strings.csv" % key)


func test_items_in_category_are_filtered_and_sorted() -> void:
	var toys := Catalog.load_from().items_in_category(&"toys")
	var ids: Array[StringName] = []
	for item in toys:
		assert_eq(item.category, &"toys")
		ids.append(item.id)
	assert_eq(ids, [&"bag_of_marbles", &"porcelain_doll", &"sealed_first_run_board_game", &"tin_wind_up_robot"] as Array[StringName])


func test_wrong_type_in_an_item_file() -> void:
	_entry("items", "items/toys.json", 0)["weight"] = "heavy"
	assert_eq(Catalog.from_data(_data).errors, PackedStringArray(["items/toys.json[0].weight: expected integer, got string"]))


func test_missing_economy_field() -> void:
	var economy: Dictionary = _data["economy"]
	economy.erase("starting_cash")
	assert_eq(Catalog.from_data(_data).errors, PackedStringArray(["economy.json: missing \"starting_cash\""]))


func test_theme_with_an_empty_category() -> void:
	var categories: Dictionary = _entry("lockers", "", 0)["categories"]
	categories["spaceships"] = 2
	_assert_only_error("locker theme attic_clearout: no items in category \"spaceships\"")


func test_zone_with_an_unknown_rival() -> void:
	var rivals: Array = _entry("zones", "", 0)["rivals"]
	rivals.append("ghost")
	_assert_only_error("zone rusty_row: unknown rival \"ghost\"")


func test_duplicate_item_id_across_files() -> void:
	var books: Array = _items()["items/books.json"]
	books.append(_entry("items", "items/toys.json", 0).duplicate())
	var errors := Catalog.from_data(_data).errors
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "item id \"bag_of_marbles\" is used twice")


func test_upside_down_value_range() -> void:
	_entry("items", "items/books.json", 0)["value"] = [20, 8]
	_assert_only_error("item box_of_paperbacks value: 20 is above 8")


func test_rival_too_slow_for_the_countdown() -> void:
	_entry("rivals", "", 0)["reaction_seconds"] = [0.4, 6.0]
	_assert_only_error("rival finn: reaction_seconds must stay under the 5-second countdown")


func test_item_too_big_for_a_shelf() -> void:
	_entry("items", "items/books.json", 0)["size"] = 4
	_assert_only_error("item box_of_paperbacks: size 4 won't fit on a 3-slot shelf")


func test_unknown_starting_vehicle() -> void:
	var economy: Dictionary = _data["economy"]
	economy["starting_vehicle"] = "spaceship"
	_assert_only_error("economy: unknown starting_vehicle \"spaceship\"")


func test_missing_folder_reports_every_file() -> void:
	var errors := Catalog.load_from("res://no_such_folder").errors
	assert_has(errors, "items/: no item files found")
	assert_has(errors, "economy.json: file not found")


## One entry of a data section, to break in place. For items, [param file]
## picks the item file.
func _entry(section: String, file: String, index: int) -> Dictionary:
	var entries: Array = _items()[file] if section == "items" else _data[section]
	return entries[index]


func _items() -> Dictionary:
	var items: Dictionary = _data["items"]
	return items


func _assert_only_error(expected: String) -> void:
	assert_eq(Catalog.from_data(_data).errors, PackedStringArray([expected]))
