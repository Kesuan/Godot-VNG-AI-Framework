extends RefCounted

const Util := preload("res://addons/vns/vns_util.gd")


static func lint(chapters: Dictionary, manifest: Dictionary, manifest_path := "") -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var node_index := {}
	var local_ids := {}
	var qualified_ids: Array = []

	for chapter_id in chapters:
		var nodes: Dictionary = (chapters[chapter_id] as Dictionary).get("nodes", {})
		var ids: Array = []
		for node_id in nodes:
			var qualified := "%s.%s" % [chapter_id, node_id]
			node_index[qualified] = {"chapter": chapter_id, "node": node_id}
			qualified_ids.append(qualified)
			ids.append(node_id)
		local_ids[chapter_id] = ids

	var writes := {}
	var reads := {}
	_collect_writes_and_reads(chapters, writes, reads)

	_validate_entry(manifest, manifest_path, node_index, errors)
	_validate_targets(chapters, node_index, local_ids, errors)
	_check_reachability(chapters, manifest, node_index, warnings)
	_validate_conditions(reads, writes, errors)
	_warn_unread_writes(chapters, writes, reads, warnings)
	_validate_assets(chapters, manifest, errors)
	_validate_characters(chapters, manifest, errors)
	_warn_trailing_steps(chapters, warnings)

	Util.sort_diagnostics(errors)
	Util.sort_diagnostics(warnings)
	return {"errors": errors, "warnings": warnings}


static func _collect_writes_and_reads(chapters: Dictionary, writes: Dictionary, reads: Dictionary) -> void:
	for chapter_id in chapters:
		var nodes: Dictionary = (chapters[chapter_id] as Dictionary).get("nodes", {})
		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			for step in node.get("steps", []):
				var op: String = step.get("op", "")
				if op == "set":
					var name: String = step.get("name", "")
					var assign: String = step.get("assign", "=")
					var kind := "var"
					if assign == "=" and step.get("value") is bool:
						kind = "flag"
					if not writes.has(name):
						writes[name] = {"kind": kind, "src": step.get("src", {})}
				elif op == "choice":
					for option in step.get("options", []):
						var cond: String = option.get("cond", "")
						if cond == "":
							continue
						var parsed := VngCondition.parse(cond)
						if not parsed.ok:
							continue
						var names := {}
						_collect_identifiers(parsed.ast, names)
						for read_name in names:
							if not reads.has(read_name):
								reads[read_name] = {"src": option.get("src", {})}


static func _collect_identifiers(ast: Variant, out: Dictionary) -> void:
	if not (ast is Dictionary):
		return
	var kind: String = ast.get("k", "")
	match kind:
		"ident":
			out[ast.get("v", "")] = true
		"and", "or", "cmp":
			_collect_identifiers(ast.get("l", null), out)
			_collect_identifiers(ast.get("r", null), out)
		"not":
			_collect_identifiers(ast.get("x", null), out)


static func _validate_entry(manifest: Dictionary, manifest_path: String, node_index: Dictionary, errors: Array) -> void:
	var entry: String = manifest.get("entry", "")
	if entry == "":
		Util.add_error(errors, manifest_path, 1, 1, "story.json 缺少 entry")
		return
	if not node_index.has(entry):
		var suggestion := Util.suggest(entry, node_index.keys())
		Util.add_error(
			errors, manifest_path, 1, 1,
			Util.suggest_message("entry 指向的节点不存在", entry, suggestion)
		)


static func _validate_targets(chapters: Dictionary, node_index: Dictionary, local_ids: Dictionary, errors: Array) -> void:
	for chapter_id in chapters:
		var nodes: Dictionary = (chapters[chapter_id] as Dictionary).get("nodes", {})
		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			for step in node.get("steps", []):
				var op: String = step.get("op", "")
				if op == "goto":
					_check_target(step.get("target", ""), chapter_id, node_index, local_ids, step.get("src", {}), errors)
				elif op == "choice":
					for option in step.get("options", []):
						_check_target(option.get("target", ""), chapter_id, node_index, local_ids, option.get("src", {}), errors)


static func _check_target(
	target: String,
	current_chapter: String,
	node_index: Dictionary,
	local_ids: Dictionary,
	src: Dictionary,
	errors: Array
) -> void:
	if target == "END":
		return
	if _qualify(target, current_chapter, node_index) != "":
		return
	var candidates: Array = []
	candidates.append_array(local_ids.get(current_chapter, []))
	for qualified in node_index:
		if not candidates.has(qualified):
			candidates.append(qualified)
	var suggestion := Util.suggest(target, candidates)
	Util.add_error(
		errors, src.get("file", ""), int(src.get("line", 0)), 1,
		Util.suggest_message("跳转目标不存在", target, suggestion)
	)


static func _qualify(target: String, current_chapter: String, node_index: Dictionary) -> String:
	if target == "END" or target == "":
		return ""
	if target.contains("."):
		if node_index.has(target):
			return target
		return ""
	var qualified := "%s.%s" % [current_chapter, target]
	if node_index.has(qualified):
		return qualified
	return ""


