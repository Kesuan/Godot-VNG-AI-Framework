# @tag story
extends VngTest

const StoryScreenScene := preload("res://game/presentation/story_screen.tscn")
const VngInputSim := preload("res://addons/vng_test/dsl/input_sim.gd")


func before_each() -> void:
	VngRun.tree.root.size = Vector2i(1280, 720)


func test_story_screen_flow() -> void:
	var services := VngServices.new(3)
	var screen: Control = StoryScreenScene.instantiate()
	screen.setup(services, _chapter(), "start")
	VngRun.tree.root.add_child(screen)
	await VngRun.tree.process_frame

	var name_label: Label = screen.get_node("NameLabel")
	var text_label: Label = screen.get_node("DialoguePanel/TextLabel")
	var choice_menu: VBoxContainer = screen.get_node("ChoiceMenu")
	assert_eq(name_label.text, "rin")
	assert_eq(text_label.text, "你好。")
	assert_false(choice_menu.visible)

	await _advance(screen)
	assert_true(choice_menu.visible)
	assert_eq(choice_menu.get_child_count(), 2)
	assert_eq((choice_menu.get_child(0) as Button).text, "回应")

	var finished := [false]
	screen.finished.connect(func(): finished[0] = true)
	(choice_menu.get_child(0) as Button).pressed.emit()
	await VngRun.tree.process_frame

	assert_eq(screen.runtime.node_id, "reply")
	assert_true(screen.runtime.state.get_flag("replied"))
	assert_eq(text_label.text, "谢谢。")
	assert_false(choice_menu.visible)

	await _advance(screen)
	var deadline := Time.get_ticks_msec() + 3000
	while not finished[0] and Time.get_ticks_msec() < deadline:
		await VngRun.tree.process_frame
	assert_true(finished[0], "END 后应发出 finished 信号")
	assert_eq(screen.runtime.errors.size(), 0, str(screen.runtime.errors))

	screen.queue_free()
	await VngRun.tree.process_frame


func test_choice_buttons_map_to_runtime_indices() -> void:
	var services := VngServices.new(3)
	var screen: Control = StoryScreenScene.instantiate()
	screen.setup(services, _chapter(), "start")
	VngRun.tree.root.add_child(screen)
	await VngRun.tree.process_frame
	await _advance(screen)

	var choice_menu: VBoxContainer = screen.get_node("ChoiceMenu")
	(choice_menu.get_child(1) as Button).pressed.emit()
	await VngRun.tree.process_frame
	assert_eq(screen.runtime.node_id, "silence")
	assert_false(screen.runtime.state.get_flag("replied"))

	screen.queue_free()
	await VngRun.tree.process_frame


func test_mouse_click_advances_dialogue() -> void:
	var services := VngServices.new(3)
	var screen: Control = StoryScreenScene.instantiate()
	screen.typewriter_cps = 100000.0
	screen.setup(services, _click_chapter(), "start")
	VngRun.tree.root.add_child(screen)
	await VngRun.tree.process_frame
	var text_label: Label = screen.get_node("DialoguePanel/TextLabel")
	assert_eq(text_label.text, "第一句。")
	await _settle_typing(screen)

	await VngInputSim.click(VngRun.tree)
	assert_eq(text_label.text, "第二句。")
	assert_false(screen.runtime.ended)
	await _settle_typing(screen)

	await VngInputSim.click(VngRun.tree)
	assert_true(screen.runtime.ended)

	screen.queue_free()
	await VngRun.tree.process_frame


func test_keyboard_accept_advances_dialogue() -> void:
	var services := VngServices.new(3)
	var screen: Control = StoryScreenScene.instantiate()
	screen.typewriter_cps = 100000.0
	screen.setup(services, _click_chapter(), "start")
	VngRun.tree.root.add_child(screen)
	await VngRun.tree.process_frame
	await _settle_typing(screen)
	var text_label: Label = screen.get_node("DialoguePanel/TextLabel")
	assert_eq(text_label.text, "第一句。")

	await VngInputSim.press_action(VngRun.tree, "ui_accept")
	assert_eq(text_label.text, "第二句。")

	screen.queue_free()
	await VngRun.tree.process_frame


func _settle_typing(screen: Control) -> void:
	var deadline := Time.get_ticks_msec() + 1000
	while screen.is_typing() and Time.get_ticks_msec() < deadline:
		await VngRun.tree.process_frame
	assert_false(screen.is_typing(), "打字机应在超时前完成")


func test_restart_after_finish_is_clean() -> void:
	var services := VngServices.new(3)
	var first: Control = StoryScreenScene.instantiate()
	first.setup(services, _chapter(), "start")
	VngRun.tree.root.add_child(first)
	await VngRun.tree.process_frame

	var finished := [false]
	first.finished.connect(func(): finished[0] = true)
	await _advance(first)
	(first.get_node("ChoiceMenu").get_child(0) as Button).pressed.emit()
	await VngRun.tree.process_frame
	await _advance(first)
	var deadline := Time.get_ticks_msec() + 3000
	while not finished[0] and Time.get_ticks_msec() < deadline:
		await VngRun.tree.process_frame
	assert_true(finished[0], "第一次通关应发出 finished")
	first.queue_free()
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame
	assert_eq(services.events.listener_count("*", true), 0, "剧情屏销毁后应解除所有事件订阅")

	var second: Control = StoryScreenScene.instantiate()
	second.setup(services, _chapter(), "start")
	VngRun.tree.root.add_child(second)
	await VngRun.tree.process_frame
	assert_eq(services.events.listener_count("*", true), 1, "新剧情屏应只注册一个订阅")
	var text_label: Label = second.get_node("DialoguePanel/TextLabel")
	assert_eq(text_label.text, "你好。")
	await _advance(second)
	assert_true((second.get_node("ChoiceMenu") as VBoxContainer).visible)

	second.queue_free()
	await VngRun.tree.process_frame


func _click_chapter() -> Dictionary:
	return {
		"chapter": "click_smoke",
		"nodes": {
			"start": {
				"id": "start",
				"steps": [
					{"op": "say", "who": "", "text": "第一句。"},
					{"op": "say", "who": "", "text": "第二句。"},
					{"op": "goto", "target": "END"},
				],
			},
		},
	}


func _advance(screen: Control) -> void:
	if screen.is_typing():
		screen.request_advance()
	await VngRun.tree.process_frame
	screen.request_advance()
	await VngRun.tree.process_frame


func _chapter() -> Dictionary:
	return {
		"chapter": "smoke",
		"nodes": {
			"start": {
				"id": "start",
				"steps": [
					{"op": "say", "who": "rin", "text": "你好。"},
					{
						"op": "choice",
						"options": [
							{"text": "回应", "target": "reply"},
							{"text": "沉默", "target": "silence"},
						],
					},
				],
			},
			"reply": {
				"id": "reply",
				"steps": [
					{"op": "set", "name": "replied", "assign": "=", "value": true},
					{"op": "say", "who": "rin", "text": "谢谢。"},
					{"op": "goto", "target": "END"},
				],
			},
			"silence": {
				"id": "silence",
				"steps": [
					{"op": "say", "who": "rin", "text": "……"},
					{"op": "goto", "target": "END"},
				],
			},
		},
	}
