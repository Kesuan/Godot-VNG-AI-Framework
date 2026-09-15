extends RefCounted

const SKIP_DIRS := ["fixtures"]


static func find_test_files(root: String) -> PackedStringArray:
	var found := PackedStringArray()
	_walk(root, found)
	found.sort()
	return found


static func _walk(dir_path: String, found: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with(".") and not SKIP_DIRS.has(entry):
				_walk(dir_path.path_join(entry), found)
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			found.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()


static func parse_source(source: String) -> Dictionary:
	var file_tags: Array = []
	var file_skip := ""
	var tests := {}
	var pending_tags: Array = []
	var pending_skip := ""
	var saw_code := false
	for raw_line in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("#"):
			var doc: String = line.lstrip("#").strip_edges()
			if doc.begins_with("@tag "):
				var tag: String = doc.substr(5).strip_edges()
				if tag != "":
					pending_tags.append(tag)
			elif doc.begins_with("@skip"):
				pending_skip = doc.substr(5).strip_edges()
				if pending_skip == "":
					pending_skip = "skipped"
			continue
		if line.begins_with("func "):
			var fn := _function_name(line)
			if fn.begins_with("test_"):
				tests[fn] = {"tags": pending_tags.duplicate(), "skip": pending_skip}
			pending_tags.clear()
			pending_skip = ""
			saw_code = true
			continue
		if line == "":
			continue
		if not saw_code and (line.begins_with("extends ") or line.begins_with("class_name ")):
			if line.begins_with("extends "):
				if not pending_tags.is_empty():
					file_tags.append_array(pending_tags)
				if pending_skip != "":
					file_skip = pending_skip
			pending_tags.clear()
			pending_skip = ""
			continue
		pending_tags.clear()
		pending_skip = ""
	return {"file_tags": file_tags, "file_skip": file_skip, "tests": tests}


static func _function_name(line: String) -> String:
	var rest := line.substr(5)
	var paren := rest.find("(")
	if paren == -1:
		return rest.strip_edges()
	return rest.substr(0, paren).strip_edges()


static func suite_name(file_path: String, root: String) -> String:
	var rel := file_path
	if rel.begins_with(root + "/"):
		rel = rel.substr(root.length() + 1)
	var base := rel.get_file().trim_prefix("test_").trim_suffix(".gd")
	var dir := rel.get_base_dir()
	if dir == "." or dir == "":
		return base
	return dir + "/" + base


static func dir_tag(file_path: String, root: String) -> String:
	var rel := file_path
	if rel.begins_with(root + "/"):
		rel = rel.substr(root.length() + 1)
	if rel.contains("/"):
		return rel.get_slice("/", 0)
	return ""


static func test_id(file_path: String, test_name: String) -> String:
	return "%s::%s" % [file_path, test_name]


static func matches_pattern(pattern: String, text: String) -> bool:
	if pattern.contains("*") or pattern.contains("?"):
		return text.match(pattern) or text.match("*%s*" % pattern)
	return text.contains(pattern)


static func test_matches_filter(file_path: String, test_name: String, patterns: Array) -> bool:
	if patterns.is_empty():
		return true
	var id := test_id(file_path, test_name)
	for pattern in patterns:
		var p: String = pattern
		if matches_pattern(p, id) or matches_pattern(p, file_path):
			return true
	return false


static func file_matches_filter(file_path: String, patterns: Array) -> bool:
	if patterns.is_empty():
		return true
	for pattern in patterns:
		var p: String = pattern
		if p.contains("::"):
			if matches_pattern(p.get_slice("::", 0), file_path):
				return true
			continue
		if p.contains("/") or p.contains("*") or p.contains("?"):
			if matches_pattern(p, file_path):
				return true
		else:
			return true
	return false
