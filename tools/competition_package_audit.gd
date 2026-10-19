extends SceneTree

var files: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func collect(path: String) -> void:
	var directory := DirAccess.open(path)
	assert(directory != null)
	for name in directory.get_files():
		files.append(path.path_join(name))
	for name in directory.get_directories():
		collect(path.path_join(name))

func run() -> void:
	collect("res://")
	for path in files:
		assert(not path.begins_with("res://server/") and not path.begins_with("res://secrets/"))
		assert(not path.begins_with("res://tools/") and not path.begins_with("res://experiments/"))
		assert(not path.ends_with("_original.json") and not path.ends_with("TSCharacters.txt"))
		if path.get_extension() in ["gdc", "gd", "json", "txt"]:
			var bytes := FileAccess.get_file_as_bytes(path)
			var content := bytes.get_string_from_ascii()
			assert(not content.contains("workers.dev") and not content.contains("api.deepseek.com"))
	assert(FileAccess.file_exists("res://data/poetry/couplets.json"))
	assert(FileAccess.file_exists("res://data/poetry/traditional_map.json"))
	assert(FileAccess.file_exists("res://data/poetry/LICENSE.txt"))
	assert(FileAccess.file_exists("res://data/poetry/OpenCC-LICENSE.txt"))
	assert(not LLMConfig.is_available() and LLMConfig.API_URL.is_empty())
	print("COMPETITION PACKAGE AUDIT: PASS (%d files; bundled poetry/licenses, no server/secrets/tools/raw datasets/proxy endpoint)" % files.size())
	quit()
