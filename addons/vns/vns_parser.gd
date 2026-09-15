extends RefCounted

const Util := preload("res://addons/vns/vns_util.gd")

const DIRECTIVES := ["bg", "show", "hide", "bgm", "sfx", "set"]


static func parse(source: String, file_path: String) -> Dictionary:
	var errors: Array = []
	var nodes := {}
	var chapter_id := ""
	var current_node := ""
	var current_node_line := 0
	var current_steps: Array = []
	var last_was_choice := false
	var line_number := 0
	var file_chapter := file_path.get_file().get_basename()

	for raw_line in source.split("\n"):
		line_number += 1
		var line := raw_line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue

		if line.begins_with("@chapter"):
			chapter_id = _parse_chapter(line, chapter_id, nodes, current_node, file_chapter, file_path, line_number, errors)
			last_was_choice = false
			continue

		if line.begins_with("::"):
			if current_node != "":
				_close_node(nodes, current_node, current_node_line, current_steps, file_path, errors)
			current_node = ""
			current_steps = []
			var node_name := line.substr(2).strip_edges()
			if not Util.is_identifier(node_name):
				Util.add_error(errors, file_path, line_number, 1, "节点名无效: '%s'（需匹配 [a-z_][a-z0-9_]*）" % node_name)
			elif nodes.has(node_name):
				Util.add_error(errors, file_path, line_number, 1, "节点重复定义: '%s'" % node_name)
			else:
				if chapter_id == "":
					Util.add_error(errors, file_path, line_number, 1, "节点定义必须位于 @chapter 声明之后")
				current_node = node_name
				current_node_line = line_number
			last_was_choice = false
			continue

		if line.begins_with("@"):
			if current_node == "":
				Util.add_error(errors, file_path, line_number, 1, "指令必须位于节点内: %s" % line)
				continue
			var step := _parse_directive(line, file_path, line_number, errors)
			if not step.is_empty():
				step["src"] = {"file": file_path, "line": line_number}
				current_steps.append(step)
			last_was_choice = false
			continue

		if line.begins_with("*"):
			if current_node == "":
				Util.add_error(errors, file_path, line_number, 1, "选项必须位于节点内")
				continue
			var option := _parse_choice(line, file_path, line_number, errors)
			if not option.is_empty():
				if last_was_choice and not current_steps.is_empty() and current_steps[current_steps.size() - 1].get("op", "") == "choice":
					var choice_step: Dictionary = current_steps[current_steps.size() - 1]
					var options: Array = choice_step.get("options", [])
					options.append(option)
				else:
					current_steps.append({
						"op": "choice",
						"options": [option],
						"src": {"file": file_path, "line": line_number},
					})
			last_was_choice = true
			continue

		if line.begins_with("->"):
			if current_node == "":
				Util.add_error(errors, file_path, line_number, 1, "跳转必须位于节点内")
			else:
				var target := line.substr(2).strip_edges()
				if not Util.is_target(target):
					Util.add_error(errors, file_path, line_number, 3, "跳转目标格式无效: '%s'（需为节点名、章节.节点 或 END）" % target)
				else:
					current_steps.append({"op": "goto", "target": target, "src": {"file": file_path, "line": line_number}})
			last_was_choice = false
			continue

		if current_node == "":
			Util.add_error(errors, file_path, line_number, 1, "对白/旁白必须位于节点内")
			last_was_choice = false
			continue
		var colon := line.find(":")
		if colon > 0 and Util.is_identifier(line.substr(0, colon)):
			var speaker := line.substr(0, colon)
			var text := line.substr(colon + 1).strip_edges()
			if text == "":
				Util.add_error(errors, file_path, line_number, colon + 2, "对白文本为空")
			current_steps.append({
				"op": "say",
				"who": speaker,
				"text": text,
				"src": {"file": file_path, "line": line_number},
			})
		else:
			var narration := line
			if narration.begins_with("\\"):
				narration = narration.substr(1)
			current_steps.append({
				"op": "say",
				"who": "",
				"text": narration,
				"src": {"file": file_path, "line": line_number},
			})
		last_was_choice = false

	if current_node != "":
		_close_node(nodes, current_node, current_node_line, current_steps, file_path, errors)
	if chapter_id == "":
		Util.add_error(errors, file_path, 1, 1, "缺少 @chapter 声明")

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"chapter": {
			"schema": 1,
			"chapter": chapter_id,
			"source": file_path,
			"nodes": nodes,
		},
	}


