class_name VngStoryRuntime
extends RefCounted

const WAITING_NONE := ""
const WAITING_SAY := "say"
const WAITING_CHOICE := "choice"

var services: VngServices
var chapter: Dictionary
var state: VngStoryState

var node_id := ""
var step_index := 0
var waiting := WAITING_NONE
var ended := false
var current_line: Dictionary = {}
var current_choices: Array = []
var stage := {"bg": "", "chars": {}, "bgm": ""}
var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []


func _init(p_services: VngServices, p_chapter: Dictionary) -> void:
	services = p_services
	chapter = p_chapter
	state = VngStoryState.new()


func start(start_node: String) -> void:
	if not (chapter.get("nodes", {}) as Dictionary).has(start_node):
		_abort("起始节点不存在: %s" % start_node)
		return
	_enter_node(start_node)
	_run()


func advance() -> void:
	if ended or waiting != WAITING_SAY:
		return
	step_index += 1
	waiting = WAITING_NONE
	current_line = {}
	_run()


func choose(index: int) -> void:
	if ended or waiting != WAITING_CHOICE:
		return
	var option := _option_by_index(index)
	if option.is_empty():
		_fail("无效选项索引: %d" % index)
		return
	_emit("choice_selected", {
		"index": index,
		"text": option.get("text", ""),
		"target": option.get("target", ""),
		"node": node_id,
		"step": step_index,
	})
	waiting = WAITING_NONE
	current_choices = []
	_enter_node(option.get("target", ""))
	if not ended:
		_run()


func skip_to(target: String) -> void:
	_enter_node(target)
	if not ended:
		_run()


func apply_command(command: Dictionary) -> bool:
	match command.get("type", ""):
		VngCommand.TYPE_ADVANCE:
			advance()
			return true
		VngCommand.TYPE_CHOOSE:
			choose(int(command.get("index", -1)))
			return true
		VngCommand.TYPE_SKIP_TO:
			skip_to(command.get("node", ""))
			return true
	_emit("command_ignored", {"command": command.duplicate(true)})
	return false


func pump() -> bool:
	if not services.input.has_pending():
		return false
	return apply_command(services.input.pop())


func is_waiting() -> bool:
	return waiting != WAITING_NONE


func visible_choices() -> Array:
	var result: Array = []
	for option in current_choices:
		result.append({"index": option.get("index", -1), "text": option.get("text", "")})
	return result


func snapshot() -> Dictionary:
	return {
		"chapter": chapter.get("chapter", ""),
		"node": node_id,
		"step": step_index,
		"waiting": waiting,
		"ended": ended,
		"line": current_line.duplicate(true),
		"choices": current_choices.duplicate(true),
		"flags": state.flags.duplicate(true),
		"vars": state.vars.duplicate(true),
		"stage": stage.duplicate(true),
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
	}


func restore_state(data: Dictionary) -> void:
	node_id = data.get("node", "")
	step_index = int(data.get("step", 0))
	waiting = data.get("waiting", WAITING_NONE)
	ended = bool(data.get("ended", false))
	state.restore({"flags": data.get("flags", {}), "vars": data.get("vars", {})})
	stage = (data.get("stage", {"bg": "", "chars": {}, "bgm": ""}) as Dictionary).duplicate(true)
	warnings = []
	_rebuild_waiting()


func _rebuild_waiting() -> void:
	current_line = {}
	current_choices = []
	var steps := _current_steps()
	if step_index >= steps.size():
		return
	if waiting == WAITING_SAY:
		current_line = (steps[step_index] as Dictionary).duplicate(true)
	elif waiting == WAITING_CHOICE:
		current_choices = _visible_options(steps[step_index])


func _run() -> void:
	while not ended and waiting == WAITING_NONE:
		var steps := _current_steps()
		if steps.is_empty():
			_abort("节点 '%s' 不存在或没有步骤" % node_id)
			return
		if step_index >= steps.size():
			_abort("节点 '%s' 执行到末尾但仍需跳转（缺少 goto/END）" % node_id)
			return
		_execute(steps[step_index])


func _execute(step: Dictionary) -> void:
	var op: String = step.get("op", "")
	match op:
		"say":
			current_line = step.duplicate(true)
			waiting = WAITING_SAY
			_emit("line_shown", {
				"who": step.get("who", ""),
				"text": step.get("text", ""),
				"node": node_id,
				"step": step_index,
				"src": step.get("src", {}),
			})
		"choice":
			var options := _visible_options(step)
			if options.is_empty():
				_abort("选项为空（条件全部不满足）: 节点 %s 步骤 %d" % [node_id, step_index])
				return
			current_choices = options
			waiting = WAITING_CHOICE
			var presented: Array = []
			for option in options:
				presented.append({"index": option.get("index", -1), "text": option.get("text", "")})
			_emit("choice_presented", {"options": presented, "node": node_id, "step": step_index})
		"goto":
			_enter_node(step.get("target", ""))
		"set":
			_apply_set(step)
			step_index += 1
		"bg", "show", "hide", "bgm", "sfx":
			_apply_presentation(op, step)
			step_index += 1
		_:
			_fail("未知指令 '%s'" % op)
			step_index += 1