static func _check_reachability(chapters: Dictionary, manifest: Dictionary, node_index: Dictionary, warnings: Array) -> void:
	var start := _qualify(manifest.get("entry", ""), "", node_index)
	if start == "":
		return
	var reachable := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		var parts := current.split(".", false)
		if parts.size() != 2:
			continue
		var node: Dictionary = _find_node(chapters, parts[0], parts[1])
		for step in node.get("steps", []):
			var targets: Array = []
			var op: String = step.get("op", "")
			if op == "goto":
				targets.append(step.get("target", ""))
			elif op == "choice":
				for option in step.get("options", []):
					targets.append(option.get("target", ""))
			for target in targets:
				var qualified := _qualify(target, parts[0], node_index)
				if qualified != "" and not reachable.has(qualified):
					reachable[qualified] = true
					queue.append(qualified)
	for qualified in node_index:
		if reachable.has(qualified):
			continue
		var info: Dictionary = node_index[qualified]
		var node: Dictionary = _find_node(chapters, info.get("chapter", ""), info.get("node", ""))
		var src: Dictionary = node.get("src", {})
		Util.add_warning(
			warnings, src.get("file", ""), int(src.get("line", 0)), 1,
			"节点 '%s' 不可达（没有任何跳转指向它）" % qualified
		)


static func _find_node(chapters: Dictionary, chapter_id: String, node_id: String) -> Dictionary:
	if not chapters.has(chapter_id):
		return {}
	var nodes: Dictionary = (chapters[chapter_id] as Dictionary).get("nodes", {})
	return nodes.get(node_id, {})


static func _validate_conditions(reads: Dictionary, writes: Dictionary, errors: Array) -> void:
	for read_name in reads:
		if writes.has(read_name):
			continue
		var src: Dictionary = reads[read_name].get("src", {})
		var suggestion := Util.suggest(read_name, writes.keys())
		Util.add_error(
			errors, src.get("file", ""), int(src.get("line", 0)), 1,
			Util.suggest_message("条件引用了未定义的 flag/变量", read_name, suggestion)
		)


static func _warn_unread_writes(chapters: Dictionary, writes: Dictionary, reads: Dictionary, warnings: Array) -> void:
	for name in writes:
		if reads.has(name):
			continue
		var src: Dictionary = writes[name].get("src", {})
		Util.add_warning(
			warnings, src.get("file", ""), int(src.get("line", 0)), 1,
			"flag/变量 '%s' 被写入但从未在条件中读取" % name
		)


static func _validate_assets(chapters: Dictionary, manifest: Dictionary, errors: Array) -> void:
	var assets: Dictionary = manifest.get("assets", {})
	var bg_list: Array = assets.get("bg", [])
	var bgm_list: Array = assets.get("bgm", [])
	var sfx_list: Array = assets.get("sfx", [])
	for chapter_id in chapters:
		var nodes: Dictionary = (chapters[chapter_id] as Dictionary).get("nodes", {})
		for node_id in nodes:
			for step in (nodes[node_id] as Dictionary).get("steps", []):
				var op: String = step.get("op", "")
				var src: Dictionary = step.get("src", {})
				if op == "bg":
					_check_asset(errors, step.get("asset", ""), bg_list, "背景", src)
				elif op == "bgm":
					var asset: String = step.get("asset", "")
					if asset != "stop":
						_check_asset(errors, asset, bgm_list, "BGM", src)
				elif op == "sfx":
					_check_asset(errors, step.get("asset", ""), sfx_list, "音效", src)


static func _check_asset(errors: Array, asset: String, candidates: Array, label: String, src: Dictionary) -> void:
	if asset == "" or candidates.has(asset):
		return
	var suggestion := Util.suggest(asset, candidates)
	Util.add_error(
		errors, src.get("file", ""), int(src.get("line", 0)), 1,
		Util.suggest_message("%s资源不存在（清单见 story.json）" % label, asset, suggestion)
	)


static func _validate_characters(chapters: Dictionary, manifest: Dictionary, errors: Array) -> void:
	var characters: Dictionary = manifest.get("characters", {})
	var names: Array = characters.keys()
	for chapter_id in chapters:
		var nodes: Dictionary = (chapters[chapter_id] as Dictionary).get("nodes", {})
		for node_id in nodes:
			for step in (nodes[node_id] as Dictionary).get("steps", []):
				var op: String = step.get("op", "")
				if op != "show" and op != "hide":
					continue
				var char_id: String = step.get("char", "")
				if names.has(char_id):
					continue
				var src: Dictionary = step.get("src", {})
				var suggestion := Util.suggest(char_id, names)
				Util.add_error(
					errors, src.get("file", ""), int(src.get("line", 0)), 1,
					Util.suggest_message("角色未在 story.json 中登记", char_id, suggestion)
				)


static func _warn_trailing_steps(chapters: Dictionary, warnings: Array) -> void:
	for chapter_id in chapters:
		var nodes: Dictionary = (chapters[chapter_id] as Dictionary).get("nodes", {})
		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			var steps: Array = node.get("steps", [])
			for i in range(steps.size() - 1):
				if (steps[i] as Dictionary).get("op", "") == "choice":
					var src: Dictionary = (steps[i] as Dictionary).get("src", {})
					Util.add_warning(
						warnings, src.get("file", ""), int(src.get("line", 0)), 1,
						"节点 '%s' 中 choice 之后的步骤不会执行" % node_id
					)
					break
