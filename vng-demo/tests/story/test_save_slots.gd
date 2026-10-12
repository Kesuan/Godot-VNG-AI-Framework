# @tag story
extends VngTest

const StoryScreenScene := preload("res://game/presentation/story_screen.tscn")
const MainScene := preload("res://game/presentation/main.tscn")
const VngInputSim := preload("res://addons/vng_test/dsl/input_sim.gd")
const VnsStoryLoader := preload("res://addons/vns/vns_story.gd")

const TEST_SAVE_ROOT := "user://vng_test/saves_slots"
const SLOTS := ["auto", "slot1", "slot2", "slot3"]


func before_each() -> void:
	VngRun.tree.root.size = Vector2i(1280, 720)
	_clear_saves()


func test_esc_toggles_menu() -> void:
	var screen := _screen(VngServices.for_tests(3))
	await VngRun.tree.process_frame
	var menu: Control = screen.get_node("MenuOverlay")
	assert_false(menu.visible)

	await VngInputSim.press_action(VngRun.tree, "ui_cancel")
	assert_true(menu.visible, "ESC 应打开菜单")
	await VngInputSim.press_action(VngRun.tree, "ui_cancel")
	assert_false(menu.visible, "再按 ESC 应关闭菜单")

	screen.queue_free()
	await VngRun.tree.process_frame


func test_save_and_load_through_menu_input() -> void:
	var screen := _screen(VngServices.for_tests(3))
	await VngRun.tree.process_frame
	await _settle_typing(screen)
	var text_label: Label = screen.get_node("DialoguePanel/TextLabel")
	assert_eq(text_label.text, "第一句。")

	# 菜单 → 保存游戏 → 存档 1
	await VngInputSim.press_action(VngRun.tree, "ui_cancel")
	var menu: Control = screen.get_node("MenuOverlay")
	await _click(menu.get_node("Panel/MenuButtons/SaveButton"))
	await VngRun.tree.process_frame
	var slot_list: VBoxContainer = menu.get_node("Panel/SlotList")
	assert_eq(slot_list.get_child_count(), 4, "保存列表应包含自动档与 3 个手动槽")
	assert_true((slot_list.get_child(0) as Button).disabled, "自动档不可手动写入")
	await _click(slot_list.get_child(1))
	await VngRun.tree.process_frame

	var store := VngSaveStore.new(TEST_SAVE_ROOT)
	assert_true(store.exists("slot1"), "存档 1 应写入")
	var saved := store.read("slot1")
	assert_eq(saved.get("chapter", ""), "chapter1")
	assert_eq(saved.get("node", ""), "start")
	assert_eq(str((saved.get("line", {}) as Dictionary).get("text", "")), "第一句。")
	assert_true(int(saved.get("save_seq", 0)) > 0, "写入存档应带递增序号")

	# 关闭菜单，推进一句，再通过菜单读回
	await VngInputSim.press_action(VngRun.tree, "ui_cancel")
	await VngInputSim.press_action(VngRun.tree, "ui_accept")
	await _settle_typing(screen)
	assert_eq(text_label.text, "第二句。")

	await VngInputSim.press_action(VngRun.tree, "ui_cancel")
	await _click(menu.get_node("Panel/MenuButtons/LoadButton"))
	await VngRun.tree.process_frame
	var load_list: VBoxContainer = menu.get_node("Panel/SlotList")
	await _click(load_list.get_child(1))
	await VngRun.tree.process_frame

	assert_eq(text_label.text, "第一句。", "读档后应恢复存档点台词")
	assert_true(screen.runtime.state.get_flag("touched"))
	assert_false(menu.visible, "读档成功后菜单应关闭")

	screen.queue_free()
	await VngRun.tree.process_frame


func test_chapter_transition_writes_autosave() -> void:
	var screen := _screen(VngServices.for_tests(3))
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame
	var store := VngSaveStore.new(TEST_SAVE_ROOT)
	assert_true(store.exists("auto"), "进入章节时应写自动存档")
	assert_eq(store.read("auto").get("chapter", ""), "chapter1")

	# 推进到第二章：自动档应更新为第二章
	await VngInputSim.press_action(VngRun.tree, "ui_accept")
	await _settle_typing(screen)
	await VngInputSim.press_action(VngRun.tree, "ui_accept")
	await _settle_typing(screen)
	assert_eq(screen.session.current_chapter, "chapter2")
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame
	var auto_save := store.read("auto")
	assert_eq(auto_save.get("chapter", ""), "chapter2")
	assert_eq(screen.runtime.node_id, "next")

	screen.queue_free()
	await VngRun.tree.process_frame


