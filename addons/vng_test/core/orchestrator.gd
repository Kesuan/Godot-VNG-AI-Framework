extends RefCounted

const Discovery := preload("res://addons/vng_test/core/discovery.gd")
const ConsoleReporter := preload("res://addons/vng_test/reporters/console_reporter.gd")
const JsonReporter := preload("res://addons/vng_test/reporters/json_reporter.gd")
const JunitReporter := preload("res://addons/vng_test/reporters/junit_reporter.gd")

var opts: Dictionary = {}

var _child_counter := 0


func run() -> int:
	var started_ms := Time.get_ticks_msec()
	var report_dir: String = opts.get("report_dir", "res://test-results")
	var artifacts_dir := report_dir.path_join("artifacts")
	_prepare_dir(artifacts_dir)

	var files := Discovery.find_test_files(opts.get("root", "res://tests"))
	files = _filter_files(files)
	if opts.get("rerun", false):
		files = _filter_rerun(files)

	if files.is_empty():
		printerr("未发现测试: %s/**/test_*.gd" % opts.get("root", "res://tests"))
		printerr("退出码 3 = 未发现任何测试（防\"假绿\"，见 docs/plans/0001-test-framework-v1.md）")
		return 3

	var groups := _make_groups(files)
	if not opts.get("json", false):
		print("VNG test run: %d file(s), %d group(s) (seed=%d, jobs=%d)" % [
			files.size(), groups.size(), opts.get("seed", 0), opts.get("jobs", 1)
		])

	var suites := _run_groups(groups, artifacts_dir)

	var flake := {}
	if opts.get("flake_check", false):
		var flake_artifacts := report_dir.path_join("artifacts-flake")
		_prepare_dir(flake_artifacts)
		_child_counter = 0
		var second_started := Time.get_ticks_msec()
		var second_suites := _run_groups(groups, flake_artifacts)
		var second_model := _build_model(second_suites, Time.get_ticks_msec() - second_started)
		JsonReporter.write_to(report_dir.path_join("flake-results.json"), second_model)
		flake = _compare_flake(suites, second_suites)
		if not opts.get("json", false):
			_print_flake(flake)

	suites.sort_custom(func(a, b): return a.get("file", "") < b.get("file", ""))

	var duration_ms := Time.get_ticks_msec() - started_ms
	var model := _build_model(suites, duration_ms)
	if not flake.is_empty():
		model["flake"] = flake
	var results_path: String = report_dir.path_join("results.json")
	var junit_path: String = report_dir.path_join("junit.xml")
	var write_error := JsonReporter.write_to(results_path, model)
	if write_error == OK:
		write_error = JunitReporter.write_to(junit_path, model)
	if write_error != OK:
		printerr("无法写入测试报告: %s" % error_string(write_error))
		return 2

	if opts.get("json", false):
		print(JsonReporter.to_string_pretty(model))
	else:
		_print_summary(model, results_path, junit_path, artifacts_dir)

	var summary: Dictionary = model.summary
	if summary.total == 0:
		printerr("未发现任何测试用例（过滤器可能排除了全部）")
		return 3
	if summary.total < opts.get("min_tests", 0):
		printerr("测试用例数 %d 低于 --min-tests %d 要求" % [summary.total, opts.get("min_tests", 0)])
		return 2
	if summary.failed > 0 or summary.errors > 0:
		return 1
	if not flake.is_empty() and not (flake.get("stable", true) as bool):
		return 1
	return 0


