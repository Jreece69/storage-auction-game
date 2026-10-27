extends GutTest
## Saves must round-trip exactly, carry a version, and fail safely.

const SLOT: String = "gut_test_slot"


func after_each() -> void:
	SaveManager.delete_slot(SLOT)


func test_save_and_load_restores_the_game() -> void:
	GameState.new_game(42, 500)
	GameState.set_cash(1234)
	assert_eq(SaveManager.save_game(SLOT), OK)

	GameState.set_cash(0)
	GameState.day = 9
	assert_eq(SaveManager.load_game(SLOT), OK)

	assert_eq(GameState.cash, 1234)
	assert_eq(GameState.day, 1)


func test_loading_resumes_the_same_random_rolls() -> void:
	GameState.new_game(7, 500)
	Rng.stream(&"loot").randi()
	SaveManager.save_game(SLOT)
	var expected := Rng.stream(&"loot").randi()

	SaveManager.load_game(SLOT)

	assert_eq(Rng.stream(&"loot").randi(), expected)


func test_save_file_records_its_version() -> void:
	SaveManager.save_game(SLOT)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.slot_path(SLOT)))
	assert_eq(int(raw["version"]), SaveManager.SAVE_VERSION)


func test_saving_leaves_no_temp_file_behind() -> void:
	SaveManager.save_game(SLOT)
	SaveManager.save_game(SLOT)
	assert_false(FileAccess.file_exists(SaveManager.slot_path(SLOT) + ".tmp"))


func test_empty_slot_reports_not_found() -> void:
	assert_eq(SaveManager.load_game("gut_slot_that_does_not_exist"), ERR_FILE_NOT_FOUND)


func test_corrupt_save_is_refused() -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var file := FileAccess.open(SaveManager.slot_path(SLOT), FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()

	assert_eq(SaveManager.load_game(SLOT), ERR_PARSE_ERROR)
	assert_push_error("not valid JSON")


func test_save_from_a_newer_game_version_is_refused() -> void:
	var future := {"version": SaveManager.SAVE_VERSION + 1, "game_state": {"cash": 5}}
	assert_true(SaveManager.migrate(future).is_empty())
	assert_push_error("this build reads up to")


func test_current_version_passes_through_migration_unchanged() -> void:
	var data := {"version": SaveManager.SAVE_VERSION, "game_state": {"cash": 5, "day": 2}}
	assert_eq(SaveManager.migrate(data), data)
