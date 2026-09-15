class_name VngSave
extends RefCounted

const VERSION := 1


static func capture(runtime: VngStoryRuntime, services: VngServices) -> Dictionary:
	return {
		"version": VERSION,
		"chapter": runtime.chapter.get("chapter", ""),
		"node": runtime.node_id,
		"step": runtime.step_index,
		"waiting": runtime.waiting,
		"ended": runtime.ended,
		"flags": runtime.state.flags.duplicate(true),
		"vars": runtime.state.vars.duplicate(true),
		"stage": runtime.stage.duplicate(true),
		"rng_state": services.rng.save_state(),
		"clock": services.clock.now(),
	}


static func apply(runtime: VngStoryRuntime, services: VngServices, save: Dictionary) -> bool:
	var version := int(save.get("version", 0))
	if version != VERSION:
		_record(runtime, "存档版本不兼容: %s" % str(save.get("version", "?")))
		return false
	var save_chapter: String = save.get("chapter", "")
	var runtime_chapter: String = runtime.chapter.get("chapter", "")
	if save_chapter != runtime_chapter:
		_record(runtime, "存档章节不匹配: '%s' != '%s'" % [save_chapter, runtime_chapter])
		return false
	runtime.restore_state(save)
	services.rng.restore_state(int(save.get("rng_state", 0)))
	services.clock.set_now(float(save.get("clock", 0.0)))
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
