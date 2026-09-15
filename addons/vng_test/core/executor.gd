extends RefCounted

const VngTestBase := preload("res://addons/vng_test/core/vng_test.gd")
const VngRunContext := preload("res://addons/vng_test/core/vng_run.gd")
const Discovery := preload("res://addons/vng_test/core/discovery.gd")
const ConsoleReporter := preload("res://addons/vng_test/reporters/console_reporter.gd")
const JsonReporter := preload("res://addons/vng_test/reporters/json_reporter.gd")

var tree: SceneTree
var opts: Dictionary = {}
var model: Dictionary = {"schema": 1, "suites": [], "planned_files": []}

var _json_path := ""
var _quiet := false
var _watchdog_token := 0
var _current_suite: Dictionary = {}
var _current_test: Dictionary = {}
var _json_write_failed := false


func run(files: PackedStringArray) -> int:
	_quiet = opts.get("quiet", false)
	_json_path = opts.get("json_out", "")
	VngRunContext.seed = opts.get("seed", 0)
	VngRunContext.timeout_sec = opts.get("timeout", 10.0)
	VngRunContext.root = opts.get("root", "res://tests")
	VngRunContext.report_dir = opts.get("report_dir", "res://test-results")
	VngRunContext.tree = tree
	VngRunContext.update_traces = opts.get("update_traces", false)
	model["planned_files"] = Array(files)
	_write_model()
	for file_path in files:
		await _run_file(file_path)
	return 1 if _has_failures() else 0


func _run_file(file_path: String) -> void:
	var suite := {
		"name": Discovery.suite_name(file_path, opts.get("root", "res://tests")),
		"file": file_path,
		"status": "pending",
		"duration_ms": 0,
		"tests": [],
	}
	model.suites.append(suite)
	_current_suite = suite
	var started_ms := Time.get_ticks_msec()

	if not FileAccess.file_exists(file_path):
		_fail_suite(suite, "test file not found")
		return
	var source := FileAccess.get_file_as_string(file_path)
	var meta := Discovery.parse_source(source)
	var script: GDScript = load(file_path)
	if script == null or not script.can_instantiate():
		_fail_suite(suite, "failed to load script (parse error?)")
		return
	var instance: Object = script.new()
	if not (instance is VngTestBase):
		_fail_suite(suite, "script must extend VngTest")
		return

	suite.tests = _enumerate(instance, meta, file_path)

	var file_skip: String = meta.get("file_skip", "")
	if file_skip != "":
		for test in suite.tests:
			test.status = "skipped"
			test.message = file_skip
		_finish_suite(suite, started_ms)
		return

	instance.failures.clear()
	await _call(instance, "before_all")
	if not instance.failures.is_empty():
		_fail_suite(suite, "before_all failed", instance.failures.duplicate(true))
		_finish_suite(suite, started_ms)
		return

	for test in suite.tests:
		if test.status == "pending":
			await _run_test(instance, suite, test, meta)

	instance.failures.clear()
	await _call(instance, "after_all")
	if not instance.failures.is_empty():
		var setup_failures: Array = suite.get("setup_failures", [])
		setup_failures.append_array(instance.failures.duplicate(true))
		suite["setup_failures"] = setup_failures
		suite["status"] = "error"

	_finish_suite(suite, started_ms)


func _run_test(instance: Object, suite: Dictionary, test: Dictionary, meta: Dictionary) -> void:
	_current_test = test
	var test_meta: Dictionary = meta.get("tests", {}).get(test.name, {})
	var skip_reason: String = test_meta.get("skip", "")
	if skip_reason != "":
		test.status = "skipped"
		test.message = skip_reason
		_report_test(test)
		_finish_suite_light(suite)
		return

	instance.failures.clear()
	var started_usec := Time.get_ticks_usec()
	_start_watchdog()
	await _call(instance, "before_each")
	await _call(instance, test.name)
	await _call(instance, "after_each")
	_stop_watchdog()
	test.duration_ms = int((Time.get_ticks_usec() - started_usec) / 1000)

	if instance.failures.is_empty():
		test.status = "passed"
	else:
		test.status = "failed"
		test.failures = instance.failures.duplicate(true)
		test.message = test.failures[0].get("message", "")
		if test.failures[0].has("expected"):
			test["expected"] = test.failures[0]["expected"]
			test["actual"] = test.failures[0]["actual"]
	_report_test(test)
	_finish_suite_light(suite)


