# @tag story
extends VngTest

const MainScene := preload("res://game/presentation/main.tscn")
const VngInputSim := preload("res://addons/vng_test/dsl/input_sim.gd")
const VnsStoryLoader := preload("res://addons/vns/vns_story.gd")

const TEST_SAVE_ROOT := "user://vng_test/saves_ending"
const TEST_READ_ROOT := "user://vng_test/read"
const TEST_SETTINGS_PATH := "user://vng_test/settings.json"


func before_each() -> void:
	VngRun.tree.root.size = Vector2i(1280, 720)
	var store := VngSaveStore.new(TEST_SAVE_ROOT)
	for slot in ["auto", "slot1", "slot2", "slot3"]:
		if store.exists(slot):
			store.erase(slot)


func test_main_plays_to_ending_page_and_returns_title() -> void:
	var story := VnsStoryLoader.load_compiled("res://game/story")
	assert_true(story.ok, "游戏剧本应可加载")

	# 在第三章傍晚（选项处）存档，直接从分歧点开始
	var pre := VngStorySession.new(VngServices.for_tests(9), story.manifest, story.chapters)
	assert_true(pre.start("chapter3.evening"))
	pre.advance()
	var save := pre.save_data()
	save["save_seq"] = 1
	var store := VngSaveStore.new(TEST_SAVE_ROOT)
	assert_eq(store.write("slot1", save), OK)

	var main: Node = MainScene.instantiate()
	VngRun.tree.root.add_child(main)
	await VngRun.tree.process_frame
	main.services.save_root = TEST_SAVE_ROOT
	main.services.settings = VngSettings.new(TEST_SETTINGS_PATH, false)
	main.services.settings.text_speed = 100000.0
	main.services.read_log = VngReadLog.new(TEST_READ_ROOT)
	main._show_title()
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame

	var title: Control = main._current_screen
	await _click(title.continue_button)
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame

	var screen: Control = main._current_screen
	assert_eq(screen.session.current_chapter, "chapter3")

	# 选择「待在家里」并推进到结局
	var choice_menu: VBoxContainer = screen.get_node("ChoiceMenu")
	var target: Button = null
	for child in choice_menu.get_children():
		if (child as Button).text == "待在家里":
			target = child
	assert_not_null(target, "夜晚分歧应包含「待在家里」")
	await _click(target)
	await VngRun.tree.process_frame
	for i in 2:
		await VngInputSim.press_action(VngRun.tree, "ui_accept")
		await VngRun.tree.process_frame

	var deadline := Time.get_ticks_msec() + 4000
	while main._current_screen.name != "EndingScreen" and Time.get_ticks_msec() < deadline:
		await VngRun.tree.process_frame
	var ending_screen: Control = main._current_screen
	assert_eq(ending_screen.name, "EndingScreen", "故事结束后应进入结局页面")
	assert_eq((ending_screen.get_node("Panel/Title") as Label).text, "结局 · 一个人的雨")
	assert_eq((ending_screen.get_node("Panel/Subtitle") as Label).text, "你把那一晚，留在了原地。")

	await _click(ending_screen.get_node("Panel/ContinueButton"))
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame
	assert_eq(main._current_screen.name, "TitleScreen", "结局页应能回到标题")

	main.queue_free()
	await VngRun.tree.process_frame


func _click(control: Control) -> void:
	await VngInputSim.click(VngRun.tree, control.get_global_rect().get_center())