func test_main_new_game_writes_chapter1_autosave() -> void:
	var main: Node = MainScene.instantiate()
	VngRun.tree.root.add_child(main)
	await VngRun.tree.process_frame
	main.services.save_root = TEST_SAVE_ROOT
	main._show_title()
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame

	var title: Control = main._current_screen
	await _click(title.start_button)
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame

	var store := VngSaveStore.new(TEST_SAVE_ROOT)
	assert_true(store.exists("auto"), "开始游戏后应写入第一章自动存档")
	var auto_save := store.read("auto")
	assert_eq(auto_save.get("chapter", ""), "chapter1")
	assert_true(int(auto_save.get("save_seq", 0)) > 0, "自动存档应带递增序号")
	assert_eq(
		str((auto_save.get("line", {}) as Dictionary).get("text", "")),
		"雨点砸在站台的顶棚上，风把雨丝吹进来。"
	)

	main.queue_free()
	await VngRun.tree.process_frame


func test_main_continue_from_title_button() -> void:
	var story := VnsStoryLoader.load_compiled("res://game/story")
	assert_true(story.ok, "游戏剧本应可加载")
	var pre_services := VngServices.for_tests(9)
	var pre_session := VngStorySession.new(pre_services, story.manifest, story.chapters)
	assert_true(pre_session.start())
	pre_session.advance()
	var store := VngSaveStore.new(TEST_SAVE_ROOT)
	assert_eq(store.write("slot1", pre_session.save_data()), OK)
	var expected_line := str(pre_session.runtime.current_line.get("text", ""))

	var main: Node = MainScene.instantiate()
	VngRun.tree.root.add_child(main)
	await VngRun.tree.process_frame
	main.services.save_root = TEST_SAVE_ROOT
	main._show_title()
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame

	var title: Control = main._current_screen
	assert_true(title.continue_button.visible, "有存档时「继续游戏」应可见")
	await _click(title.continue_button)
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame

	var screen: Control = main._current_screen
	assert_eq(screen.name, "StoryScreen")
	assert_eq(screen.session.current_chapter, "chapter1")
	assert_eq(str(screen.runtime.current_line.get("text", "")), expected_line)
	assert_false(screen.runtime.state.has_flag("shared_umbrella"))

	main.queue_free()
	await VngRun.tree.process_frame


func test_continue_prefers_latest_save_sequence() -> void:
	var saves := _build_saves()
	var store := VngSaveStore.new(TEST_SAVE_ROOT)
	var old_save := (saves["first"] as Dictionary).duplicate(true)
	old_save["play_time"] = 500.0
	old_save["save_seq"] = 1
	assert_eq(store.write("slot1", old_save), OK)
	var newer_save := (saves["second"] as Dictionary).duplicate(true)
	newer_save["play_time"] = 1.0
	newer_save["save_seq"] = 2
	assert_eq(store.write("slot2", newer_save), OK)

	var main: Node = MainScene.instantiate()
	VngRun.tree.root.add_child(main)
	await VngRun.tree.process_frame
	main.services.save_root = TEST_SAVE_ROOT
	main._show_title()
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame

	var title: Control = main._current_screen
	await _click(title.continue_button)
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame

	var screen: Control = main._current_screen
	assert_eq(screen.name, "StoryScreen")
	assert_eq(
		str(screen.runtime.current_line.get("text", "")),
		"你收起伞，看见长椅旁站着一个湿透的女孩。",
		"「继续」应按写入序号取最新档，而非游戏时长"
	)

	main.queue_free()
	await VngRun.tree.process_frame


