extends RefCounted

# Disk writes are separate from snapshot conversion and validation.
static func write_atomic(config: ConfigFile, path: String) -> Error:
	var error := config.save(path + ".tmp")
	if error != OK: return error
	var target := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		# Only back up readable data; a failed load must not replace a good backup.
		var previous := ConfigFile.new()
		if previous.load(path) == OK:
			error = DirAccess.copy_absolute(target, target + ".bak")
			if error != OK: return error
	return DirAccess.rename_absolute(target + ".tmp", target)
