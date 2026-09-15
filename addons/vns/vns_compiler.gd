extends RefCounted

const Util := preload("res://addons/vns/vns_util.gd")
const Parser := preload("res://addons/vns/vns_parser.gd")
const Linter := preload("res://addons/vns/vns_linter.gd")


static func load_manifest(story_dir: String, errors: Array) -> Dictionary:
	var path := story_dir.path_join("story.json")
	if not FileAccess.file_exists(path):
		Util.add_error(errors, path, 1, 1, "缺少 story.json 清单")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		Util.add_error(errors, path, 1, 1, "story.json 不是合法 JSON 对象")
		return {}
	return parsed


static func compile_story(story_dir: String) -> Dictionary:
	var result := {"ok": false, "errors": [], "warnings": [], "chapters": {}, "manifest": {}}
	var errors: Array = result.errors
	var warnings: Array = result.warnings

	var manifest_path := story_dir.path_join("story.json")
	var manifest := load_manifest(story_dir, errors)
	if manifest.is_empty():
		Util.sort_diagnostics(errors)
		return result

	var chapters: Dictionary = {}
	var listed: Array = manifest.get("chapters", [])
	var listed_lookup := {}
	for chapter_id in listed:
		listed_lookup[chapter_id] = true

	for full_path in _find_chapter_files(story_dir):
		var chapter_id := full_path.get_file().get_basename()
		if not listed_lookup.has(chapter_id):
			Util.add_error(errors, full_path, 1, 1, "剧本未在 story.json 的 chapters 中登记")

	for chapter_id in listed:
		var path := story_dir.path_join(str(chapter_id) + ".vns")
		if not FileAccess.file_exists(path):
			Util.add_error(errors, manifest_path, 1, 1, "章节文件不存在: %s" % path)
			continue
		var source := FileAccess.get_file_as_string(path)
		var parsed := Parser.parse(source, path)
		errors.append_array(parsed.errors)
		if parsed.ok:
			chapters[chapter_id] = parsed.chapter

	if not chapters.is_empty():
		var lint_result := Linter.lint(chapters, manifest, manifest_path)
		errors.append_array(lint_result.errors)
		warnings.append_array(lint_result.warnings)

	Util.sort_diagnostics(errors)
	Util.sort_diagnostics(warnings)
	result.chapters = chapters
	result.manifest = manifest
	result.ok = errors.is_empty()
	return result


static func build_story(story_dir: String, output_dir := "") -> Dictionary:
	var result := compile_story(story_dir)
	result["written"] = []
	if not result.ok:
		return result
	var target_dir: String = output_dir if output_dir != "" else story_dir.path_join("compiled")
	var written: Array = []
	for chapter_id in result.chapters:
		var chapter: Dictionary = result.chapters[chapter_id]
		chapter["source_hash"] = _source_hash(chapter.get("source", ""))
		var error := _write_chapter(target_dir, chapter)
		if error != OK:
			Util.add_error(result.errors, target_dir, 1, 1, "编译产物写入失败: %s" % error_string(error))
			result.ok = false
			continue
		written.append(target_dir.path_join(str(chapter_id) + ".json"))
	result["written"] = written
	result.ok = result.errors.is_empty()
	return result


static func check_story(story_dir: String, output_dir := "") -> Dictionary:
	var result := compile_story(story_dir)
	var stale: Array = []
	var missing: Array = []
	if result.ok:
		var target_dir: String = output_dir if output_dir != "" else story_dir.path_join("compiled")
		for chapter_id in result.chapters:
			var chapter: Dictionary = result.chapters[chapter_id]
			var target := target_dir.path_join(str(chapter_id) + ".json")
			if not FileAccess.file_exists(target):
				missing.append(target)
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(target))
			if not (parsed is Dictionary):
				stale.append(target)
				continue
			var expected_hash := _source_hash(chapter.get("source", ""))
			if parsed.get("source_hash", "") != expected_hash:
				stale.append(target)
	result["stale"] = stale
	result["missing"] = missing
	result.ok = result.errors.is_empty() and stale.is_empty() and missing.is_empty()
	return result


static func _source_hash(source_path: String) -> String:
	if not FileAccess.file_exists(source_path):
		return ""
	return FileAccess.get_file_as_string(source_path).sha256_text()


static func _write_chapter(target_dir: String, chapter: Dictionary) -> Error:
	var absolute_dir := ProjectSettings.globalize_path(target_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return dir_error
	var file := FileAccess.open(target_dir.path_join(str(chapter.get("chapter", "chapter")) + ".json"), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(chapter, "\t", true) + "\n")
	file.close()
	return OK


static func _find_chapter_files(story_dir: String) -> PackedStringArray:
	var files := PackedStringArray()
	var dir := DirAccess.open(story_dir)
	if dir == null:
		return files
	for file_name in dir.get_files():
		if file_name.ends_with(".vns"):
			files.append(story_dir.path_join(file_name))
	files.sort()
	return files
