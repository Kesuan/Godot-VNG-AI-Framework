# @tag story
extends VngTest

const Compiler := preload("res://addons/vns/vns_compiler.gd")

var _chapter: Dictionary = {}


func before_all() -> void:
	var result := Compiler.compile_story("res://game/story")
	if not result.ok:
		fail("剧本编译失败:\n%s" % _format(result.errors))
		return
	_chapter = result.chapters.get("chapter1", {})
	if _chapter.is_empty():
		fail("编译结果缺少 chapter1")


func test_route_secret_via_hidden_flag() -> void:
	if _chapter.is_empty():
		return
	var play := VngPlaythrough.new(_chapter, self)
	play.start_scene("prologue")
	play.expect_speaker("yuki").expect_line("早上好！")
	play.advance().expect_line("你推开了门。")
	play.advance()
	play.expect_choices(["捡起钥匙", "直接离开"])
	play.choose_text("捡起钥匙")
	play.expect_scene("pick_key").expect_flag("has_key")
	play.advance()
	play.expect_scene("hallway").expect_line("走吧。")
	play.advance()
	play.expect_choices(["打开储藏室", "离开"])
	play.choose_text("打开储藏室")
	play.expect_scene("secret").expect_flag("found_secret")
	play.advance()
	play.expect_ended()
	play.expect_no_errors()
	play.expect_trace("chapter1_secret")


func test_route_leave_hides_secret() -> void:
	if _chapter.is_empty():
		return
	var play := VngPlaythrough.new(_chapter, self)
	play.start_scene("prologue")
	play.advance().advance()
	play.expect_choices(["捡起钥匙", "直接离开"])
	play.choose_text("直接离开")
	play.expect_scene("hallway")
	play.advance()
	play.expect_choices(["离开"])
	play.choose_text("离开")
	play.expect_ended()
	play.expect_no_errors()
	play.expect_trace("chapter1_leave")


func test_compiled_steps_keep_source_provenance() -> void:
	if _chapter.is_empty():
		return
	var nodes: Dictionary = _chapter.get("nodes", {})
	var prologue: Dictionary = nodes.get("prologue", {})
	var steps: Array = prologue.get("steps", [])
	assert_true(steps.size() > 0)
	var first: Dictionary = steps[0]
	assert_eq(first.get("src", {}).get("file", ""), "res://game/story/chapter1.vns")
	assert_true(int(first.get("src", {}).get("line", 0)) > 0)


func _format(diagnostics: Array) -> String:
	var lines := PackedStringArray()
	for diagnostic in diagnostics:
		lines.append("%s:%d: %s" % [
			diagnostic.get("file", ""),
			int(diagnostic.get("line", 0)),
			diagnostic.get("message", ""),
		])
	return "\n".join(lines)
