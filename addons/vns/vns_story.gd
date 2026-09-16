extends RefCounted

const Util := preload("res://addons/vns/vns_util.gd")


static func load_compiled(story_dir: String) -> Dictionary:
	var result := {"ok": false, "errors": [], "manifest": {}, "chapters": {}}
	var errors: Array = result.errors
	var manifest_path := story_dir.path_join("story.json")
	if not FileAccess.file_exists(manifest_path):
		Util.add_error(errors, manifest_path, 1, 1, "缺少 story.json 清单")
		return result
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not (parsed is Dictionary):
		Util.add_error(errors, manifest_path, 1, 1, "story.json 不是合法 JSON 对象")
		return result
	var manifest: Dictionary = parsed
	var chapters: Dictionary = {}
	for chapter_id in manifest.get("chapters", []):
		var compiled_path := story_dir.path_join("compiled").path_join(str(chapter_id) + ".json")
		if not FileAccess.file_exists(compiled_path):
			Util.add_error(errors, manifest_path, 1, 1, "缺少编译产物: %s（运行 tools/story build）" % compiled_path)
			continue
		var chapter: Variant = JSON.parse_string(FileAccess.get_file_as_string(compiled_path))
		if not (chapter is Dictionary):
			Util.add_error(errors, compiled_path, 1, 1, "编译产物不是合法 JSON 对象")
			continue
		chapters[chapter_id] = chapter
	result.manifest = manifest
	result.chapters = chapters
	result.ok = errors.is_empty()
	return result


static func split_entry(entry: String) -> Dictionary:
	var parts := entry.split(".", false)
	if parts.size() != 2:
		return {}
	return {"chapter": parts[0], "node": parts[1]}


static func chapter_for_entry(entry: String, chapters: Dictionary) -> Dictionary:
	var split := split_entry(entry)
	if split.is_empty():
		return {}
	return chapters.get(split.get("chapter", ""), {})
