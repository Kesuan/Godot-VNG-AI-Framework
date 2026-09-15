# @tag fast
extends VngTest

const Compiler := preload("res://addons/vns/vns_compiler.gd")


func test_basic_fixture_is_clean() -> void:
	var result := Compiler.compile_story("res://tests/fixtures/story_basic")
	assert_eq((result.errors as Array).size(), 0, _messages(result.errors))
	assert_eq((result.warnings as Array).size(), 0, _messages(result.warnings))


func test_broken_fixture_reports_expected_diagnostics() -> void:
	var result := Compiler.compile_story("res://tests/fixtures/story_broken")
	assert_false(result.ok)
	assert_true(_contains(result.errors, "跳转目标不存在: 'gret'（是否想写 'greet'？）"))
	assert_true(_contains(result.errors, "条件引用了未定义的 flag/变量: 'met_yyuki'（是否想写 'met_yuki'？）"))
	assert_true(_contains(result.errors, "角色未在 story.json 中登记: 'ghost'"))
	assert_true(_contains(result.errors, "背景资源不存在（清单见 story.json）: 'missing_bg'"))
	assert_true(_contains(result.warnings, "不可达"))
	assert_true(_contains(result.warnings, "从未在条件中读取"))


func test_diagnostics_have_source_locations() -> void:
	var result := Compiler.compile_story("res://tests/fixtures/story_broken")
	for diagnostic in result.errors:
		assert_ne(diagnostic.get("file", ""), "")
		assert_true(int(diagnostic.get("line", 0)) > 0)
		assert_eq(diagnostic.get("severity", ""), "error")


func _messages(diagnostics: Array) -> String:
	var lines := PackedStringArray()
	for diagnostic in diagnostics:
		lines.append("%s: %s" % [diagnostic.get("file", ""), diagnostic.get("message", "")])
	return "\n".join(lines)


func _contains(diagnostics: Array, needle: String) -> bool:
	for diagnostic in diagnostics:
		if (diagnostic.get("message", "") as String).contains(needle):
			return true
	return false
