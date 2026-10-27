extends Node
## Save games: one JSON file per slot in user://saves/. Steam Auto-Cloud will
## sync that folder once the game is on Steam.
##
## A save holds the run as it stood at the start of the current day, plus the
## random streams, so loading always resumes at the start of a day and the
## day plays out the same way.
##
## Every file carries a version number. When the save format changes, bump
## SAVE_VERSION and add a step to [method _migrate_step] so old saves still
## load.

const SAVE_VERSION: int = 2
const DEFAULT_SAVE_DIR: String = "user://saves/"
## The slot the game saves to at the start of each day.
const AUTOSAVE: String = "autosave"

## Where slots live. Tests point this somewhere else so they never touch a
## real save (see tests/helpers/save_sandbox.gd).
var save_dir: String = DEFAULT_SAVE_DIR


## Writes the run in progress to [param slot].
func save_game(slot: String) -> Error:
	if not GameState.has_run():
		return ERR_UNCONFIGURED
	var snapshot := GameState.snapshot()
	var err := write_slot(slot, {"run": snapshot["run"], "rng": snapshot["rng"]})
	if err == OK:
		EventBus.game_saved.emit(slot)
	return err


## Reads [param slot] and resumes it.
## Returns ERR_FILE_NOT_FOUND for an empty slot and ERR_PARSE_ERROR for a
## file that can't be read.
func load_game(slot: String) -> Error:
	if not has_slot(slot):
		return ERR_FILE_NOT_FOUND
	var data := read_slot(slot)
	if data.is_empty():
		return ERR_PARSE_ERROR
	var run: Dictionary = data.get("run", {})
	var rng: Dictionary = data.get("rng", {})
	GameState.load_snapshot({"run": run, "rng": rng})
	EventBus.game_loaded.emit(slot)
	return OK


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func delete_slot(slot: String) -> Error:
	if not has_slot(slot):
		return OK
	return DirAccess.remove_absolute(slot_path(slot))


func slot_path(slot: String) -> String:
	return save_dir + slot.validate_filename() + ".json"


## Writes [param payload] to [param slot], stamped with SAVE_VERSION.
## The file is written in full before it replaces the old one, so a crash
## mid-save never leaves a half-written slot.
func write_slot(slot: String, payload: Dictionary) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return err
	var data := payload.duplicate(true)
	data["version"] = SAVE_VERSION
	var path := slot_path(slot)
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		err = DirAccess.remove_absolute(path)
		if err != OK:
			return err
	return DirAccess.rename_absolute(temp_path, path)


## The contents of [param slot], upgraded to SAVE_VERSION. Empty when the slot
## is missing, unreadable or from a newer version of the game.
func read_slot(slot: String) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	# JSON.new().parse() reports failure quietly, unlike JSON.parse_string().
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_error("Save slot '%s' is not valid JSON." % slot)
		return {}
	var data: Dictionary = json.data
	return migrate(data)


## Brings a save from any older version up to SAVE_VERSION, one step at a time.
func migrate(data: Dictionary) -> Dictionary:
	var version := JsonValue.as_int(data.get("version", 1))
	if version > SAVE_VERSION:
		push_error("Save is version %d but this build reads up to %d." % [version, SAVE_VERSION])
		return {}
	var upgraded := data.duplicate(true)
	while version < SAVE_VERSION:
		upgraded = _migrate_step(version, upgraded)
		version += 1
		upgraded["version"] = version
	return upgraded


## Upgrades a save from [param from_version] to the next version.
func _migrate_step(from_version: int, data: Dictionary) -> Dictionary:
	if from_version == 1:
		# Version 1 (Phase 0) kept only the day and cash, under "game_state".
		# Everything else starts fresh, as RunState fills in missing fields.
		var old: Dictionary = data.get("game_state", {})
		data["run"] = {"day": old.get("day", 1), "cash": old.get("cash", 0)}
		data.erase("game_state")
	return data
