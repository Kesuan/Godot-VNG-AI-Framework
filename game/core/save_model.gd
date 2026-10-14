class_name VngSave
extends RefCounted

const VERSION := 2


static func capture(runtime: VngStoryRuntime, services: VngServices, story_hash := "") -> Dictionary:
	return {
		"version": VERSION,
		"story_hash": story_hash,
		"chapter": runtime.chapter.get("chapter", ""),
		"node": runtime.node_id,
		"step": runtime.step_index,
		"waiting": runtime.waiting,
		"ended": runtime.ended,
		"end_kind": runtime.end_kind,
		"flags": runtime.state.flags.duplicate(true),
		"vars": runtime.state.vars.duplicate(true),
		"stage": runtime.stage.duplicate(true),
		"line": runtime.current_line.duplicate(true),
		"ending_id": runtime.ending_id,
		"rng_state": services.rng.save_state(),
		"play_time": services.clock.now(),
	}


static func apply(runtime: VngStoryRuntime, services: VngServices, save: Dictionary, story_hash := "") -> bool:
	var version := int(save.get("version", 0))
	if version != VERSION:
		_record(runtime, "存档版本不兼容: %s" % str(save.get("version", "?")))
		return false
	var save_hash := str(save.get("story_hash", ""))
	if story_hash != "" and save_hash != "" and save_hash != story_hash:
		_record(runtime, "存档与当前剧本不一致（剧本已改动）")
		return false
	var save_chapter: String = save.get("chapter", "")
	var runtime_chapter: String = runtime.chapter.get("chapter", "")
	if save_chapter != runtime_chapter:
		_record(runtime, "存档章节不匹配: '%s' != '%s'" % [save_chapter, runtime_chapter])
		return false
	runtime.restore_state(save)
	services.rng.restore_state(int(save.get("rng_state", 0)))
	services.clock.set_now(float(save.get("play_time", save.get("clock", 0.0))))
	services.events.emit_event("save_applied", {"node": runtime.node_id, "step": runtime.step_index})
	return true


static func to_json(save: Dictionary) -> String:
	return JSON.stringify(save, "\t", true)


static func from_json(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func _record(runtime: VngStoryRuntime, message: String) -> void:
	runtime.errors.append({"message": message, "node": runtime.node_id, "step": runtime.step_index})