static func _parse_chapter(
	line: String,
	chapter_id: String,
	nodes: Dictionary,
	current_node: String,
	file_chapter: String,
	file_path: String,
	line_number: int,
	errors: Array
) -> String:
	var chapter_name := line.substr(8).strip_edges()
	if chapter_name == "":
		Util.add_error(errors, file_path, line_number, 1, "@chapter 缺少章节 id")
	elif not Util.is_identifier(chapter_name):
		Util.add_error(errors, file_path, line_number, 1, "章节 id 无效: '%s'" % chapter_name)
	elif chapter_id != "":
		Util.add_error(errors, file_path, line_number, 1, "重复的 @chapter 声明（已为 '%s'）" % chapter_id)
		return chapter_id
	elif not nodes.is_empty() or current_node != "":
		Util.add_error(errors, file_path, line_number, 1, "@chapter 必须位于所有节点之前")
	else:
		if chapter_name != file_chapter:
			Util.add_error(errors, file_path, line_number, 1, "章节 id '%s' 与文件名 '%s' 不一致" % [chapter_name, file_chapter])
		return chapter_name
	return chapter_id


static func _close_node(
	nodes: Dictionary,
	node_id: String,
	node_line: int,
	steps: Array,
	file_path: String,
	errors: Array
) -> void:
	if steps.is_empty():
		Util.add_error(errors, file_path, node_line, 1, "节点 '%s' 没有内容" % node_id)
	else:
		var last: Dictionary = steps[steps.size() - 1]
		var op: String = last.get("op", "")
		if op != "goto" and op != "choice":
			Util.add_error(errors, file_path, node_line, 1, "节点 '%s' 必须以跳转（->）或选项结尾" % node_id)
	nodes[node_id] = {
		"id": node_id,
		"src": {"file": file_path, "line": node_line},
		"steps": steps,
	}


static func _parse_directive(line: String, file_path: String, line_number: int, errors: Array) -> Dictionary:
	var parts := Util.split_whitespace(line.substr(1))
	if parts.is_empty():
		Util.add_error(errors, file_path, line_number, 1, "空指令")
		return {}
	var name: String = parts[0]
	if not DIRECTIVES.has(name):
		var suggestion := Util.suggest(name, DIRECTIVES)
		Util.add_error(errors, file_path, line_number, 2, Util.suggest_message("未知指令 @%s" % name, name, suggestion))
		return {}
	match name:
		"bg":
			return _parse_asset_step("bg", parts, file_path, line_number, errors)
		"bgm":
			return _parse_bgm(parts, file_path, line_number, errors)
		"sfx":
			return _parse_asset_step("sfx", parts, file_path, line_number, errors)
		"show":
			return _parse_show(parts, file_path, line_number, errors)
		"hide":
			return _parse_hide(parts, file_path, line_number, errors)
		"set":
			return _parse_set(parts, file_path, line_number, errors)
	return {}


static func _split_options(parts: PackedStringArray, start: int) -> Dictionary:
	var positional: Array = []
	var options := {}
	for i in range(start, parts.size()):
		var part: String = parts[i]
		if part.contains("="):
			var kv := part.split("=", true, 1)
			options[kv[0]] = kv[1]
		else:
			positional.append(part)
	return {"positional": positional, "options": options}


static func _parse_asset_step(kind: String, parts: PackedStringArray, file_path: String, line_number: int, errors: Array) -> Dictionary:
	var split := _split_options(parts, 1)
	var positional: Array = split.positional
	var options: Dictionary = split.options
	if positional.is_empty():
		Util.add_error(errors, file_path, line_number, 2, "@%s 缺少资源 id" % kind)
		return {}
	var asset: String = positional[0]
	if not Util.is_identifier(asset):
		Util.add_error(errors, file_path, line_number, 2, "资源 id 无效: '%s'" % asset)
		return {}
	var step := {"op": kind, "asset": asset}
	if not _apply_options(step, options, file_path, line_number, errors):
		return {}
	return step


static func _parse_bgm(parts: PackedStringArray, file_path: String, line_number: int, errors: Array) -> Dictionary:
	var split := _split_options(parts, 1)
	var positional: Array = split.positional
	var options: Dictionary = split.options
	if positional.is_empty():
		Util.add_error(errors, file_path, line_number, 2, "@bgm 缺少资源 id（或 stop）")
		return {}
	var asset: String = positional[0]
	if asset != "stop" and not Util.is_identifier(asset):
		Util.add_error(errors, file_path, line_number, 2, "资源 id 无效: '%s'（或 stop）" % asset)
		return {}
	var step := {"op": "bgm", "asset": asset}
	if not _apply_options(step, options, file_path, line_number, errors):
		return {}
	return step


