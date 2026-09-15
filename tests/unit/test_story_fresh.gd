# @tag fast
extends VngTest

const Compiler := preload("res://addons/vns/vns_compiler.gd")


func test_game_story_compiled_artifacts_are_fresh() -> void:
	var result := Compiler.check_story("res://game/story")
	assert_eq((result.errors as Array).size(), 0, _messages(result.errors))
	assert_eq((result.get("stale", []) as Array).size(), 0, "编译产物过期，请运行 tools/story build")
	assert_eq((result.get("missing", []) as Array).size(), 0, "缺少编译产物，请运行 tools/story build")


func _messages(diagnostics: Array) -> String:
	var lines := PackedStringArray()
	for diagnostic in diagnostics:
		lines.append("%s:%d: %s" % [
			diagnostic.get("file", ""),
			int(diagnostic.get("line", 0)),
			diagnostic.get("message", ""),
		])
	return "\n".join(lines)
