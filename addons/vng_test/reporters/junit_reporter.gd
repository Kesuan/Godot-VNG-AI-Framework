extends RefCounted


static func write_to(path: String, model: Dictionary) -> Error:
	var absolute := _globalize(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_xml(model))
	file.close()
	return OK


static func to_xml(model: Dictionary) -> String:
	var summary: Dictionary = model.get("summary", {})
	var lines := PackedStringArray()
	lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	lines.append("<testsuites name=\"vng\" tests=\"%d\" failures=\"%d\" errors=\"%d\" skipped=\"%d\" time=\"%.3f\">" % [
		summary.get("total", 0), summary.get("failed", 0), summary.get("errors", 0), summary.get("skipped", 0),
		float(summary.get("duration_ms", 0)) / 1000.0,
	])
	for suite in model.get("suites", []):
		lines.append(_suite_xml(suite))
	lines.append("</testsuites>")
	return "\n".join(lines) + "\n"


static func _suite_xml(suite: Dictionary) -> String:
	var tests: Array = suite.get("tests", [])
	var failed := 0
	var skipped := 0
	for test in tests:
		if test.status == "failed":
			failed += 1
		elif test.status == "skipped":
			skipped += 1
	var errors: int = 1 if suite.get("status", "") == "error" else 0
	var parts := PackedStringArray()
	parts.append("<testsuite name=\"%s\" file=\"%s\" tests=\"%d\" failures=\"%d\" errors=\"%d\" skipped=\"%d\" time=\"%.3f\">" % [
		_escape(suite.get("name", "")), _escape(suite.get("file", "")), tests.size(), failed, errors, skipped,
		float(suite.get("duration_ms", 0)) / 1000.0,
	])
	for failure in suite.get("setup_failures", []):
		parts.append("<error message=\"%s\">%s</error>" % [_escape(failure.get("message", "")), _escape(failure.get("location", ""))])
	for test in tests:
		parts.append(_test_xml(test, suite.get("name", "")))
	parts.append("</testsuite>")
	return "\n".join(parts)


static func _test_xml(test: Dictionary, suite_name_value: String) -> String:
	var time := float(test.get("duration_ms", 0)) / 1000.0
	var head := "<testcase name=\"%s\" classname=\"%s\" time=\"%.3f\"" % [
		_escape(test.get("name", "")), _escape(suite_name_value), time
	]
	var body := PackedStringArray()
	for failure in test.get("failures", []):
		var message: String = failure.get("message", "")
		var detail := "location: %s\nexpected: %s\nactual: %s" % [
			failure.get("location", ""), failure.get("expected", ""), failure.get("actual", ""),
		]
		body.append("<failure message=\"%s\" type=\"assertion\">%s</failure>" % [_escape(message), _escape(detail)])
	if test.get("status", "") == "skipped":
		body.append("<skipped message=\"%s\"/>" % _escape(test.get("message", "")))
	if body.is_empty():
		return head + "/>"
	return head + ">" + "".join(body) + "</testcase>"


static func _escape(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


static func _globalize(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path
