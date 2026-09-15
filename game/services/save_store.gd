class_name VngSaveStore
extends RefCounted

const SLOT_MAX := 64

var root: String


func _init(p_root: String = "user://saves") -> void:
	root = p_root.rstrip("/")


func slot_path(slot: String) -> String:
	return root.path_join(slot + ".json")


func valid_slot(slot: String) -> bool:
	if slot.is_empty() or slot.length() > SLOT_MAX:
		return false
	for i in slot.length():
		var c := slot[i]
		var is_lower := c >= "a" and c <= "z"
		var is_upper := c >= "A" and c <= "Z"
		var is_digit := c >= "0" and c <= "9"
		if not (is_lower or is_upper or is_digit or c == "_" or c == "-"):
			return false
	return true


func write(slot: String, data: Dictionary) -> Error:
	if not valid_slot(slot):
		return ERR_INVALID_PARAMETER
	var absolute := ProjectSettings.globalize_path(slot_path(slot))
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return dir_error
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", true))
	file.close()
	return OK


func read(slot: String) -> Dictionary:
	if not valid_slot(slot):
		return {}
	var absolute := ProjectSettings.globalize_path(slot_path(slot))
	if not FileAccess.file_exists(absolute):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(absolute))
	if parsed is Dictionary:
		return parsed
	return {}


func exists(slot: String) -> bool:
	return valid_slot(slot) and FileAccess.file_exists(ProjectSettings.globalize_path(slot_path(slot)))


func erase(slot: String) -> Error:
	if not valid_slot(slot):
		return ERR_INVALID_PARAMETER
	var absolute := ProjectSettings.globalize_path(slot_path(slot))
	if not FileAccess.file_exists(absolute):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(absolute)


func list_slots() -> PackedStringArray:
	var slots := PackedStringArray()
	var absolute := ProjectSettings.globalize_path(root)
	var dir := DirAccess.open(absolute)
	if dir == null:
		return slots
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			slots.append(file_name.trim_suffix(".json"))
	slots.sort()
	return slots
