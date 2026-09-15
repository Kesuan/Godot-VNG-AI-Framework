extends RefCounted


static func add_error(errors: Array, file: String, line: int, column: int, message: String) -> void:
	errors.append({"file": file, "line": line, "column": column, "message": message, "severity": "error"})


static func add_warning(warnings: Array, file: String, line: int, column: int, message: String) -> void:
	warnings.append({"file": file, "line": line, "column": column, "message": message, "severity": "warning"})


static func format_diagnostic(diagnostic: Dictionary) -> String:
	return "%s:%d:%d: %s: %s" % [
		diagnostic.get("file", "?"),
		int(diagnostic.get("line", 0)),
		int(diagnostic.get("column", 0)),
		diagnostic.get("severity", "error"),
		diagnostic.get("message", ""),
	]


static func sort_diagnostics(diagnostics: Array) -> void:
	diagnostics.sort_custom(func(a, b):
		var a_file: String = a.get("file", "")
		var b_file: String = b.get("file", "")
		if a_file != b_file:
			return a_file < b_file
		var a_line := int(a.get("line", 0))
		var b_line := int(b.get("line", 0))
		if a_line != b_line:
			return a_line < b_line
		return int(a.get("column", 0)) < int(b.get("column", 0))
	)


static func is_identifier(text: String) -> bool:
	if text.is_empty():
		return false
	var first := text[0]
	if not ((first >= "a" and first <= "z") or first == "_"):
		return false
	for i in range(1, text.length()):
		var c := text[i]
		var ok := (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"
		if not ok:
			return false
	return true


static func is_target(text: String) -> bool:
	if text == "END":
		return true
	if text.contains("."):
		var parts := text.split(".", false)
		return parts.size() == 2 and is_identifier(parts[0]) and is_identifier(parts[1])
	return is_identifier(text)


static func split_whitespace(text: String) -> PackedStringArray:
	return text.replace("\t", " ").strip_edges().split(" ", false)


static func suggest(name: String, candidates: Array) -> String:
	var best := ""
	var best_distance := 1 << 30
	for candidate in candidates:
		var c: String = candidate
		var distance := levenshtein(name, c)
		if distance < best_distance:
			best_distance = distance
			best = c
	if best == "":
		return ""
	var threshold := maxi(1, name.length() / 3)
	if best_distance > threshold:
		return ""
	return best


static func suggest_message(prefix: String, name: String, suggestion: String) -> String:
	if suggestion == "":
		return "%s: '%s'" % [prefix, name]
	return "%s: '%s'（是否想写 '%s'？）" % [prefix, name, suggestion]


static func levenshtein(a: String, b: String) -> int:
	var length_a := a.length()
	var length_b := b.length()
	if length_a == 0:
		return length_b
	if length_b == 0:
		return length_a
	var previous := PackedInt32Array()
	var current := PackedInt32Array()
	previous.resize(length_b + 1)
	current.resize(length_b + 1)
	for j in range(length_b + 1):
		previous[j] = j
	for i in range(1, length_a + 1):
		current[0] = i
		for j in range(1, length_b + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			current[j] = mini(mini(current[j - 1] + 1, previous[j] + 1), previous[j - 1] + cost)
		var swap := previous
		previous = current
		current = swap
	return previous[length_b]
