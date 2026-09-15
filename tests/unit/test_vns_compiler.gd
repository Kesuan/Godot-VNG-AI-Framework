# @tag fast
extends VngTest

const Compiler := preload("res://addons/vns/vns_compiler.gd")


func test_build_writes_compiled_artifacts() -> void:
	var output := "user://vng_test/compiled_artifacts"
	_clean_dir(output)
	var result := Compiler.build_story("res://tests/fixtures/story_basic", output)
	assert_true(result.ok, str(result.errors))
	assert_eq((result.get("written", []) as Array).size(), 1)
	var path := output.path_join("chapter_basic.json")
	assert_true(FileAccess.file_exists(path))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary)
	assert_eq(parsed.get("chapter", ""), "chapter_basic")
	assert_ne(parsed.get("source_hash", ""), "")
	var check := Compiler.check_story("res://tests/fixtures/story_basic", output)
	assert_true(check.ok, str(check.get("stale", [])) + str(check.get("missing", [])))


func test_check_detects_stale_artifact() -> void:
	var output := "user://vng_test/compiled_stale"
	_clean_dir(output)
	assert_true(Compiler.build_story("res://tests/fixtures/story_basic", output).ok)
	var path := output.path_join("chapter_basic.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var chapter: Dictionary = parsed
	chapter["source_hash"] = "stale"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(chapter))
	file.close()
	var check := Compiler.check_story("res://tests/fixtures/story_basic", output)
	assert_false(check.ok)
	assert_eq((check.get("stale", []) as Array).size(), 1)


func test_check_detects_missing_artifact() -> void:
	var output := "user://vng_test/compiled_missing"
	_clean_dir(output)
	var check := Compiler.check_story("res://tests/fixtures/story_basic", output)
	assert_false(check.ok)
	assert_eq((check.get("missing", []) as Array).size(), 1)


func test_broken_story_fails_build() -> void:
	var result := Compiler.build_story("res://tests/fixtures/story_broken", "user://vng_test/compiled_broken")
	assert_false(result.ok)
	assert_eq((result.get("written", []) as Array).size(), 0)


func test_unregistered_chapter_file_is_error() -> void:
	var result := Compiler.compile_story("res://tests/fixtures/story_unlisted")
	assert_false(result.ok)
	assert_true(_contains(result.errors, "未在 story.json 的 chapters 中登记"))


func _contains(diagnostics: Array, needle: String) -> bool:
	for diagnostic in diagnostics:
		if (diagnostic.get("message", "") as String).contains(needle):
			return true
	return false


func _clean_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute)
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
