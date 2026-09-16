# @tag fast
extends VngTest

const VnsStory := preload("res://addons/vns/vns_story.gd")


func test_load_game_story() -> void:
	var story := VnsStory.load_compiled("res://game/story")
	assert_true(story.ok, str(story.errors))
	var chapters: Dictionary = story.chapters
	assert_true(chapters.has("chapter1"))
	var entry: String = story.manifest.get("entry", "")
	var split := VnsStory.split_entry(entry)
	assert_eq(split.get("chapter", ""), "chapter1")
	var chapter: Dictionary = chapters.get(split.get("chapter", ""), {})
	assert_true((chapter.get("nodes", {}) as Dictionary).has(split.get("node", "")))


func test_missing_manifest_reports_error() -> void:
	var story := VnsStory.load_compiled("res://tests/fixtures/no_such_story")
	assert_false(story.ok)
	assert_true((story.errors[0].get("message", "") as String).contains("story.json"))


func test_missing_compiled_reports_error() -> void:
	var story := VnsStory.load_compiled("res://tests/fixtures/story_basic")
	assert_false(story.ok)
	assert_true(_contains(story.errors, "缺少编译产物"))


func test_split_entry_invalid() -> void:
	assert_eq(VnsStory.split_entry("prologue"), {})
	assert_eq(VnsStory.split_entry("a.b.c"), {})


func test_chapter_for_entry() -> void:
	var story := VnsStory.load_compiled("res://game/story")
	var chapter: Dictionary = VnsStory.chapter_for_entry("chapter1.prologue", story.chapters)
	assert_true(chapter.has("nodes"))
	assert_eq(VnsStory.chapter_for_entry("nope.prologue", story.chapters), {})


func _contains(diagnostics: Array, needle: String) -> bool:
	for diagnostic in diagnostics:
		if (diagnostic.get("message", "") as String).contains(needle):
			return true
	return false
