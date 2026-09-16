# @tag fast
extends VngTest

const SampleChapter := preload("res://tests/fixtures/sample_chapter.gd")


func _runtime(seed_value := 1) -> VngStoryRuntime:
	return VngStoryRuntime.new(VngServices.for_tests(seed_value), SampleChapter.build())


func test_prologue_runs_to_first_line() -> void:
	var runtime := _runtime()
	runtime.start("prologue")
	assert_eq(runtime.waiting, VngStoryRuntime.WAITING_SAY)
	assert_eq(runtime.current_line.get("who", ""), "yuki")
	assert_eq(runtime.current_line.get("text", ""), "早上好！")
	assert_eq(runtime.stage.get("bg", ""), "classroom_day")
	assert_eq(runtime.stage.get("bgm", ""), "bgm_daily")
	assert_eq((runtime.stage.get("chars", {}) as Dictionary).has("yuki"), true)
	assert_eq(runtime.errors.size(), 0)


func test_advance_moves_through_lines_to_choice() -> void:
	var runtime := _runtime()
	runtime.start("prologue")
	runtime.advance()
	assert_eq(runtime.current_line.get("who", ""), "")
	assert_eq(runtime.waiting, VngStoryRuntime.WAITING_SAY)
	runtime.advance()
	assert_eq(runtime.waiting, VngStoryRuntime.WAITING_CHOICE)
	assert_true(runtime.state.get_flag("met_yuki"))
	assert_eq(runtime.visible_choices().size(), 2)
	assert_eq(runtime.errors.size(), 0)


func test_advance_while_choice_is_noop() -> void:
	var runtime := _runtime()
	runtime.start("prologue")
	runtime.advance()
	runtime.advance()
	var before := runtime.snapshot()
	runtime.advance()
	assert_eq(runtime.snapshot(), before)


func test_choice_condition_reveals_hidden_option() -> void:
	var runtime := _runtime()
	runtime.state.set_var("trust", 2)
	runtime.start("prologue")
	runtime.advance()
	runtime.advance()
	assert_eq(runtime.current_choices.size(), 3)
	runtime.choose(0)
	assert_eq(runtime.node_id, "greet_warm")
	assert_true(runtime.state.get_flag("route_yuki"))
	assert_eq(runtime.waiting, VngStoryRuntime.WAITING_SAY)
	runtime.advance()
	assert_true(runtime.ended)


func test_var_increment_on_undefined_creates_var() -> void:
	var runtime := _runtime()
	runtime.start("prologue")
	runtime.advance()
	runtime.advance()
	runtime.choose(1)
	assert_eq(runtime.state.get_var("trust"), 1)
	assert_true(runtime.state.get_flag("route_yuki"))
	runtime.advance()
	assert_true(runtime.ended)


func test_events_recorded_in_order() -> void:
	var runtime := _runtime()
	runtime.start("prologue")
	runtime.advance()
	runtime.advance()
	runtime.choose(2)
	var types := runtime.services.events.event_types()
	var expected := PackedStringArray([
		"node_entered", "bg_changed", "char_shown", "bgm_changed", "line_shown",
		"flag_changed", "line_shown", "choice_presented", "choice_selected",
		"node_entered", "line_shown",
	])
	assert_eq(types, expected)
	assert_eq(runtime.stage.get("bg", ""), "classroom_day")


func test_choice_selected_ignored_nodes_do_not_end_story() -> void:
	var runtime := _runtime()
	runtime.start("prologue")
	runtime.advance()
	runtime.advance()
	runtime.choose(2)
	runtime.advance()
	assert_true(runtime.ended)
	assert_eq(runtime.current_line, {})
	assert_eq(runtime.errors.size(), 0)


func test_apply_command_via_input_hub() -> void:
	var services := VngServices.for_tests(1)
	var runtime := VngStoryRuntime.new(services, SampleChapter.build())
	runtime.start("prologue")
	services.input.push(VngCommand.advance())
	assert_true(runtime.pump())
	services.input.push(VngCommand.advance())
	assert_true(runtime.pump())
	assert_eq(runtime.waiting, VngStoryRuntime.WAITING_CHOICE)
	services.input.push(VngCommand.choose(2))
	assert_true(runtime.pump())
	assert_eq(runtime.node_id, "ignore")
	assert_false(runtime.pump())


func test_skip_to_jumps_directly() -> void:
	var runtime := _runtime()
	runtime.start("prologue")
	runtime.skip_to("greet")
	assert_eq(runtime.node_id, "greet")
	assert_eq(runtime.waiting, VngStoryRuntime.WAITING_SAY)
	assert_eq(runtime.current_line.get("text", ""), "太好了。")


func test_missing_target_aborts_with_error() -> void:
	var chapter := SampleChapter.build()
	var steps: Array = (chapter.nodes as Dictionary)["prologue"]["steps"]
	for step in steps:
		if (step as Dictionary).get("op", "") == "choice":
			var options: Array = (step as Dictionary)["options"]
			(options[2] as Dictionary)["target"] = "no_such_node"
	var runtime := VngStoryRuntime.new(VngServices.for_tests(1), chapter)
	runtime.start("prologue")
	runtime.advance()
	runtime.advance()
	runtime.choose(2)
	assert_true(runtime.ended)
	assert_true(runtime.errors.size() > 0)
	assert_in("story_error", runtime.services.events.event_types())


func test_invalid_choice_index_records_error() -> void:
	var runtime := _runtime()
	runtime.start("prologue")
	runtime.advance()
	runtime.advance()
	runtime.choose(99)
	assert_eq(runtime.errors.size(), 1)
	assert_eq(runtime.waiting, VngStoryRuntime.WAITING_CHOICE)


func test_presentation_events_carry_fade() -> void:
	var chapter := {
		"chapter": "fade_probe",
		"nodes": {
			"n": {
				"id": "n",
				"steps": [
					{"op": "bg", "asset": "room", "fade": 0.5},
					{"op": "show", "char": "rin", "expr": "smile", "pos": "center"},
					{"op": "say", "who": "", "text": "你好"},
					{"op": "goto", "target": "END"},
				],
			},
		},
	}
	var services := VngServices.for_tests(1)
	var runtime := VngStoryRuntime.new(services, chapter)
	runtime.start("n")
	var events := services.events.history()
	var bg_event: Dictionary = events[1]
	assert_eq(bg_event.get("type", ""), "bg_changed")
	assert_eq(float(bg_event.get("data", {}).get("fade", 0.0)), 0.5)
	var show_event: Dictionary = events[2]
	assert_eq(show_event.get("type", ""), "char_shown")
	assert_eq(float(show_event.get("data", {}).get("fade", 0.0)), -1.0)
	assert_eq(runtime.errors.size(), 0)
