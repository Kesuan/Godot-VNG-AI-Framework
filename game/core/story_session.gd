class_name VngStorySession
extends RefCounted

## 多章节会话：持有 manifest + 全部章节，编排单章 runtime 的推进与切换。
## 跨章延续 flags / vars / stage；`-> END` 章末推进，`-> STORY_END` 提前终结全书。

var services: VngServices
var manifest: Dictionary
var chapters: Dictionary
var story_hash := ""

var state: VngStoryState
var stage: Dictionary = {"bg": "", "chars": {}, "bgm": ""}
var current_chapter := ""
var runtime: VngStoryRuntime = null
var finished := false
var errors: Array[Dictionary] = []

var _chapter_order: Array = []


func _init(p_services: VngServices, p_manifest: Dictionary, p_chapters: Dictionary) -> void:
	services = p_services
	manifest = p_manifest
	chapters = p_chapters
	state = VngStoryState.new()
	_chapter_order = manifest.get("chapters", [])
	story_hash = compute_story_hash(manifest, chapters)


func start(entry := "") -> bool:
	var resolved := resolve_entry(entry if entry != "" else str(manifest.get("entry", "")))
	if resolved.is_empty():
		return false
	_switch_chapter(str(resolved.get("chapter", "")), str(resolved.get("node", "")))
	_settle()
	return errors.is_empty()


func advance() -> void:
	if runtime == null:
		return
	runtime.advance()
	_settle()


func choose(index: int) -> void:
	if runtime == null:
		return
	runtime.choose(index)
	_settle()


func skip_to(node: String) -> void:
	if runtime == null:
		return
	runtime.skip_to(node)
	_settle()


func pump() -> bool:
	if runtime == null:
		return false
	var handled := runtime.pump()
	if handled:
		_settle()
	return handled


func resolve_entry(entry: String) -> Dictionary:
	var parts := entry.split(".", false)
	if parts.size() != 2 or not chapters.has(parts[0]):
		_fail("入口章节不存在: '%s'（需为 章节.节点）" % entry)
		return {}
	var nodes: Dictionary = (chapters[parts[0]] as Dictionary).get("nodes", {})
	if not nodes.has(parts[1]):
		_fail("入口节点不存在: '%s'" % entry)
		return {}
	return {"chapter": parts[0], "node": parts[1]}


func entry_for(chapter_id: String) -> String:
	var entries: Dictionary = manifest.get("entries", {})
	if entries.has(chapter_id):
		return "%s.%s" % [chapter_id, str(entries[chapter_id])]
	if chapter_id == first_chapter_id():
		return str(manifest.get("entry", ""))
	return ""


func first_chapter_id() -> String:
	if _chapter_order.is_empty():
		return ""
	return str(_chapter_order[0])


func next_chapter_id() -> String:
	var index := _chapter_order.find(current_chapter)
	if index == -1 or index + 1 >= _chapter_order.size():
		return ""
	return str(_chapter_order[index + 1])


func chapter_title(chapter_id: String) -> String:
	var titles: Dictionary = manifest.get("titles", {})
	return str(titles.get(chapter_id, chapter_id))


func save_data() -> Dictionary:
	if runtime == null:
		return {}
	var save := VngSave.capture(runtime, services, story_hash)
	save["finished"] = finished
	return save


func load_save(save: Dictionary) -> bool:
	var version := int(save.get("version", 0))
	if version != VngSave.VERSION:
		_fail("存档版本不兼容: %s" % str(save.get("version", "?")))
		return false
	var save_hash := str(save.get("story_hash", ""))
	if save_hash != "" and story_hash != "" and save_hash != story_hash:
		_fail("存档与当前剧本不一致（剧本已改动），无法读取")
		return false
	var chapter_id := str(save.get("chapter", ""))
	if not chapters.has(chapter_id):
		_fail("存档章节不存在: %s" % chapter_id)
		return false
	var node := str(save.get("node", ""))
	var nodes: Dictionary = (chapters[chapter_id] as Dictionary).get("nodes", {})
	if not nodes.has(node):
		_fail("存档节点不存在: %s.%s" % [chapter_id, node])
		return false
	current_chapter = chapter_id
	runtime = VngStoryRuntime.new(services, chapters[chapter_id])
	runtime.state = state
	runtime.stage = stage
	runtime.cross_chapter_handler = _on_cross_chapter_jump
	if not VngSave.apply(runtime, services, save, story_hash):
		for entry in runtime.errors:
			errors.append(entry)
		return false
	state = runtime.state
	stage = runtime.stage
	finished = bool(save.get("finished", false))
	return true


func snapshot() -> Dictionary:
	return {
		"chapter": current_chapter,
		"finished": finished,
		"runtime": runtime.snapshot() if runtime != null else {},
	}


static func compute_story_hash(p_manifest: Dictionary, p_chapters: Dictionary) -> String:
	var material: Array = []
	for chapter_id in p_manifest.get("chapters", []):
		var chapter: Dictionary = p_chapters.get(chapter_id, {})
		var source_hash: String = chapter.get("source_hash", "")
		if source_hash == "":
			source_hash = JSON.stringify(chapter).sha256_text()
		material.append({"id": chapter_id, "hash": source_hash})
	var payload := {
		"entry": p_manifest.get("entry", ""),
		"entries": p_manifest.get("entries", {}),
		"chapters": material,
	}
	return JSON.stringify(payload).sha256_text()


func _switch_chapter(chapter_id: String, node: String) -> void:
	if current_chapter != "":
		_emit("chapter_finished", {"chapter": current_chapter})
	current_chapter = chapter_id
	runtime = VngStoryRuntime.new(services, chapters[chapter_id])
	runtime.state = state
	runtime.stage = stage
	runtime.cross_chapter_handler = _on_cross_chapter_jump
	_emit("chapter_started", {"chapter": chapter_id, "entry": node})
	runtime.start(node)
	state = runtime.state
	stage = runtime.stage


func _on_cross_chapter_jump(target: String) -> bool:
	var parts := target.split(".", false)
	if parts.size() != 2 or not chapters.has(parts[0]):
		return false
	var nodes: Dictionary = (chapters[parts[0]] as Dictionary).get("nodes", {})
	if not nodes.has(parts[1]):
		return false
	_switch_chapter(parts[0], parts[1])
	return true


func _settle() -> void:
	while runtime != null and runtime.ended and not finished:
		var advanced := false
		if runtime.end_kind == VngStoryRuntime.END_CHAPTER:
			var next := next_chapter_id()
			if next != "":
				var entry := entry_for(next)
				var resolved := resolve_entry(entry) if entry != "" else {}
				if resolved.is_empty():
					if entry == "":
						_fail("章节 '%s' 缺少入口登记（story.json entries）" % next)
				else:
					_switch_chapter(str(resolved.get("chapter", "")), str(resolved.get("node", "")))
					advanced = true
		if not advanced:
			finished = true
			_emit("story_finished", {})


func _fail(message: String) -> void:
	var entry := {
		"message": message,
		"chapter": current_chapter,
		"node": runtime.node_id if runtime != null else "",
	}
	errors.append(entry)
	_emit("session_error", entry)


func _emit(type: String, data: Dictionary) -> void:
	services.events.emit_event(type, data)
