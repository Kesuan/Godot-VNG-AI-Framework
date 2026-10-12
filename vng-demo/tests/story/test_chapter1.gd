# @tag story
extends VngTest

const Compiler := preload("res://addons/vns/vns_compiler.gd")

var _story: Dictionary = {}


func before_all() -> void:
	var result := Compiler.compile_story("res://game/story")
	if not result.ok:
		fail("剧本编译失败:\n%s" % _format(result.errors))
		return
	_story = result
	if (_story.get("chapters", {}) as Dictionary).is_empty():
		fail("编译结果缺少章节")


func test_route_umbrella_to_cafe_epilogue() -> void:
	if _story.is_empty():
		return
	var play := VngPlaythrough.for_story(_story, self)
	play.start_story()
	play.expect_chapter("chapter1").expect_line("雨点砸在站台的顶棚上，风把雨丝吹进来。")
	play.advance().expect_line("你收起伞，看见长椅旁站着一个湿透的女孩。")
	play.advance().expect_speaker("rin").expect_line("……末班车，停运了。")
	play.advance().advance()
	play.expect_choices(["把伞递过去", "什么都不做"])
	play.choose_text("把伞递过去")
	play.expect_scene("share_umbrella").expect_flag("shared_umbrella")
	play.advance().expect_line("谢谢……我叫凛。")
	play.advance()
	play.expect_scene("platform").expect_line("站台的广播响了起来。")
	play.advance().expect_speaker("announcer").expect_line("由于暴雨，今晚所有列车停运，请改乘明早第一班。")
	play.advance().advance()
	play.expect_choices(["邀请她去咖啡馆避雨", "独自离开车站"])
	play.choose_text("邀请她去咖啡馆避雨")
	play.expect_scene("cafe_invite")
	play.advance()
	play.expect_line("这杯我请你——就当是伞的谢礼。")
	play.advance().advance()
	play.expect_chapter("chapter2").expect_scene("cafe_morning").expect_line("天快亮了，雨声渐渐小了下去。")
	play.advance().expect_speaker("rin").expect_line("明天见。")
	play.advance().expect_line("你笑着点了点头。")
	play.advance().expect_finished()
	play.expect_no_errors()
	play.expect_trace("chapter1_umbrella")


func test_route_alone_to_morning_epilogue() -> void:
	if _story.is_empty():
		return
	var play := VngPlaythrough.for_story(_story, self)
	play.start_story()
	play.advance().advance().advance().advance()
	play.expect_choices(["把伞递过去", "什么都不做"])
	play.choose_text("什么都不做")
	play.expect_scene("do_nothing")
	play.expect_flag("shared_umbrella", false)
	play.advance().advance().advance()
	play.expect_scene("platform").expect_line("站台的广播响了起来。")
	play.advance().advance().advance()
	play.expect_choices(["独自离开车站"])
	play.choose_text("独自离开车站")
	play.expect_scene("leave_alone")
	play.advance()
	play.expect_chapter("chapter2").expect_scene("morning").expect_line("雨下了一整夜，清晨的车站亮起了灯。")
	play.advance().expect_line("你走进检票口。")
	play.advance().expect_finished()
	play.expect_no_errors()
	play.expect_trace("chapter1_alone")


func test_manifest_entries_cover_all_chapters() -> void:
	var result := Compiler.compile_story("res://game/story")
	assert_true(result.ok, _format(result.errors))
	var manifest: Dictionary = result.manifest
	assert_eq(manifest.get("entry", ""), "chapter1.prologue")
	assert_in("chapter1", manifest.get("chapters", []))
	assert_in("chapter2", manifest.get("chapters", []))
	var entries: Dictionary = manifest.get("entries", {})
	assert_eq(entries.get("chapter1", ""), "prologue")
	assert_eq(entries.get("chapter2", ""), "morning")


func _format(diagnostics: Array) -> String:
	var lines := PackedStringArray()
	for diagnostic in diagnostics:
		lines.append("%s:%d: %s" % [
			diagnostic.get("file", ""),
			int(diagnostic.get("line", 0)),
			diagnostic.get("message", ""),
		])
	return "\n".join(lines)
