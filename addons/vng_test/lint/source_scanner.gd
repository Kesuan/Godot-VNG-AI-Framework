extends RefCounted

const BANNED_CALLS := ["randi", "randf", "randi_range", "randf_range", "randomize"]
const BANNED_MEMBERS := ["Time.", "OS.get_ticks_msec", "OS.get_ticks_usec"]

const HINT_CALLS := "禁止直接调用非确定性 API，请通过 services.rng"
const HINT_TIME := "禁止直接使用真实时间 API，请通过 services.clock"


static func scan_source(source: String, file_path := "") -> Array:
	var masked := mask(source)
	var hits: Array = []
	for index in masked.length():
		for symbol in BANNED_CALLS:
			if masked[index] != symbol[0]:
				continue
			if masked.substr(index, symbol.length()) != symbol:
				continue
			if not _is_call(masked, index, symbol.length()):
				continue
			hits.append(_violation(file_path, masked, index, symbol, HINT_CALLS))
	for symbol in BANNED_MEMBERS:
		var from := 0
		while true:
			var at := masked.find(symbol, from)
			if at == -1:
				break
			if _is_member_boundary(masked, at):
				hits.append(_violation(file_path, masked, at, symbol.rstrip("."), HINT_TIME))
			from = at + symbol.length()
	hits.sort_custom(func(a, b): return a.offset < b.offset)
	return hits


static func scan_file(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	return scan_source(FileAccess.get_file_as_string(path), path)


static func mask(source: String) -> String:
	var out := PackedStringArray()
	var i := 0
	var length := source.length()
	var in_comment := false
	var in_string := false
	var quote := ""
	while i < length:
		var c := source[i]
		if in_comment:
			if c == "\n":
				in_comment = false
				out.append(c)
			else:
				out.append(" ")
			i += 1
			continue
		if in_string:
			if c == "\\" and i + 1 < length:
				out.append(" ")
				out.append(" ")
				i += 2
				continue
			if c == quote:
				in_string = false
				out.append(c)
			else:
				out.append(" ")
			i += 1
			continue
		if c == "#":
			in_comment = true
			out.append(" ")
		elif c == "\"" or c == "'":
			in_string = true
			quote = c
			out.append(c)
		else:
			out.append(c)
		i += 1
	return "".join(out)


static func _is_call(text: String, at: int, length: int) -> bool:
	if at > 0 and (_is_ident_char(text[at - 1]) or text[at - 1] == "."):
		return false
	var i := at + length
	while i < text.length() and (text[i] == " " or text[i] == "\t"):
		i += 1
	return i < text.length() and text[i] == "("


static func _is_member_boundary(text: String, at: int) -> bool:
	if at > 0 and (_is_ident_char(text[at - 1]) or text[at - 1] == "."):
		return false
	return true


static func _violation(file_path: String, text: String, at: int, symbol: String, hint: String) -> Dictionary:
	var line := 1
	var line_start := 0
	for i in at:
		if text[i] == "\n":
			line += 1
			line_start = i + 1
	return {
		"file": file_path,
		"line": line,
		"column": at - line_start + 1,
		"offset": at,
		"symbol": symbol,
		"message": hint,
	}


static func _is_ident_char(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_"
