# @tag story
extends VngTest

const TwoChapter := preload("res://tests/fixtures/two_chapter_story.gd")


func test_two_chapter_walkthrough() -> void:
	var play := VngPlaythrough.for_story(TwoChapter.build(), self)
	play.start_story()
	play.expect_chapter("chapter1").expect_line("第一章开始了。")
	play.advance().expect_line("雨停了。")
	play.advance()
	play.expect_chapter("chapter2").expect_line("第二章开始了。")
	play.advance().expect_finished()
	play.expect_no_errors()
	play.expect_trace("session_two_chapters")


func test_explicit_cross_chapter_and_early_story_end() -> void:
	var play := VngPlaythrough.for_story(TwoChapter.build(), self)
	play.start_story()
	play.skip_to("detour").expect_line("你提前离开。")
	play.advance().expect_chapter("chapter2").expect_line("你提前抵达。")
	play.advance().expect_finished()
	play.expect_no_errors()
	play.expect_trace("session_early_story_end")
