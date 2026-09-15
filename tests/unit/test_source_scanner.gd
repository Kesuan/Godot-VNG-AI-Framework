# @tag fast
extends VngTest

const Scanner := preload("res://addons/vng_test/lint/source_scanner.gd")


func test_detects_global_randi() -> void:
	var hits := Scanner.scan_source("var x = randi()\n")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].get("symbol", ""), "randi")


func test_detects_global_randf_and_range() -> void:
	var hits := Scanner.scan_source("var a = randf()\nvar b = randi_range(1, 3)\n")
	assert_eq(hits.size(), 2)
	assert_eq(hits[0].get("symbol", ""), "randf")
	assert_eq(hits[1].get("symbol", ""), "randi_range")


func test_allows_method_calls_on_rng_service() -> void:
	var hits := Scanner.scan_source("var x = services.rng.next_int()\nservices.rng.seed_value()\n")
	assert_eq(hits.size(), 0)


func test_detects_time_api() -> void:
	var hits := Scanner.scan_source("var t = Time.get_ticks_msec()\n")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].get("symbol", ""), "Time")


func test_detects_os_ticks() -> void:
	var hits := Scanner.scan_source("var t = OS.get_ticks_usec()\n")
	assert_eq(hits.size(), 1)


func test_ignores_comments_and_strings() -> void:
	var hits := Scanner.scan_source("# randi() in comment\nvar s = \"Time.get_ticks_msec()\"\nvar c = '# randf()'\n")
	assert_eq(hits.size(), 0)


func test_reports_line_and_column() -> void:
	var hits := Scanner.scan_source("var a = 1\nvar b = randf()\n")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].get("line", 0), 2)
	assert_eq(hits[0].get("column", 0), 9)


func test_scan_file_reports_path() -> void:
	var hits := Scanner.scan_file("res://tests/meta/fixtures/test_pass_case.gd")
	assert_eq(hits.size(), 0)
