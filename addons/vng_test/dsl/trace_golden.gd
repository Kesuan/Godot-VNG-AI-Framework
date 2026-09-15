extends RefCounted


static func reduce(history: Array) -> Array:
	var events: Array = []
	for entry in history:
		var reduced := _reduce_entry(entry)
		if not reduced.is_empty():
			events.append(reduced)
	return events


static func _reduce_entry(entry: Dictionary) -> Dictionary:
	var type: String = entry.get("type", "")
	var data: Dictionary = entry.get("data", {})
	match type:
		"node_entered":
			return {"type": type, "node": data.get("node", "")}
		"line_shown":
			return {"type": type, "who": data.get("who", ""), "text": data.get("text", "")}
		"choice_presented":
			var texts: Array = []
			for option in data.get("options", []):
				texts.append((option as Dictionary).get("text", ""))
			return {"type": type, "options": texts}
		"choice_selected":
			return {"type": type, "index": data.get("index", -1), "text": data.get("text", "")}
		"flag_changed":
			return {"type": type, "name": data.get("name", ""), "value": data.get("new", false)}
		"var_changed":
			return {"type": type, "name": data.get("name", ""), "value": data.get("new", 0)}
		"bg_changed":
			return {"type": type, "asset": data.get("asset", "")}
		"char_shown":
			return {
				"type": type,
				"char": data.get("char", ""),
				"expr": data.get("expr", ""),
				"pos": data.get("pos", ""),
			}
		"char_hidden":
			return {"type": type, "char": data.get("char", "")}
		"bgm_changed":
			return {"type": type, "asset": data.get("asset", "")}
		"sfx_played":
			return {"type": type, "asset": data.get("asset", "")}
		"story_ended":
			return {"type": type}
		"story_error":
			return {"type": type, "message": data.get("message", "")}
	return {}


static func load_golden(path: String) -> Dictionary:
	var absolute := _globalize(path)
	if not FileAccess.file_exists(absolute):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(absolute))
	if parsed is Dictionary:
		return parsed
	return {}


static func save_golden(path: String, name: String, events: Array) -> Error:
	var absolute := _globalize(path)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return dir_error
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"schema": 1, "name": name, "events": events}, "\t", true) + "\n")
	file.close()
	_audit(path)
	return OK


static func compare(expected: Array, actual: Array) -> Dictionary:
	var normalized_expected := _normalize(expected)
	var normalized_actual := _normalize(actual)
	var differences: Array = []
	var count := maxi(normalized_expected.size(), normalized_actual.size())
	for i in count:
		var left: Variant = normalized_expected[i] if i < normalized_expected.size() else null
		var right: Variant = normalized_actual[i] if i < normalized_actual.size() else null
		if left != right:
			differences.append({"index": i, "expected": left, "actual": right})
	return {"equal": differences.is_empty(), "differences": differences}


static func _normalize(value: Variant) -> Array:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Array else []


static func format_diff(differences: Array, limit := 8) -> String:
	var lines := PackedStringArray()
	lines.append("共 %d 处差异:" % differences.size())
	for i in differences.size():
		if i >= limit:
			lines.append("  ...（其余 %d 处省略）" % (differences.size() - limit))
			break
		var diff: Dictionary = differences[i]
		lines.append("  [#%d] 期望: %s" % [int(diff.get("index", -1)), JSON.stringify(diff.get("expected", null))])
		lines.append("        实际: %s" % JSON.stringify(diff.get("actual", null)))
	return "\n".join(lines)


static func _audit(path: String) -> void:
	var log_path := VngRun.report_dir.path_join("trace-updates.log")
	var absolute := _globalize(log_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("[%s] updated %s (--update-traces)" % [Time.get_datetime_string_from_system(true), path])
	file.close()


static func _globalize(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path