func _filter_files(files: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	var root: String = opts.get("root", "res://tests")
	var patterns: Array = opts.get("filter", [])
	for file_path in files:
		if opts.get("fast", false) and not file_path.begins_with(root + "/unit/"):
			continue
		if not Discovery.file_matches_filter(file_path, patterns):
			continue
		result.append(file_path)
	return result


func _filter_rerun(files: PackedStringArray) -> PackedStringArray:
	var previous := JsonReporter.read_from(opts.get("report_dir", "res://test-results").path_join("results.json"))
	var failed_ids: Array = []
	for suite in previous.get("suites", []):
		for test in suite.get("tests", []):
			if test.get("status", "") == "failed":
				failed_ids.append(test.get("id", ""))
	if failed_ids.is_empty():
		return PackedStringArray()
	opts["only_ids"] = failed_ids
	var result := PackedStringArray()
	for file_path in files:
		for id in failed_ids:
			if (id as String).begins_with(file_path + "::"):
				result.append(file_path)
				break
	return result


func _make_groups(files: PackedStringArray) -> Array:
	var isolated: bool = opts.get("isolate_all", false)
	var groups: Array = []
	var batch := PackedStringArray()
	for file_path in files:
		if isolated or file_path.contains("/story/"):
			groups.append(PackedStringArray([file_path]))
		else:
			batch.append(file_path)
	if not batch.is_empty():
		groups.append(batch)
	return groups


func _run_groups(groups: Array, artifacts_dir: String) -> Array:
	var pending: Array = groups.duplicate()
	var running: Array = []
	var suites: Array = []
	while not pending.is_empty() or not running.is_empty():
		while running.size() < opts.get("jobs", 1) and not pending.is_empty():
			running.append(_spawn(pending.pop_front(), artifacts_dir))
		for entry in running.duplicate():
			var pid: int = entry.pid
			if pid <= 0:
				running.erase(entry)
				suites.append_array(_collect(entry))
			elif not OS.is_process_running(pid):
				running.erase(entry)
				entry.exit_code = OS.get_process_exit_code(pid)
				suites.append_array(_collect(entry))
			elif not entry.killed and Time.get_ticks_msec() > entry.hard_deadline_ms:
				entry.killed = true
				OS.kill(pid)
		if not pending.is_empty() or not running.is_empty():
			OS.delay_msec(30)
	return suites


func _spawn(group: PackedStringArray, artifacts_dir: String) -> Dictionary:
	var index := _child_counter
	_child_counter += 1
	var json_path := artifacts_dir.path_join("child_%02d.json" % index)
	var log_path := artifacts_dir.path_join("child_%02d.engine.log" % index)
	var args := PackedStringArray([
		"--headless", "--no-header",
		"--log-file", _globalize(log_path),
		"--path", _globalize("res://"),
		"--script", "res://addons/vng_test/cli/run_tests.gd",
		"--",
		"--child",
		"--json-out", json_path,
		"--root", opts.get("root", "res://tests"),
		"--timeout", str(opts.get("timeout", 10.0)),
		"--seed", str(opts.get("seed", 0)),
		"--report-dir", opts.get("report_dir", "res://test-results"),
	])
	if opts.get("quiet", false) or opts.get("json", false):
		args.append("--quiet")
	if opts.get("update_traces", false):
		args.append("--update-traces")
	var tags: Array = opts.get("tags", [])
	if not tags.is_empty():
		args.append("--tags")
		args.append(",".join(PackedStringArray(tags)))
	for pattern in opts.get("filter", []):
		args.append("--filter")
		args.append(pattern)
	var only_ids: Array = opts.get("only_ids", [])
	if not only_ids.is_empty():
		args.append("--only-ids")
		args.append(",".join(PackedStringArray(only_ids)))
	args.append_array(group)
	var pid := OS.create_process(OS.get_executable_path(), args)
	return {
		"pid": pid,
		"group": group,
		"json_path": json_path,
		"log_path": log_path,
		"hard_deadline_ms": Time.get_ticks_msec() + int(opts.get("hard_timeout", 300.0) * 1000.0),
		"killed": false,
		"exit_code": -1,
	}


func _collect(entry: Dictionary) -> Array:
	var suites: Array = []
	var raw := JsonReporter.read_from(entry.json_path)
	var reason := "not run: runner process "
	if entry.killed:
		reason += "killed by hard timeout"
	elif entry.exit_code != 0:
		reason += "exited with code %d" % entry.exit_code
	else:
		reason += "terminated before finishing"
	if raw.is_empty():
		for file_path in entry.group:
			suites.append(_synthesize_suite(file_path, reason))
		_scan_engine_log(suites, entry.log_path)
		return suites

	suites = raw.get("suites", [])
	var seen := {}
	for suite in suites:
		seen[suite.get("file", "")] = true
		suite["log"] = entry.log_path
		suite["engine_errors"] = 0
	for file_path in entry.group:
		if not seen.has(file_path):
			suites.append(_synthesize_suite(file_path, reason))
	for suite in suites:
		for test in suite.get("tests", []):
			if test.get("status", "") == "pending":
				test.status = "failed"
				test.message = reason
				test.failures = [{"message": reason, "location": test.get("id", "")}]
		if suite.get("status", "") == "pending":
			suite["status"] = "failed"
	_scan_engine_log(suites, entry.log_path)
	return suites


func _synthesize_suite(file_path: String, reason: String) -> Dictionary:
	return {
		"name": Discovery.suite_name(file_path, opts.get("root", "res://tests")),
		"file": file_path,
		"status": "error",
		"duration_ms": 0,
		"tests": [],
		"engine_errors": 0,
		"setup_failures": [{"message": reason, "location": file_path}],
	}


func _scan_engine_log(suites: Array, log_path: String) -> void:
	var absolute := _globalize(log_path)
	if not FileAccess.file_exists(absolute):
		return
	var text := FileAccess.get_file_as_string(absolute)
	if text.is_empty() or not text.contains("SCRIPT ERROR"):
		return
	var error_blocks := _error_blocks(text)
	if error_blocks.is_empty():
		return
	var count := error_blocks.size()
	var first_block: String = error_blocks[0] if error_blocks.size() > 0 else ""
	var matched := false
	for suite in suites:
		var suite_file: String = suite.get("file", "")
		if suite_file == "":
			continue
		for block in error_blocks:
			if (block as String).contains(suite_file):
				_mark_engine_errors(suite, count, log_path, first_block)
				matched = true
				break
	if not matched:
		for suite in suites:
			_mark_engine_errors(suite, count, log_path, first_block)


func _error_blocks(text: String) -> PackedStringArray:
	var blocks := PackedStringArray()
	var current := ""
	for line in text.split("\n"):
		if line.contains("SCRIPT ERROR"):
			if current != "":
				blocks.append(current)
			current = line
		elif current != "" and (line.begins_with(" ") or line.begins_with("\t")):
			current += "\n" + line
		elif current != "":
			blocks.append(current)
			current = ""
	if current != "":
		blocks.append(current)
	return blocks


func _mark_engine_errors(suite: Dictionary, count: int, log_path: String, first_block := "") -> void:
	suite["engine_errors"] = count
	if suite.get("status", "") in ["passed", "pending"]:
		suite["status"] = "error"
		var message := "engine reported %d script error(s); see %s" % [count, log_path]
		if first_block != "":
			message += "\n" + first_block
		var setup_failures: Array = suite.get("setup_failures", [])
		setup_failures.append({
			"message": message,
			"location": suite.get("file", ""),
		})
		suite["setup_failures"] = setup_failures


func _compare_flake(first: Array, second: Array) -> Dictionary:
	var a := _status_map(first)
	var b := _status_map(second)
	var ids: Array = a.keys()
	for id in b.keys():
		if not ids.has(id):
			ids.append(id)
	ids.sort()
	var differences: Array = []
	for id in ids:
		var left: String = a.get(id, "<missing>")
		var right: String = b.get(id, "<missing>")
		if left != right:
			differences.append({"id": id, "first": left, "second": right})
	return {"checked": true, "stable": differences.is_empty(), "differences": differences}


func _status_map(suites: Array) -> Dictionary:
	var map := {}
	for suite in suites:
		for test in suite.get("tests", []):
			map[test.get("id", "")] = test.get("status", "")
	return map


func _print_flake(flake: Dictionary) -> void:
	print("")
	if flake.get("stable", false):
		print("flake-check: stable（两次运行结果一致）")
		return
	var differences: Array = flake.get("differences", [])
	print("flake-check: UNSTABLE（%d 处差异）" % differences.size())
	for diff in differences:
		print("  %s: %s -> %s" % [diff.get("id", ""), diff.get("first", ""), diff.get("second", "")])


func _build_model(suites: Array, duration_ms: int) -> Dictionary:
	var summary := {"total": 0, "passed": 0, "failed": 0, "skipped": 0, "errors": 0, "duration_ms": duration_ms}
	for suite in suites:
		for test in suite.get("tests", []):
			summary.total += 1
			match test.get("status", ""):
				"passed":
					summary.passed += 1
				"failed":
					summary.failed += 1
				"skipped":
					summary.skipped += 1
		if suite.get("status", "") == "error":
			summary.errors += 1
	return {
		"schema": 1,
		"run": {
			"seed": opts.get("seed", 0),
			"godot": Engine.get_version_info().get("string", ""),
			"root": opts.get("root", "res://tests"),
			"jobs": opts.get("jobs", 1),
			"duration_ms": duration_ms,
		},
		"summary": summary,
		"suites": suites,
	}


func _print_summary(model: Dictionary, results_path: String, junit_path: String, artifacts_dir: String) -> void:
	print("")
	print(ConsoleReporter.summary_line(model.summary, opts.get("seed", 0), model.summary.duration_ms))
	var failure_lines := PackedStringArray()
	for suite in model.suites:
		if suite.get("status", "") == "error":
			for failure in suite.get("setup_failures", []):
				failure_lines.append("  %s  %s" % [suite.get("file", ""), failure.get("message", "")])
		for test in suite.get("tests", []):
			if test.get("status", "") == "failed":
				failure_lines.append("  %s  %s" % [test.get("id", ""), test.get("message", "")])
	if not failure_lines.is_empty():
		print("failed:")
		for line in failure_lines:
			print(line)
	print("artifacts:")
	print("  " + results_path)
	print("  " + junit_path)
	print("  " + artifacts_dir)


func _prepare_dir(path: String) -> void:
	var absolute := _globalize(path)
	DirAccess.make_dir_recursive_absolute(absolute)
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


func _globalize(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path
