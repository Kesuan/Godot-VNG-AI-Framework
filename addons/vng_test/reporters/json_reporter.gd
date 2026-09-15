extends RefCounted


static func to_string_pretty(data: Dictionary) -> String:
	return JSON.stringify(data, "\t", true)


static func write_to(path: String, data: Dictionary) -> Error:
	var absolute := _globalize(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_string_pretty(data))
	file.close()
	return OK


static func read_from(path: String) -> Dictionary:
	var absolute := _globalize(path)
	if not FileAccess.file_exists(absolute):
		return {}
	var text := FileAccess.get_file_as_string(absolute)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func _globalize(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path
