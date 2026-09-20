extends RefCounted

const Paths := preload("res://addons/vns/vns_asset_paths.gd")

const KIND_LABELS := {"bg": "背景", "char": "立绘", "bgm": "BGM", "sfx": "音效"}


static func build(chapters: Dictionary, manifest: Dictionary, asset_root := Paths.DEFAULT_ROOT) -> Dictionary:
	var used := _collect_used(chapters)
	var entries: Array = []
	var missing := 0
	for entry in used:
		var kind: String = entry.get("kind", "")
		var candidates := Paths.candidates_for(kind, entry.get("id", ""), entry.get("expr", ""), asset_root)
		var found := Paths.first_existing(candidates)
		if found == "":
			missing += 1
		entries.append({
			"kind": kind,
			"id": entry.get("id", ""),
			"expr": entry.get("expr", ""),
			"label": _label(entry),
			"candidates": Array(candidates),
			"found": found,
			"fallback": _is_fallback(entry, found),
		})
	entries.sort_custom(func(a, b):
		var a_kind := Paths.KIND_ORDER.find(a.get("kind", ""))
		var b_kind := Paths.KIND_ORDER.find(b.get("kind", ""))
		if a_kind != b_kind:
			return a_kind < b_kind
		return (a.get("label", "") as String) < (b.get("label", "") as String)
	)
	var total := entries.size()
	var report := {
		"asset_root": asset_root.rstrip("/"),
		"entries": entries,
		"unused": _collect_unused(manifest, used),
		"summary": {"total": total, "found": total - missing, "missing": missing},
	}
	report["ok"] = missing == 0
	return report


static func format(report: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("资源就位报告（root: %s）" % report.get("asset_root", ""))
	var entries: Array = report.get("entries", [])
	for kind in Paths.KIND_ORDER:
		var group: Array = []
		for entry in entries:
			if entry.get("kind", "") == kind:
				group.append(entry)
		if group.is_empty():
			continue
		var found := 0
		for entry in group:
			if entry.get("found", "") != "":
				found += 1
		lines.append("%s（%d/%d 就位）:" % [KIND_LABELS.get(kind, kind), found, group.size()])
		for entry in group:
			if entry.get("found", "") != "":
				var suffix := "（回退）" if entry.get("fallback", false) else ""
				lines.append("  [x] %s -> %s%s" % [entry.get("label", ""), entry.get("found", ""), suffix])
			else:
				lines.append("  [ ] %s" % entry.get("label", ""))
				lines.append("      候选: %s" % " | ".join(PackedStringArray(entry.get("candidates", []))))
	var summary: Dictionary = report.get("summary", {})
	lines.append("汇总: %d/%d 就位，%d 项待投放" % [
		summary.get("found", 0), summary.get("total", 0), summary.get("missing", 0)
	])
	var unused: Array = report.get("unused", [])
	if not unused.is_empty():
		var labels := PackedStringArray()
		for entry in unused:
			labels.append("%s/%s" % [entry.get("kind", ""), entry.get("id", "")])
		lines.append("未使用（清单已登记但剧本未引用）: %s" % ", ".join(labels))
	return "\n".join(lines)


static func _collect_used(chapters: Dictionary) -> Array:
	var used: Array = []
	var seen := {}
	for chapter_id in chapters:
		var nodes: Dictionary = (chapters[chapter_id] as Dictionary).get("nodes", {})
		for node_id in nodes:
			var steps: Array = (nodes[node_id] as Dictionary).get("steps", [])
			for step in steps:
				var op: String = step.get("op", "")
				match op:
					"bg":
						_add_used(used, seen, {"kind": "bg", "id": step.get("asset", "")})
					"bgm":
						var bgm: String = step.get("asset", "")
						if bgm != "stop" and bgm != "":
							_add_used(used, seen, {"kind": "bgm", "id": bgm})
					"sfx":
						_add_used(used, seen, {"kind": "sfx", "id": step.get("asset", "")})
					"show":
						_add_used(used, seen, {
							"kind": "char",
							"id": step.get("char", ""),
							"expr": step.get("expr", ""),
						})
	return used


static func _add_used(used: Array, seen: Dictionary, entry: Dictionary) -> void:
	if (entry.get("id", "") as String).is_empty():
		return
	var key := "%s|%s|%s" % [entry.get("kind", ""), entry.get("id", ""), entry.get("expr", "")]
	if seen.has(key):
		return
	seen[key] = true
	used.append(entry)


static func _collect_unused(manifest: Dictionary, used: Array) -> Array:
	var used_keys := {}
	for entry in used:
		used_keys["%s|%s" % [entry.get("kind", ""), entry.get("id", "")]] = true
	var unused: Array = []
	var assets: Dictionary = manifest.get("assets", {})
	for kind in ["bg", "bgm", "sfx"]:
		for asset_id in assets.get(kind, []):
			if not used_keys.has("%s|%s" % [kind, asset_id]):
				unused.append({"kind": kind, "id": asset_id})
	return unused


static func _label(entry: Dictionary) -> String:
	var kind: String = entry.get("kind", "")
	if kind == "char":
		return "char/%s/%s" % [entry.get("id", ""), entry.get("expr", "")]
	return "%s/%s" % [kind, entry.get("id", "")]


static func _is_fallback(entry: Dictionary, found: String) -> bool:
	if entry.get("kind", "") != "char" or found == "":
		return false
	var expr: String = entry.get("expr", "")
	if expr == "" or expr == "default":
		return false
	return found.get_file().get_basename() == "default"
