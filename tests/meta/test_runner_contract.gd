# @tag meta
extends VngTest


func test_pass_fixture_exits_zero() -> void:
	var result := _run_fixture("pass_case", "res://tests/meta/fixtures", ["--filter", "test_pass_case"])
	assert_eq(result.exit, 0)
	assert_eq(result.model.get("summary", {}).get("total", 0), 2)
	assert_eq(result.model.get("summary", {}).get("passed", 0), 2)


func test_fail_fixture_reports_location_and_values() -> void:
	var result := _run_fixture("fail_case", "res://tests/meta/fixtures", ["--filter", "test_fail_case"])
	assert_eq(result.exit, 1)
	var test: Variant = _find_test(result.model, "test_fails")
	if test == null:
		fail("fixture test_fails not found in results")
		return
	assert_eq(test.get("status", ""), "failed")
	var failures: Array = test.get("failures", [])
	if failures.is_empty():
		fail("no failure entries recorded")
		return
	var failure: Dictionary = failures[0]
	assert_eq(failure.get("expected", ""), "42")
	assert_eq(failure.get("actual", ""), "43")
	assert_true((failure.get("location", "") as String).contains("test_fail_case.gd"))


func test_soft_timeout_marks_test_failed() -> void:
	var result := _run_fixture("hang_await", "res://tests/meta/fixtures", ["--filter", "test_hang_await_case", "--timeout", "1"])
	assert_eq(result.exit, 1)
	var test: Variant = _find_test(result.model, "test_awaits_forever")
	if test == null:
		fail("fixture test_awaits_forever not found in results")
		return
	assert_eq(test.get("status", ""), "failed")
	assert_true((test.get("message", "") as String).contains("timed out"))


func test_hard_timeout_kills_blocking_test() -> void:
	var result := _run_fixture("hang_block", "res://tests/meta/fixtures", ["--filter", "test_hang_block_case", "--timeout", "1", "--hard-timeout", "3"])
	assert_eq(result.exit, 1)
	var test: Variant = _find_test(result.model, "test_hangs")
	if test == null:
		fail("fixture test_hangs not found in results")
		return
	assert_eq(test.get("status", ""), "failed")
	assert_true((test.get("message", "") as String).contains("not run"))


func test_skip_annotation() -> void:
	var result := _run_fixture("skip_case", "res://tests/meta/fixtures", ["--filter", "test_skip_case"])
	assert_eq(result.exit, 0)
	assert_eq(result.model.get("summary", {}).get("skipped", 0), 1)
	assert_eq(result.model.get("summary", {}).get("passed", 0), 1)


func test_engine_error_prevents_false_green() -> void:
	var result := _run_fixture("error_case", "res://tests/meta/fixtures", ["--filter", "test_error_case"])
	assert_eq(result.exit, 1)
	assert_true(result.model.get("summary", {}).get("errors", 0) >= 1)


func test_no_tests_exit_three() -> void:
	var result := _run_fixture("empty", "res://tests/meta/empty_fixtures", [])
	assert_eq(result.exit, 3)
	assert_eq(result.model.get("summary", {}).get("total", 0), 0)


func test_min_tests_guard() -> void:
	var result := _run_fixture("min_tests", "res://tests/meta/fixtures", ["--filter", "test_pass_case", "--min-tests", "99"])
	assert_eq(result.exit, 2)


func test_method_filter_selects_single_test() -> void:
	var result := _run_fixture("method_filter", "res://tests/meta/fixtures", ["--filter", "test_pass_case.gd::test_one"])
	assert_eq(result.exit, 0)
	assert_eq(result.model.get("summary", {}).get("total", 0), 1)


func test_seed_propagates_to_report() -> void:
	var result := _run_fixture("seed_case", "res://tests/meta/fixtures", ["--filter", "test_pass_case", "--seed", "7"])
	assert_eq(result.exit, 0)
	assert_eq(result.model.get("run", {}).get("seed", -1), 7)


func test_isolate_all_runs_each_file_in_own_process() -> void:
	var result := _run_fixture("isolate_all", "res://tests/meta/fixtures", ["--isolate-all", "--filter", "test_pass_case", "--filter", "test_skip_case"])
	assert_eq(result.exit, 0)
	assert_eq(result.model.get("summary", {}).get("total", 0), 4)


func test_rerun_selects_previous_failures() -> void:
	var first := _run_fixture("rerun_case", "res://tests/meta/fixtures", ["--filter", "test_fail_case"])
	assert_eq(first.exit, 1)
	var second := _run_fixture("rerun_case", "res://tests/meta/fixtures", ["--filter", "test_fail_case", "--rerun"])
	assert_eq(second.exit, 1)
	assert_eq(second.model.get("summary", {}).get("total", 0), 1)


func test_rerun_without_previous_failures_exits_three() -> void:
	var first := _run_fixture("rerun_clean", "res://tests/meta/fixtures", ["--filter", "test_pass_case"])
	assert_eq(first.exit, 0)
	var second := _run_fixture("rerun_clean", "res://tests/meta/fixtures", ["--filter", "test_pass_case", "--rerun"])
	assert_eq(second.exit, 3)


func test_flake_check_stable_suite() -> void:
	var result := _run_fixture("flake_stable", "res://tests/meta/fixtures", ["--filter", "test_pass_case", "--flake-check"])
	assert_eq(result.exit, 0)
	assert_true(result.model.get("flake", {}).get("stable", false))


func test_flake_check_detects_flaky_test() -> void:
	_reset_flake_marker()
	var result := _run_fixture("flake_flaky", "res://tests/meta/fixtures", ["--filter", "test_flaky_case", "--flake-check"])
	assert_eq(result.exit, 1)
	assert_false(result.model.get("flake", {}).get("stable", true))
	assert_true((result.model.get("flake", {}).get("differences", []) as Array).size() > 0)
	_reset_flake_marker()


func _reset_flake_marker() -> void:
	var marker := "user://vng_test/flaky_marker.txt"
	if FileAccess.file_exists(marker):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker))


func _run_fixture(name: String, root: String, extra: Array) -> Dictionary:
	var report_dir := "user://vng_meta/%s" % name
	var args := PackedStringArray([
		"--headless", "--no-header",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://addons/vng_test/cli/run_tests.gd",
		"--",
		"--root", root,
		"--report-dir", report_dir,
		"--jobs", "1",
		"--quiet",
	])
	for item in extra:
		args.append(item)
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
	var model := {}
	var json_path := report_dir.path_join("results.json")
	if FileAccess.file_exists(json_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed is Dictionary:
			model = parsed
	return {"exit": exit_code, "model": model}


func _find_test(model: Dictionary, test_name: String) -> Variant:
	for suite in model.get("suites", []):
		for test in suite.get("tests", []):
			if test.get("name", "") == test_name:
				return test
	return null
