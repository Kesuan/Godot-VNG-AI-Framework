# @tag fast
extends VngTest

const Discovery := preload("res://addons/vng_test/core/discovery.gd")


func test_suite_name() -> void:
	assert_eq(Discovery.suite_name("res://tests/unit/test_rng.gd", "res://tests"), "unit/rng")
	assert_eq(Discovery.suite_name("res://tests/story/ch1/test_a.gd", "res://tests"), "story/ch1/a")
	assert_eq(Discovery.suite_name("res://tests/test_top.gd", "res://tests"), "top")


func test_dir_tag() -> void:
	assert_eq(Discovery.dir_tag("res://tests/unit/test_rng.gd", "res://tests"), "unit")
	assert_eq(Discovery.dir_tag("res://tests/test_top.gd", "res://tests"), "")


func test_test_id() -> void:
	assert_eq(Discovery.test_id("res://tests/unit/test_a.gd", "test_x"), "res://tests/unit/test_a.gd::test_x")


func test_parse_source_tags_and_skip() -> void:
	var source := "# @tag fast\n# @tag unit\nextends VngTest\n\n\n# @tag slow\n# @skip later\nfunc test_a() -> void:\n\tpass\n\n\nfunc test_b() -> void:\n\tpass\n"
	var meta := Discovery.parse_source(source)
	assert_eq(meta.file_tags, ["fast", "unit"])
	assert_eq(meta.file_skip, "")
	assert_eq(meta.tests.get("test_a", {}).get("tags", []), ["slow"])
	assert_eq(meta.tests.get("test_a", {}).get("skip", ""), "later")
	assert_eq(meta.tests.get("test_b", {}).get("tags", []), [])
	assert_eq(meta.tests.size(), 2)


func test_parse_source_file_skip() -> void:
	var source := "# @skip whole file\nextends VngTest\n\n\nfunc test_a() -> void:\n\tpass\n"
	var meta := Discovery.parse_source(source)
	assert_eq(meta.file_skip, "whole file")


func test_matches_pattern() -> void:
	assert_true(Discovery.matches_pattern("unit/*", "res://tests/unit/test_a.gd"))
	assert_true(Discovery.matches_pattern("test_a", "res://tests/unit/test_a.gd::test_a"))
	assert_false(Discovery.matches_pattern("*nope*", "res://tests/unit/test_a.gd"))


func test_file_matches_filter() -> void:
	assert_true(Discovery.file_matches_filter("res://tests/unit/test_a.gd", []))
	assert_true(Discovery.file_matches_filter("res://tests/unit/test_a.gd", ["unit/"]))
	assert_true(Discovery.file_matches_filter("res://tests/unit/test_a.gd", ["test_a"]))
	assert_false(Discovery.file_matches_filter("res://tests/unit/test_a.gd", ["story/"]))