func _enumerate(instance: Object, meta: Dictionary, file_path: String) -> Array:
	var entries: Array = []
	var root: String = opts.get("root", "res://tests")
	var implicit_tag := Discovery.dir_tag(file_path, root)
	var file_tags: Array = meta.get("file_tags", [])
	var patterns: Array = opts.get("filter", [])
	var tag_filter: Array = opts.get("tags", [])
	var only_ids: Array = opts.get("only_ids", [])
	var test_meta: Dictionary = meta.get("tests", {})
	for method in instance.get_method_list():
		var name: String = method.get("name", "")
		if not name.begins_with("test_"):
			continue
		if not Discovery.test_matches_filter(file_path, name, patterns):
			continue
		var tags := _effective_tags(implicit_tag, file_tags, test_meta.get(name, {}).get("tags", []))
		if not tag_filter.is_empty() and not _has_any_tag(tags, tag_filter):
			continue
		var id := Discovery.test_id(file_path, name)
		if not only_ids.is_empty() and not only_ids.has(id):
			continue
		var entry := {
			"id": id,
			"name": name,
			"file": file_path,
			"status": "pending",
			"duration_ms": 0,
			"tags": tags,
			"message": "",
			"failures": [],
		}
		if method.get("args", []).size() > 0:
			entry.status = "failed"
			entry.message = "test methods must take no arguments"
			entry.failures = [{"message": entry.message, "location": id}]
		entries.append(entry)
	entries.sort_custom(func(a, b): return a.name < b.name)
	return entries


func _effective_tags(implicit_tag: String, file_tags: Array, method_tags: Array) -> Array:
	var tags: Array = []
	for tag in ([implicit_tag] + file_tags + method_tags):
		var value: String = tag
		if value != "" and not tags.has(value):
			tags.append(value)
	return tags


func _has_any_tag(tags: Array, wanted: Array) -> bool:
	for tag in wanted:
		if tags.has(tag):
			return true
	return false


func _call(instance: Object, method: String) -> void:
	if not instance.has_method(method):
		return
	await instance.call(method)


func _start_watchdog() -> void:
	_watchdog_token += 1
	var token := _watchdog_token
	var timer := tree.create_timer(opts.get("timeout", 10.0))
	timer.timeout.connect(_on_watchdog_timeout.bind(token))


func _stop_watchdog() -> void:
	_watchdog_token += 1


func _on_watchdog_timeout(token: int) -> void:
	if token != _watchdog_token:
		return
	if _current_test.is_empty() or _current_test.get("status", "pending") != "pending":
		return
	var timeout_sec: float = opts.get("timeout", 10.0)
	_current_test.status = "failed"
	_current_test.message = "timed out after %.1fs" % timeout_sec
	_current_test.failures = [{"message": _current_test.message, "location": _current_test.id}]
	for test in _current_suite.get("tests", []):
		if test.get("status", "pending") == "pending":
			test.status = "failed"
			test.message = "not run (previous test timed out)"
			test.failures = [{"message": test.message, "location": test.id}]
	_current_suite.status = "failed"
	_write_model()
	printerr("TIMEOUT %s (%s)" % [_current_test.id, _current_test.message])
	tree.quit(1)


func _report_test(test: Dictionary) -> void:
	if _quiet:
		return
	print(ConsoleReporter.test_line(test))
	if test.status == "failed":
		for line in ConsoleReporter.failure_lines(test.failures):
			print(line)


func _finish_suite_light(suite: Dictionary) -> void:
	_update_suite_status(suite)
	_write_model()


func _finish_suite(suite: Dictionary, started_ms: int) -> void:
	suite.duration_ms = Time.get_ticks_msec() - started_ms
	_update_suite_status(suite)
	_write_model()


func _update_suite_status(suite: Dictionary) -> void:
	if suite.get("status", "") == "error" and not suite.get("setup_failures", []).is_empty():
		return
	var any_failed := false
	var any_pending := false
	var all_skipped := true
	for test in suite.get("tests", []):
		match test.get("status", "pending"):
			"failed":
				any_failed = true
				all_skipped = false
			"pending":
				any_pending = true
				all_skipped = false
			"passed":
				all_skipped = false
	if any_pending:
		suite.status = "pending"
	elif any_failed:
		suite.status = "failed"
	elif all_skipped and not suite.get("tests", []).is_empty():
		suite.status = "skipped"
	else:
		suite.status = "passed"


func _fail_suite(suite: Dictionary, message: String, failures: Array = []) -> void:
	suite.status = "error"
	var setup_failures: Array = suite.get("setup_failures", [])
	if failures.is_empty():
		setup_failures.append({"message": message, "location": suite.get("file", "")})
	else:
		setup_failures.append_array(failures)
	suite["setup_failures"] = setup_failures
	for test in suite.get("tests", []):
		if test.get("status", "pending") == "pending":
			test.status = "failed"
			test.message = "not run (%s)" % message
			test.failures = [{"message": test.message, "location": test.id}]


func _write_model() -> void:
	if _json_path == "":
		return
	var error := JsonReporter.write_to(_json_path, model)
	if error != OK and not _json_write_failed:
		_json_write_failed = true
		printerr("无法写入子进程结果 JSON: %s (%s)" % [_json_path, error_string(error)])


func _has_failures() -> bool:
	for suite in model.suites:
		if suite.get("status", "") == "error":
			return true
		for test in suite.get("tests", []):
			if test.get("status", "") == "failed":
				return true
	return false