func _apply_set(step: Dictionary) -> void:
	var name: String = step.get("name", "")
	var assign: String = step.get("assign", "=")
	var value: Variant = step.get("value", null)
	if name == "":
		_fail("set 缺少 name")
		return
	if assign == "=":
		if value is bool:
			var old_flag := state.get_flag(name)
			state.set_flag(name, value)
			_emit("flag_changed", {"name": name, "old": old_flag, "new": value, "node": node_id, "step": step_index})
		elif value is int:
			var old_var := state.get_var(name)
			state.set_var(name, value)
			_emit("var_changed", {"name": name, "old": old_var, "new": value, "node": node_id, "step": step_index})
		else:
			_fail("set 值类型不支持: %s" % _stringify(value))
	elif assign == "+=" or assign == "-=":
		if not (value is int):
			_fail("%s 需要整数" % assign)
			return
		var old_value := state.get_var(name)
		var delta: int = value if assign == "+=" else -int(value)
		state.set_var(name, old_value + delta)
		_emit("var_changed", {"name": name, "old": old_value, "new": old_value + delta, "node": node_id, "step": step_index})
	else:
		_fail("未知赋值操作 '%s'" % assign)


func _apply_presentation(op: String, step: Dictionary) -> void:
	var fade: float = float(step.get("fade", -1.0))
	match op:
		"bg":
			var bg_asset: String = step.get("asset", "")
			stage["bg"] = bg_asset
			_emit("bg_changed", {"asset": bg_asset, "fade": fade, "node": node_id, "step": step_index})
		"show":
			var char_id: String = step.get("char", "")
			var chars: Dictionary = stage["chars"]
			chars[char_id] = {"expr": step.get("expr", ""), "pos": step.get("pos", "")}
			_emit("char_shown", {
				"char": char_id,
				"expr": step.get("expr", ""),
				"pos": step.get("pos", ""),
				"fade": fade,
				"node": node_id,
				"step": step_index,
			})
		"hide":
			var hide_id: String = step.get("char", "")
			var hidden_chars: Dictionary = stage["chars"]
			hidden_chars.erase(hide_id)
			_emit("char_hidden", {"char": hide_id, "fade": fade, "node": node_id, "step": step_index})
		"bgm":
			var bgm_asset: String = step.get("asset", "")
			stage["bgm"] = bgm_asset
			_emit("bgm_changed", {"asset": bgm_asset, "node": node_id, "step": step_index})
		"sfx":
			_emit("sfx_played", {"asset": step.get("asset", ""), "node": node_id, "step": step_index})


func _visible_options(step: Dictionary) -> Array:
	var options: Array = []
	var raw: Array = step.get("options", [])
	for i in raw.size():
		var option: Dictionary = raw[i]
		var cond: String = option.get("cond", "")
		if cond != "":
			var undefined_names: Array = []
			var result := VngCondition.evaluate_text(cond, state, undefined_names)
			if not result.ok:
				_warn("选项条件求值失败 [%s]: %s" % [cond, result.error])
				continue
			for undefined_name in undefined_names:
				_warn("条件 [%s] 引用了未定义变量 '%s'，按默认值处理（建议在剧本中初始化）" % [cond, undefined_name])
			if result.value != true:
				continue
		var entry := option.duplicate(true)
		entry["index"] = i
		options.append(entry)
	return options


func _option_by_index(index: int) -> Dictionary:
	for option in current_choices:
		if int(option.get("index", -1)) == index:
			return option
	return {}


func _enter_node(target: String) -> void:
	if target == "END":
		ended = true
		waiting = WAITING_NONE
		current_line = {}
		current_choices = []
		_emit("story_ended", {})
		return
	var resolved := _resolve_target(target)
	if resolved == "":
		_abort("跳转目标不存在: %s" % target)
		return
	node_id = resolved
	step_index = 0
	waiting = WAITING_NONE
	current_line = {}
	current_choices = []
	_emit("node_entered", {"node": node_id})


func _resolve_target(target: String) -> String:
	if target == "":
		return ""
	var name := target
	if name.contains("."):
		var parts := name.split(".", false)
		if parts.size() != 2:
			return ""
		if parts[0] != chapter.get("chapter", ""):
			return ""
		name = parts[1]
	if (chapter.get("nodes", {}) as Dictionary).has(name):
		return name
	return ""


func _current_steps() -> Array:
	var nodes: Dictionary = chapter.get("nodes", {})
	if not nodes.has(node_id):
		return []
	var node: Dictionary = nodes[node_id]
	return node.get("steps", [])


func _emit(type: String, data: Dictionary) -> void:
	services.events.emit_event(type, data)


func _fail(message: String) -> void:
	var entry := {"message": message, "node": node_id, "step": step_index}
	errors.append(entry)
	_emit("story_error", entry)


func _warn(message: String) -> void:
	var entry := {"message": message, "node": node_id, "step": step_index}
	for existing in warnings:
		if existing.get("message", "") == message and int(existing.get("step", -1)) == step_index:
			return
	warnings.append(entry)


func _abort(message: String) -> void:
	_fail(message)
	ended = true
	waiting = WAITING_NONE
	current_line = {}
	current_choices = []
	_emit("story_ended", {"aborted": true})


static func _stringify(value: Variant) -> String:
	if value == null:
		return "null"
	return var_to_str(value)
