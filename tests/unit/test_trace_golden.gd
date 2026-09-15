# @tag fast
extends VngTest

const TraceGolden := preload("res://addons/vng_test/dsl/trace_golden.gd")
const SampleChapter := preload("res://tests/fixtures/sample_chapter.gd")


func test_reduce_keeps_semantic_events_only() -> void:
	var history: Array = [
		{"seq": 1, "t": 0.0, "type": "node_entered", "data": {"node": "prologue", "src": {"file": "x", "line": 3}}},
		{"seq": 2, "t": 0.0, "type": "line_shown", "data": {"who": "yuki", "text": "你好", "node": "prologue", "step": 3}},
		{"seq": 3, "t": 0.0, "type": "choice_presented", "data": {"options": [{"index": 0, "text": "A"}, {"index": 1, "text": "B"}]}},
		{"seq": 4, "t": 0.0, "type": "save_applied", "data": {}},
	]
	var reduced := TraceGolden.reduce(history)
	assert_eq(reduced.size(), 3)
	assert_eq(reduced[0], {"type": "node_entered", "node": "prologue"})
	assert_eq(reduced[1], {"type": "line_shown", "who": "yuki", "text": "你好"})
	assert_eq(reduced[2], {"type": "choice_presented", "options": ["A", "B"]})


func test_compare_reports_differences() -> void:
	var expected: Array = [{"type": "node_entered", "node": "a"}]
	var actual: Array = [{"type": "node_entered", "node": "b"}]
	var result := TraceGolden.compare(expected, actual)
	assert_false(result.equal)
	assert_eq((result.differences as Array).size(), 1)
	assert_true(TraceGolden.format_diff(result.differences).contains("期望"))


func test_compare_normalizes_json_number_types() -> void:
	var expected: Array = [{"type": "choice_selected", "index": 0}]
	var actual: Array = [{"type": "choice_selected", "index": 0.0}]
	assert_true(TraceGolden.compare(expected, actual).equal)


func test_save_and_load_round_trip() -> void:
	var path := "user://vng_test/traces/round_trip.trace.json"
	var events: Array = [{"type": "story_ended"}]
	assert_eq(TraceGolden.save_golden(path, "round_trip", events), OK)
	var loaded := TraceGolden.load_golden(path)
	assert_eq(loaded.get("name", ""), "round_trip")
	assert_eq(loaded.get("events", []), events)


func test_playthrough_update_then_compare_and_fail() -> void:
	var old_trace_dir: String = VngRun.trace_dir
	var old_report_dir: String = VngRun.report_dir
	var old_update: bool = VngRun.update_traces
	VngRun.trace_dir = "user://vng_test/traces"
	VngRun.report_dir = "user://vng_test"
	var play := VngPlaythrough.new(SampleChapter.build(), self)
	play.start_scene("prologue").advance().advance().choose(2).advance()
	VngRun.update_traces = true
	play.expect_trace("unit_playthrough")
	VngRun.update_traces = false
	play.expect_trace("unit_playthrough")
	assert_eq(failures.size(), 0)
	var other := VngPlaythrough.new(SampleChapter.build(), self)
	other.start_scene("prologue").advance().advance().choose(1).advance()
	other.expect_trace("unit_playthrough")
	assert_true(failures.size() > 0)
	failures.clear()
	VngRun.trace_dir = old_trace_dir
	VngRun.report_dir = old_report_dir
	VngRun.update_traces = old_update


func test_expect_trace_without_golden_reports_hint() -> void:
	var old_trace_dir: String = VngRun.trace_dir
	VngRun.trace_dir = "user://vng_test/traces_missing"
	var play := VngPlaythrough.new(SampleChapter.build(), self)
	play.start_scene("prologue")
	play.expect_trace("no_such_trace")
	assert_true(failures.size() > 0)
	assert_true((failures[0].get("message", "") as String).contains("--update-traces"))
	failures.clear()
	VngRun.trace_dir = old_trace_dir
