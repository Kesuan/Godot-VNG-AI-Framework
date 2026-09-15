# @tag fast
extends VngTest

const Parser := preload("res://addons/vns/vns_parser.gd")

const FILE := "res://game/story/chapter_one.vns"


func test_valid_chapter_structure_and_src_lines() -> void:
	var source := "@chapter chapter_one\n\n:: start\n@bg room fade=0.5\nsay_hi: 你好\n这是一句旁白\n* 选项A -> end\n* 选项B {flag_a} -> end\n\n:: end\n-> END\n"
	var parsed := Parser.parse(source, FILE)
	assert_true(parsed.ok, _messages(parsed.errors))
	var chapter: Dictionary = parsed.chapter
	assert_eq(chapter.get("chapter", ""), "chapter_one")
	var nodes: Dictionary = chapter.get("nodes", {})
	assert_eq(nodes.size(), 2)
	var steps: Array = (nodes["start"] as Dictionary).get("steps", [])
	assert_eq(steps.size(), 4)
	var bg_step: Dictionary = steps[0]
	assert_eq(bg_step.get("op", ""), "bg")
	assert_eq(bg_step.get("asset", ""), "room")
	assert_eq(bg_step.get("fade", 0.0), 0.5)
	assert_eq(int(bg_step.get("src", {}).get("line", 0)), 4)
	var say_step: Dictionary = steps[1]
	assert_eq(say_step.get("who", ""), "say_hi")
	assert_eq(say_step.get("text", ""), "你好")
	var narration: Dictionary = steps[2]
	assert_eq(narration.get("who", ""), "")
	assert_eq(narration.get("text", ""), "这是一句旁白")
	var choice_step: Dictionary = steps[3]
	assert_eq(choice_step.get("op", ""), "choice")
	var options: Array = choice_step.get("options", [])
	assert_eq(options.size(), 2)
	assert_eq((options[0] as Dictionary).get("target", ""), "end")
	assert_eq((options[1] as Dictionary).get("cond", ""), "flag_a")


func test_colon_inside_narration_is_not_speaker() -> void:
	var source := "@chapter chapter_one\n\n:: n\n他说：你好\n-> END\n"
	var parsed := Parser.parse(source, FILE)
	assert_true(parsed.ok, _messages(parsed.errors))
	var steps: Array = ((parsed.chapter.nodes as Dictionary)["n"] as Dictionary).get("steps", [])
	assert_eq((steps[0] as Dictionary).get("who", ""), "")
	assert_eq((steps[0] as Dictionary).get("text", ""), "他说：你好")


func test_missing_chapter_declaration() -> void:
	var parsed := Parser.parse(":: n\n-> END\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "缺少 @chapter 声明"))


func test_chapter_id_must_match_file_name() -> void:
	var parsed := Parser.parse("@chapter other\n\n:: n\n-> END\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "与文件名"))


func test_duplicate_node() -> void:
	var parsed := Parser.parse("@chapter chapter_one\n\n:: n\n-> END\n\n:: n\n-> END\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "节点重复定义"))


func test_node_must_end_with_jump_or_choice() -> void:
	var parsed := Parser.parse("@chapter chapter_one\n\n:: n\n你好。\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "必须以跳转"))


func test_empty_node() -> void:
	var parsed := Parser.parse("@chapter chapter_one\n\n:: n\n:: m\n-> END\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "没有内容"))


func test_choice_requires_target() -> void:
	var parsed := Parser.parse("@chapter chapter_one\n\n:: n\n* 选项\n-> END\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "选项缺少跳转目标"))


func test_unknown_directive_suggests() -> void:
	var parsed := Parser.parse("@chapter chapter_one\n\n:: n\n@bgg room\n-> END\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "未知指令 @bgg"))
	assert_true(_contains(parsed.errors, "是否想写 'bg'"))


func test_bad_set_value() -> void:
	var parsed := Parser.parse("@chapter chapter_one\n\n:: n\n@set x = maybe\n-> END\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "值必须是 true/false 或整数"))


func test_bad_choice_condition() -> void:
	var parsed := Parser.parse("@chapter chapter_one\n\n:: n\n* 选项 {x &&} -> END\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "条件表达式错误"))


func test_bad_fade_value() -> void:
	var parsed := Parser.parse("@chapter chapter_one\n\n:: n\n@bg room fade=abc\n-> END\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "fade 需要数字"))


func test_text_outside_node() -> void:
	var parsed := Parser.parse("@chapter chapter_one\n你好\n", FILE)
	assert_false(parsed.ok)
	assert_true(_contains(parsed.errors, "对白/旁白必须位于节点内"))


func test_escape_makes_special_prefix_narration() -> void:
	var source := "@chapter chapter_one\n\n:: n\n\\* 这不是选项\n-> END\n"
	var parsed := Parser.parse(source, FILE)
	assert_true(parsed.ok, _messages(parsed.errors))
	var steps: Array = ((parsed.chapter.nodes as Dictionary)["n"] as Dictionary).get("steps", [])
	assert_eq((steps[0] as Dictionary).get("text", ""), "* 这不是选项")


func _messages(errors: Array) -> String:
	var lines := PackedStringArray()
	for error in errors:
		lines.append(str(error.get("message", "")))
	return "\n".join(lines)


func _contains(errors: Array, needle: String) -> bool:
	for error in errors:
		if (error.get("message", "") as String).contains(needle):
			return true
	return false
