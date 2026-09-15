extends RefCounted


static func test_line(test: Dictionary) -> String:
	var line := "%s %s  (%.1fms)" % [_short_status(test.status), test.id, float(test.duration_ms)]
	if test.status == "failed" and test.get("message", "") != "":
		line += "  - " + test.message
	return line


static func failure_lines(failures: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	for failure in failures:
		var f: Dictionary = failure
		lines.append("\tmessage:  %s" % f.get("message", ""))
		if f.has("expected"):
			lines.append("\texpected: %s" % f.get("expected", ""))
		if f.has("actual"):
			lines.append("\tactual:   %s" % f.get("actual", ""))
		lines.append("\tat:       %s" % f.get("location", ""))
	return lines


static func summary_line(summary: Dictionary, seed_value: int, duration_ms: int) -> String:
	return "%d tests: %d passed, %d failed, %d skipped, %d errors (%dms, seed=%d)" % [
		summary.total, summary.passed, summary.failed, summary.skipped, summary.errors, duration_ms, seed_value
	]


static func _short_status(status: String) -> String:
	match status:
		"passed":
			return "PASS"
		"failed":
			return "FAIL"
		"error":
			return "ERROR"
		"skipped":
			return "SKIP"
		_:
			return status.to_upper()
