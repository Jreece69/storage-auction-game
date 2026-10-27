extends RefCounted
## Points SaveManager at a scratch folder, so tests never read or overwrite a
## real save on the machine running them. Every test file that saves calls
## enter() in before_all() and leave() in after_all().

const DIR: String = "user://gut_saves/"


static func enter() -> void:
	SaveManager.save_dir = DIR


## Deletes whatever the tests saved and points back at the real folder.
static func leave() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for file_name in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + file_name)
	SaveManager.save_dir = SaveManager.DEFAULT_SAVE_DIR
