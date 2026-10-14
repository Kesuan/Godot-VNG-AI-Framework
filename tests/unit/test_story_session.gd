# @tag fast
extends VngTest

const TwoChapter := preload("res://tests/fixtures/two_chapter_story.gd")


func _session(story: Dictionary = {}) -> VngStorySession:
	var data: Dictionary = story if not story.is_empty() else TwoChapter.build()
	return VngStorySession.new(VngServices.for_tests(1), data.get("manifest", {}), data.get("chapters", {}))


func test_end_advances_to_next_chapter_and_carries_state() -> void:
	var session := _session()
	assert_true(session.start())
	assert_eq(session.current_chapter, "chapter1")
	assert_eq(session.runtime.current_line.get("text", ""), "第一章开始了。")
	session.advance()
	assert_eq(session.runtime.current_line.get("text", ""), "雨停了。")
	session.advance()
	assert_eq(session.current_chapter, "chapter2")
	assert_eq(session.runtime.node_id, "wake")
	assert_eq(session.runtime.current_line.get("text", ""), "第二章开始了。")
	assert_true(session.state.get_flag("met_kaede"))
	assert_eq(session.stage.get("bg", ""), "room")
	assert_false(session.finished)
	session.advance()
	assert_true(session.finished)
	assert_eq(session.errors.size(), 0)


func test_explicit_cross_chapter_jump() -> void:
	var session := _session()
	session.start()
	session.skip_to("detour")
	assert_eq(session.runtime.current_line.get("text", ""), "你提前离开。")
	session.advance()
	assert_eq(session.current_chapter, "chapter2")
	assert_eq(session.runtime.node_id, "early")
	assert_eq(session.runtime.current_line.get("text", ""), "你提前抵达。")
	session.advance()
	assert_true(session.finished)
	assert_eq(session.runtime.end_kind, VngStoryRuntime.END_STORY)
	assert_eq(session.errors.size(), 0)


func test_final_chapter_end_finishes_story() -> void:
	var session := _session()
	session.start()
	session.advance()
	session.advance()
	session.advance()
	assert_true(session.finished)
	assert_eq(session.runtime.end_kind, VngStoryRuntime.END_CHAPTER)


func test_missing_chapter_entry_records_error() -> void:
	var session := _session(TwoChapter.build_missing_entry())
	session.start()
	session.advance()
	session.advance()
	assert_true(session.finished)
	assert_eq(session.errors.size(), 1)
	assert_true((session.errors[0].get("message", "") as String).contains("缺少入口登记"))


func test_save_load_across_chapters() -> void:
	var source := _session()
	source.start()
	source.advance()
	source.advance()
	var save := source.save_data()
	assert_eq(save.get("chapter", ""), "chapter2")
	assert_eq(save.get("version", 0), VngSave.VERSION)
	assert_ne(save.get("story_hash", ""), "")

	var target := _session()
	assert_true(target.load_save(save))
	assert_eq(target.current_chapter, "chapter2")
	assert_eq(target.snapshot(), source.snapshot())
	target.advance()
	assert_true(target.finished)


func test_story_hash_mismatch_rejects_save() -> void:
	var source := _session()
	source.start()
	var save := source.save_data()
	var modified := TwoChapter.build()
	(modified.manifest as Dictionary)["entries"] = {"chapter1": "start", "chapter2": "early"}
	var target := _session(modified)
	assert_false(target.load_save(save))
	assert_eq(target.errors.size(), 1)
	assert_true((target.errors[0].get("message", "") as String).contains("剧本已改动"))


func test_version_mismatch_rejects_save() -> void:
	var source := _session()
	source.start()
	var save := source.save_data()
	save["version"] = 1
	var target := _session()
	assert_false(target.load_save(save))
	assert_true((target.errors[0].get("message", "") as String).contains("版本不兼容"))


func test_entry_for_uses_entries_then_free_fallback() -> void:
	var session := _session()
	assert_eq(session.entry_for("chapter1"), "chapter1.start")
	assert_eq(session.entry_for("chapter2"), "chapter2.wake")
	var legacy := _session({"manifest": {"entry": "chapter1.start", "chapters": ["chapter1"]}, "chapters": TwoChapter.build().chapters})
	assert_eq(legacy.entry_for("chapter1"), "chapter1.start")
	assert_eq(legacy.entry_for("chapter2"), "")


func test_ending_is_exposed_on_finish() -> void:
	var story := {
		"manifest": {
			"entry": "only.end",
			"chapters": ["only"],
			"endings": {"final_good": {"title": "好结局", "subtitle": "副标题"}},
		},
		"chapters": {
			"only": {
				"chapter": "only",
				"nodes": {
					"end": {
						"id": "end",
						"steps": [
							{"op": "say", "who": "", "text": "结束。"},
							{"op": "ending", "id": "final_good"},
							{"op": "goto", "target": "END"},
						],
					},
				},
			},
		},
	}
	var session := _session(story)
	assert_true(session.start())
	assert_eq(session.ending_id(), "")
	session.advance()
	assert_true(session.finished)
	assert_eq(session.ending_id(), "final_good")
	assert_eq(str(session.ending().get("title", "")), "好结局")
	assert_eq(str(session.ending().get("subtitle", "")), "副标题")
