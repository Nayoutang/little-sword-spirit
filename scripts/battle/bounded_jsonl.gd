extends RefCounted

const DEFAULT_LIMIT := 2 * 1024 * 1024

static func append(path: String, record: Dictionary, enabled := true, limit := DEFAULT_LIMIT) -> void:
	if not enabled:
		return
	var line := JSON.stringify(record) + "\n"
	if line.to_utf8_buffer().size() > limit:
		return
	if FileAccess.file_exists(path):
		var existing := FileAccess.open(path, FileAccess.READ)
		if existing == null:
			return
		var size := existing.get_length()
		existing.close()
		if size + line.to_utf8_buffer().size() > limit:
			if FileAccess.file_exists(path + ".1"):
				DirAccess.remove_absolute(path + ".1")
			if DirAccess.rename_absolute(path, path + ".1") != OK:
				return
	var output := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if output != null:
		output.seek_end()
		output.store_string(line)
