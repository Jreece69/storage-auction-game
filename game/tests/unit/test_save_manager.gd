extends GutTest
## Saves hold the run as it stood at the start of the day, round-trip
## exactly, replay the same day, upgrade old versions, and fail safely.

const SaveSandbox := preload("res://tests/helpers/save_sandbox.gd")
const SLOT: String = "gut_test_slot"


func before_all() -> void:
	SaveSandbox.enter()


func after_all() -> void:
	SaveSandbox.leave()


func after_each() -> void:
	SaveManager.delete_slot(SLOT)
	GameState.end_run()


func test_nothing_to_save_without_a_run() -> void:
	GameState.end_run()
	assert_eq(SaveManager.save_game(SLOT), ERR_UNCONFIGURED)


func test_loading_returns_to_the_start_of_the_day() -> void:
	GameState.new_game(42)
	assert_eq(SaveManager.save_game(SLOT), OK)
	GameState.controller.start_day()
	GameState.controller.run.cash = 5
	assert_eq(SaveManager.load_game(SLOT), OK)
	assert_eq(GameState.cash, Content.catalog.economy.starting_cash)
	assert_eq(GameState.day, 1)


func test_a_save_after_the_day_ends_resumes_the_next_morning() -> void:
	GameState.new_game(42)
	GameState.controller.start_day()
	GameState.controller.end_day()
	var cash := GameState.cash
	SaveManager.save_game(SLOT)
	GameState.end_run()
	assert_eq(SaveManager.load_game(SLOT), OK)
	assert_eq(GameState.day, 2)
	assert_eq(GameState.cash, cash)


func test_loading_replays_the_same_lockers() -> void:
	GameState.new_game(7)
	SaveManager.save_game(SLOT)
	var first := _lockers(GameState.controller.start_day())
	SaveManager.load_game(SLOT)
	assert_eq(_lockers(GameState.controller.start_day()), first)


func test_save_file_records_its_version() -> void:
	GameState.new_game(1)
	SaveManager.save_game(SLOT)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.slot_path(SLOT)))
	assert_eq(JsonValue.as_int(raw["version"]), SaveManager.SAVE_VERSION)


func test_a_version_one_save_still_loads() -> void:
	# Phase 0 saved only the day and cash, under "game_state".
	_write_raw({"version": 1, "game_state": {"day": 4, "cash": 321}, "rng": {"master_seed": "9", "streams": {}}})
	assert_eq(SaveManager.load_game(SLOT), OK)
	assert_eq(GameState.day, 4)
	assert_eq(GameState.cash, 321)
	assert_eq(GameState.controller.run.vehicle_id, Content.catalog.economy.starting_vehicle)


func test_saving_leaves_no_temp_file_behind() -> void:
	GameState.new_game(1)
	SaveManager.save_game(SLOT)
	SaveManager.save_game(SLOT)
	assert_false(FileAccess.file_exists(SaveManager.slot_path(SLOT) + ".tmp"))


func test_empty_slot_reports_not_found() -> void:
	assert_eq(SaveManager.load_game("gut_slot_that_does_not_exist"), ERR_FILE_NOT_FOUND)


func test_corrupt_save_is_refused() -> void:
	_write_text("{ this is not json")
	assert_eq(SaveManager.load_game(SLOT), ERR_PARSE_ERROR)
	assert_push_error("not valid JSON")


func test_save_from_a_newer_game_version_is_refused() -> void:
	var future := {"version": SaveManager.SAVE_VERSION + 1, "run": {"cash": 5}}
	assert_true(SaveManager.migrate(future).is_empty())
	assert_push_error("this build reads up to")


func test_current_version_passes_through_migration_unchanged() -> void:
	var data := {"version": SaveManager.SAVE_VERSION, "run": {"cash": 5, "day": 2}}
	assert_eq(SaveManager.migrate(data), data)


func _write_raw(data: Dictionary) -> void:
	_write_text(JSON.stringify(data))


func _write_text(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.save_dir)
	var file := FileAccess.open(SaveManager.slot_path(SLOT), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _lockers(day: DayPlan) -> Array:
	var described := []
	for locker in day.lockers:
		var items := []
		for item in locker.items:
			items.append(item.to_dict())
		described.append([locker.theme_id, locker.opening_price, items])
	return described
