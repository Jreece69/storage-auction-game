extends GutTest
## Project-wide checks that catch mistakes no single feature test would:
## a script that no longer compiles, a scene that won't load, or UI text that
## skips the translation table.

const TITLE_SCENE_PATH: String = "res://scenes/ui/title_screen.tscn"
const TRANSLATIONS_CSV: String = "res://data/translations/strings.csv"


func test_main_scene_is_the_title_screen() -> void:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	if main_scene.begins_with("uid://"):
		main_scene = ResourceUID.get_id_path(ResourceUID.text_to_id(main_scene))
	assert_eq(main_scene, TITLE_SCENE_PATH)


func test_every_script_compiles() -> void:
	var scripts := _files_under("res://scripts", ".gd") + _files_under("res://scenes", ".gd")
	assert_gt(scripts.size(), 0, "found game scripts to check")
	for path in scripts:
		assert_not_null(load(path) as Script, "%s should compile" % path)


func test_every_scene_instantiates() -> void:
	var scenes := _files_under("res://scenes", ".tscn")
	assert_gt(scenes.size(), 0, "found scenes to check")
	for path in scenes:
		var packed := load(path) as PackedScene
		assert_not_null(packed, "%s should load" % path)
		if packed != null:
			var root := packed.instantiate()
			assert_not_null(root, "%s should instantiate" % path)
			root.free()


func test_scene_text_uses_translation_keys() -> void:
	# Labels and buttons hold keys such as MENU_QUIT, never English.
	for path in _files_under("res://scenes", ".tscn"):
		var root := (load(path) as PackedScene).instantiate()
		for node in _with_descendants(root):
			var text := _static_text(node)
			if not text.is_empty():
				assert_ne(tr(text), text, "%s: '%s' needs a key in strings.csv" % [path, text])
		root.free()


func test_every_translation_key_has_english_text() -> void:
	var file := FileAccess.open(TRANSLATIONS_CSV, FileAccess.READ)
	var header := file.get_csv_line()
	assert_eq(header[1], "en", "English is the second column")
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 and row[0].is_empty():
			continue
		assert_eq(row.size(), header.size(), "row '%s' has every column" % row[0])
		assert_false(row[1].strip_edges().is_empty(), "'%s' has English text" % row[0])


func _files_under(dir_path: String, extension: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(extension):
			found.append(dir_path.path_join(file_name))
	for sub_dir in DirAccess.get_directories_at(dir_path):
		found.append_array(_files_under(dir_path.path_join(sub_dir), extension))
	return found


func _with_descendants(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	for child in root.get_children():
		nodes.append_array(_with_descendants(child))
	return nodes


func _static_text(node: Node) -> String:
	if node is Label:
		return (node as Label).text
	if node is Button:
		return (node as Button).text
	return ""
