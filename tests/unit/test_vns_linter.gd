# @tag fast
extends VngTest

const Compiler := preload("res://addons/vns/vns_compiler.gd")
const Linter := preload("res://addons/vns/vns_linter.gd")


func test_basic_fixture_is_clean() -> void:
	var result := Compiler.compile_story("res://tests/fixtures/story_basic")
	assert_eq((result.errors as Array).size(), 0, _messages(result.errors))
	assert_eq((result.warnings as Array).size(), 0, _messages(result.warnings))


func test_multi_chapter_fixture_is_clean() -> void:
	var result := Compiler.compile_story("res://tests/fixtures/story_multi")
	assert_eq((result.errors as Array).size(), 0, _messages(result.errors))
	assert_eq((result.warnings as Array).size(), 0, _messages(result.warnings))
	assert_eq((result.manifest.get("entries", {}) as Dictionary).size(), 2)


func test_multi_chapter_requires_entries_for_every_chapter() -> void:
	var result := Linter.lint(_multi_chapters(), {"entry": "alpha.begin", "chapters": ["alpha", "beta"]}, "story.json")
	assert_true(_contains(result.errors, "必须为章节 'beta' 登记 entries 入口节点"))


func test_entries_bad_node_suggests_close_match() -> void:
	var manifest := {
		"entry": "alpha.begin",
		"entries": {"alpha": "begn", "beta": "finish"},
		"chapters": ["alpha", "beta"],
	}
	var result := Linter.lint(_multi_chapters(), manifest, "story.json")
	assert_true(_contains(result.errors, "章节 'alpha' 的 entries 入口节点不存在"))
	assert_true(_contains(result.errors, "是否想写 'begin'"))


func test_entries_unknown_chapter_is_rejected() -> void:
	var manifest := {
		"entry": "alpha.begin",
		"entries": {"alpha": "begin", "beta": "finish", "gamma": "nope"},
		"chapters": ["alpha", "beta"],
	}
	var result := Linter.lint(_multi_chapters(), manifest, "story.json")
	assert_true(_contains(result.errors, "entries 中的章节未在 chapters 登记: 'gamma'"))


func test_story_end_is_a_valid_target() -> void:
	var chapters := _multi_chapters()
	var alpha: Dictionary = chapters["alpha"]
	var nodes: Dictionary = alpha["nodes"]
	var begin: Dictionary = nodes["begin"]
	var steps: Array = begin["steps"]
	steps[1] = {"op": "goto", "target": "STORY_END"}
	var result := Linter.lint(chapters, {"entry": "alpha.begin", "chapters": ["alpha", "beta"]}, "story.json")
	assert_false(_contains(result.errors, "跳转目标不存在"))


func _endings_chapters() -> Dictionary:
	return {
		"gamma": {
			"chapter": "gamma",
			"nodes": {
				"end": {
					"id": "end",
					"steps": [
						{"op": "say", "who": "", "text": "x", "src": {"file": "g.vns", "line": 3}},
						{"op": "ending", "id": "good_end", "src": {"file": "g.vns", "line": 4}},
						{"op": "goto", "target": "END"},
					],
				},
			},
		},
	}


func test_ending_must_be_registered_with_suggestion() -> void:
	var manifest := {"entry": "gamma.end", "chapters": ["gamma"], "endings": {"good_end": {"title": "好结局"}}}
	var chapters := _endings_chapters()
	var gamma: Dictionary = chapters["gamma"]
	var nodes: Dictionary = gamma["nodes"]
	var node: Dictionary = nodes["end"]
	var steps: Array = node["steps"]
	steps[1] = {"op": "ending", "id": "god_end", "src": {"file": "g.vns", "line": 4}}
	var result := Linter.lint(chapters, manifest, "story.json")
	assert_true(_contains(result.errors, "结局未在 story.json 的 endings 中登记"))
	assert_true(_contains(result.errors, "是否想写 'good_end'"))


func test_unused_registered_ending_warns() -> void:
	var manifest := {
		"entry": "gamma.end",
		"chapters": ["gamma"],
		"endings": {"good_end": {"title": "好"}, "unused_end": {"title": "未用"}},
	}
	var result := Linter.lint(_endings_chapters(), manifest, "story.json")
	assert_true(_contains(result.warnings, "结局 'unused_end' 已登记但没有任何 @ending 引用"))
	assert_false(_contains(result.errors, "结局未在 story.json 的 endings 中登记"))


func _multi_chapters() -> Dictionary:
	return {
		"alpha": {
			"chapter": "alpha",
			"nodes": {
				"begin": {
					"id": "begin",
					"steps": [
						{"op": "say", "who": "", "text": "a"},
						{"op": "goto", "target": "END"},
					],
				},
			},
		},
		"beta": {
			"chapter": "beta",
			"nodes": {
				"finish": {
					"id": "finish",
					"steps": [
						{"op": "say", "who": "", "text": "b"},
						{"op": "goto", "target": "END"},
					],
				},
			},
		},
	}


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