func test_title_load_specific_slot_and_back() -> void:
	var saves := _build_saves()
	var store := VngSaveStore.new(TEST_SAVE_ROOT)
	var first_save := (saves["first"] as Dictionary).duplicate(true)
	first_save["save_seq"] = 1
	assert_eq(store.write("slot1", first_save), OK)
	var second_save := (saves["second"] as Dictionary).duplicate(true)
	second_save["save_seq"] = 2
	assert_eq(store.write("slot2", second_save), OK)

	var main: Node = MainScene.instantiate()
	VngRun.tree.root.add_child(main)
	await VngRun.tree.process_frame
	main.services.save_root = TEST_SAVE_ROOT
	main._show_title()
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame

	var title: Control = main._current_screen
	assert_true(title.load_button.visible, "有存档时「读取存档」应可见")
	await _click(title.load_button)
	await VngRun.tree.process_frame
	var overlay: Control = main._load_overlay
	assert_true(overlay.is_open(), "标题屏读档应打开槽位列表")

	await _click(overlay.get_node("Panel/BackButton"))
	await VngRun.tree.process_frame
	assert_false(overlay.is_open(), "返回应关闭槽位列表")

	# 模拟“完成一轮剧情回到主界面”：重建标题屏，弹层须重新置顶
	main._show_title()
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame
	title = main._current_screen

	await _click(title.load_button)
	await VngRun.tree.process_frame
	assert_true(overlay.is_open(), "回到标题后「读取存档」仍应可用")
	assert_true(
		main.get_child(main.get_child_count() - 1) == overlay,
		"读取存档弹层应显示在标题屏之上（最顶层）"
	)
	var slot_list: VBoxContainer = overlay.get_node("Panel/SlotList")
	assert_eq(slot_list.get_child_count(), 4)
	await _click(slot_list.get_child(1))
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame

	assert_false(overlay.is_open(), "选档成功后应关闭列表")
	var screen: Control = main._current_screen
	assert_eq(screen.name, "StoryScreen")
	assert_eq(
		str(screen.runtime.current_line.get("text", "")),
		"雨点砸在站台的顶棚上，风把雨丝吹进来。",
		"标题屏应能读取指定的手动档（即使它不是最新）"
	)

	main.queue_free()
	await VngRun.tree.process_frame


func _build_saves() -> Dictionary:
	var story := VnsStoryLoader.load_compiled("res://game/story")
	assert_true(story.ok, "游戏剧本应可加载")
	var pre_services := VngServices.for_tests(9)
	var session := VngStorySession.new(pre_services, story.manifest, story.chapters)
	session.start()
	var first := session.save_data()
	session.advance()
	var second := session.save_data()
	return {"first": first, "second": second}


func _screen(services: VngServices) -> Control:
	services.save_root = TEST_SAVE_ROOT
	var story := _two_chapter_story()
	var session := VngStorySession.new(services, story["manifest"], story["chapters"])
	var screen: Control = StoryScreenScene.instantiate()
	screen.typewriter_cps = 100000.0
	screen.setup_session(services, session)
	VngRun.tree.root.add_child(screen)
	return screen


func _two_chapter_story() -> Dictionary:
	return {
		"manifest": {
			"entry": "chapter1.start",
			"entries": {"chapter1": "start", "chapter2": "next"},
			"chapters": ["chapter1", "chapter2"],
			"titles": {"chapter1": "第一章", "chapter2": "第二章"},
		},
		"chapters": {
			"chapter1": {
				"chapter": "chapter1",
				"nodes": {
					"start": {
						"id": "start",
						"steps": [
							{"op": "set", "name": "touched", "assign": "=", "value": true},
							{"op": "say", "who": "", "text": "第一句。"},
							{"op": "say", "who": "", "text": "第二句。"},
							{"op": "goto", "target": "END"},
						],
					},
				},
			},
			"chapter2": {
				"chapter": "chapter2",
				"nodes": {
					"next": {
						"id": "next",
						"steps": [
							{"op": "say", "who": "", "text": "第二章。"},
							{"op": "goto", "target": "END"},
						],
					},
				},
			},
		},
	}


func _click(control: Control) -> void:
	await VngInputSim.click(VngRun.tree, control.get_global_rect().get_center())


func _settle_typing(screen: Control) -> void:
	var deadline := Time.get_ticks_msec() + 1000
	while screen.is_typing() and Time.get_ticks_msec() < deadline:
		await VngRun.tree.process_frame
	assert_false(screen.is_typing(), "打字机应在超时前完成")


func _clear_saves() -> void:
	var store := VngSaveStore.new(TEST_SAVE_ROOT)
	for slot in SLOTS:
		if store.exists(slot):
			store.erase(slot)
