# @tag fast
extends VngTest

const VnsStory := preload("res://addons/vns/vns_story.gd")
const VnsCompiler := preload("res://addons/vns/vns_compiler.gd")


func test_project_settings_are_game_ready() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""), "gl_compatibility")
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)), 1280)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)), 720)


func test_framework_mirror_is_usable() -> void:
	var services := VngServices.new(7)
	var runtime := VngStoryRuntime.new(services, {"chapter": "probe", "nodes": {}})
	assert_not_null(runtime)
	var condition := VngCondition.evaluate_text("true", VngStoryState.new())
	assert_true(condition.ok)


func test_game_story_loads() -> void:
	var story := VnsStory.load_compiled("res://game/story")
	assert_true(story.ok, str(story.errors))
	assert_true((story.chapters as Dictionary).has("chapter1"))


func test_game_story_compiled_is_fresh() -> void:
	var result := VnsCompiler.check_story("res://game/story")
	assert_eq((result.errors as Array).size(), 0, str(result.errors))
	assert_eq((result.get("stale", []) as Array).size(), 0, "编译产物过期，请运行 tools/demo story build")
	assert_eq((result.get("missing", []) as Array).size(), 0, "缺少编译产物，请运行 tools/demo story build")