static func _parse_show(parts: PackedStringArray, file_path: String, line_number: int, errors: Array) -> Dictionary:
	var split := _split_options(parts, 1)
	var positional: Array = split.positional
	var options: Dictionary = split.options
	if positional.size() < 3:
		Util.add_error(errors, file_path, line_number, 2, "@show 用法: @show <角色> <表情> <位置>")
		return {}
	for value in positional:
		if not Util.is_identifier(value):
			Util.add_error(errors, file_path, line_number, 2, "参数无效: '%s'（需匹配 [a-z_][a-z0-9_]*）" % value)
			return {}
	var step := {"op": "show", "char": positional[0], "expr": positional[1], "pos": positional[2]}
	if not _apply_options(step, options, file_path, line_number, errors):
		return {}
	return step


static func _parse_hide(parts: PackedStringArray, file_path: String, line_number: int, errors: Array) -> Dictionary:
	var split := _split_options(parts, 1)
	var positional: Array = split.positional
	var options: Dictionary = split.options
	if positional.is_empty():
		Util.add_error(errors, file_path, line_number, 2, "@hide 缺少角色 id")
		return {}
	var char_id: String = positional[0]
	if not Util.is_identifier(char_id):
		Util.add_error(errors, file_path, line_number, 2, "角色 id 无效: '%s'" % char_id)
		return {}
	var step := {"op": "hide", "char": char_id}
	if not _apply_options(step, options, file_path, line_number, errors):
		return {}
	return step


static func _parse_set(parts: PackedStringArray, file_path: String, line_number: int, errors: Array) -> Dictionary:
	if parts.size() < 4:
		Util.add_error(errors, file_path, line_number, 2, "@set 用法: @set <名称> = <true|false|整数> 或 @set <名称> += <整数>")
		return {}
	var set_name: String = parts[1]
	var assign: String = parts[2]
	if not Util.is_identifier(set_name):
		Util.add_error(errors, file_path, line_number, 2, "变量名无效: '%s'" % set_name)
		return {}
	if not ["=", "+=", "-="].has(assign):
		Util.add_error(errors, file_path, line_number, 2, "赋值操作必须是 =、+= 或 -=（收到 '%s'）" % assign)
		return {}
	var value_text := " ".join(parts.slice(3)).strip_edges()
	var value: Variant = null
	if assign == "=":
		if value_text == "true" or value_text == "false":
			value = value_text == "true"
		elif value_text.is_valid_int():
			value = int(value_text)
		else:
			Util.add_error(errors, file_path, line_number, 2, "值必须是 true/false 或整数（收到 '%s'）" % value_text)
			return {}
	else:
		if not value_text.is_valid_int():
			Util.add_error(errors, file_path, line_number, 2, "%s 需要整数（收到 '%s'）" % [assign, value_text])
			return {}
		value = int(value_text)
	return {"op": "set", "name": set_name, "assign": assign, "value": value}


static func _apply_options(step: Dictionary, options: Dictionary, file_path: String, line_number: int, errors: Array) -> bool:
	var ok := true
	for key in options:
		if key != "fade":
			Util.add_error(errors, file_path, line_number, 2, "未知参数 '%s'（仅支持 fade=<秒>）" % key)
			ok = false
			continue
		var raw: String = options[key]
		if not raw.is_valid_float():
			Util.add_error(errors, file_path, line_number, 2, "fade 需要数字（收到 '%s'）" % raw)
			ok = false
			continue
		step["fade"] = float(raw)
	return ok


static func _parse_choice(line: String, file_path: String, line_number: int, errors: Array) -> Dictionary:
	var rest := line.substr(1).strip_edges()
	var arrow := rest.find("->")
	if arrow == -1:
		Util.add_error(errors, file_path, line_number, 1, "选项缺少跳转目标（用法: * 文本 [{条件}] -> 目标）")
		return {}
	var target := rest.substr(arrow + 2).strip_edges()
	var head := rest.substr(0, arrow).strip_edges()
	if not Util.is_target(target):
		Util.add_error(errors, file_path, line_number, 3, "跳转目标格式无效: '%s'（需为节点名、章节.节点 或 END）" % target)
		return {}
	var cond := ""
	if head.ends_with("}"):
		var open := head.rfind("{")
		if open == -1:
			Util.add_error(errors, file_path, line_number, 1, "条件缺少左花括号")
			return {}
		cond = head.substr(open + 1, head.length() - open - 2).strip_edges()
		head = head.substr(0, open).strip_edges()
	if head == "":
		Util.add_error(errors, file_path, line_number, 1, "选项文本为空")
		return {}
	var option := {"text": head, "target": target}
	if cond != "":
		var parsed := VngCondition.parse(cond)
		if not parsed.ok:
			var brace_column := line.find("{") + 1
			Util.add_error(errors, file_path, line_number, brace_column, "条件表达式错误: %s" % parsed.error)
			return {}
		option["cond"] = cond
	option["src"] = {"file": file_path, "line": line_number}
	return option
