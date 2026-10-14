# @tag story
extends VngTest

const StoryScreenScene := preload("res://game/presentation/story_screen.tscn")
const VngInputSim := preload("res://addons/vng_test/dsl/input_sim.gd")

const TEST_READ_ROOT := "user://vng_test/read"
const TEST_SETTINGS_PATH := "user://vng_test/settings.json"


func before_each() -> void:
	VngRun.tree.root.size = Vector2i(1280, 720)
	_clear_read_root()
	_remove_settings()


func test_instant_text_speed_shows_full_line() -> void:
	var services := VngServices.for_tests(3)
	services.settings.text_speed = 0.0
	var screen := _screen(services, _line_chapter())
	await VngRun.tree.process_frame
	var text_label: Label = screen.get_node("DialoguePanel/TextLabel")
	assert_eq(text_label.text, "第一行。")
	assert_eq(text_label.visible_characters, -1, "瞬间速度应直接显示完整行")

	screen.queue_free()
	await VngRun.tree.process_frame


func test_volume_applied_from_settings() -> void:
	var services := VngServices.for_tests(3)
	services.settings.bgm_volume = 0.25
	services.settings.sfx_volume = 0.0
	var screen := _screen(services, _line_chapter())
	await VngRun.tree.process_frame
	var bgm: AudioStreamPlayer = screen.get_node("AudioDirector/Bgm")
	var sfx: AudioStreamPlayer = screen.get_node("AudioDirector/Sfx")
	assert_near(bgm.volume_db, linear_to_db(0.25), 0.01, "BGM 音量应来自设置")
	assert_near(sfx.volume_db, -80.0, 0.01, "0 音量应静音")

	screen.queue_free()
	await VngRun.tree.process_frame


func test_skip_holds_read_lines_and_stops_at_unread() -> void:
	var services := VngServices.for_tests(3)
	services.settings.text_speed = 100000.0
	var chapter := _line_chapter()
	var session := _session(services, chapter)
	services.read_log.bind(session.story_hash)
	services.read_log.mark_read(VngReadLog.line_key("", "第一行。"))
	services.read_log.mark_read(VngReadLog.line_key("rin", "第二行。"))

	var screen := _screen_with_session(services, session)
	await VngRun.tree.process_frame
	var text_label: Label = screen.get_node("DialoguePanel/TextLabel")
	assert_eq(text_label.text, "第一行。")

	_hold_action("vng_skip")
	for i in 5:
		await VngRun.tree.process_frame
	assert_eq(text_label.text, "第三行。", "跳过应停在第一个未读行")
	_release_action("vng_skip")

	# 未读行不会被跳过，即使继续按住
	_hold_action("vng_skip")
	for i in 5:
		await VngRun.tree.process_frame
	assert_eq(text_label.text, "第三行。", "未读行必须停下")
	_release_action("vng_skip")

	screen.queue_free()
	await VngRun.tree.process_frame


func test_auto_advances_and_stops_at_choice() -> void:
	var services := VngServices.for_tests(3)
	services.settings.text_speed = 0.0
	services.settings.auto_delay = 0.05
	var screen := _screen(services, _choice_chapter())
	await VngRun.tree.process_frame
	var text_label: Label = screen.get_node("DialoguePanel/TextLabel")
	var choice_menu: VBoxContainer = screen.get_node("ChoiceMenu")

	await VngInputSim.press_action(VngRun.tree, "vng_auto")
	assert_true(screen.is_auto())
	for i in 40:
		await VngRun.tree.process_frame
	assert_true(choice_menu.visible, "自动播放应推进到选项")
	var text_before := text_label.text
	for i in 20:
		await VngRun.tree.process_frame
	assert_eq(text_label.text, text_before, "自动播放不得越过选项")
	assert_true(choice_menu.visible)

	screen.queue_free()
	await VngRun.tree.process_frame


func test_backlog_records_lines_choices_and_chapters() -> void:
	var services := VngServices.for_tests(3)
	services.settings.text_speed = 100000.0
	var screen := _screen(services, _choice_chapter())
	await VngRun.tree.process_frame

	# 推进到选项并选择第一项
	await VngInputSim.press_action(VngRun.tree, "ui_accept")
	await VngInputSim.press_action(VngRun.tree, "ui_accept")
	var choice_menu: VBoxContainer = screen.get_node("ChoiceMenu")
	assert_true(choice_menu.visible)
	await _click(choice_menu.get_child(0) as Control)
	await VngRun.tree.process_frame

	var entries: Array = screen.backlog_entries()
	var texts: Array = []
	for entry in entries:
		texts.append(str((entry as Dictionary).get("text", "")))
	assert_eq(str((entries[0] as Dictionary).get("type", "")), "chapter")
	assert_in("自动一。", texts)
	assert_in("自动二。", texts)
	assert_in("选项甲", texts, "选项选择应进入回顾")

	await VngInputSim.press_action(VngRun.tree, "vng_backlog")
	await VngRun.tree.process_frame
	var panel: Control = screen.backlog_panel()
	assert_not_null(panel)
	assert_true(panel.is_open(), "B 应打开回顾面板")
	assert_eq(panel.line_count(), entries.size())

	await VngInputSim.press_action(VngRun.tree, "ui_cancel")
	await VngRun.tree.process_frame
	assert_false(panel.is_open(), "ESC 应关闭回顾面板")

	screen.queue_free()
	await VngRun.tree.process_frame
	assert_eq(services.events.listener_count("*", true), 0, "销毁后应解除订阅")


func test_settings_panel_updates_text_speed_live() -> void:
	var services := VngServices.for_tests(3)
	var screen := _screen(services, _line_chapter())
	await VngRun.tree.process_frame

	await VngInputSim.press_action(VngRun.tree, "ui_cancel")
	var menu: Control = screen.get_node("MenuOverlay")
	await _click(menu.get_node("Panel/MenuButtons/SettingsButton"))
	await VngRun.tree.process_frame
	var panel: Control = screen.settings_panel()
	assert_not_null(panel)
	assert_true(panel.is_open(), "菜单应能打开设置面板")

	var option: OptionButton = panel.get_node("Panel/TextSpeedOption")
	option.selected = 0
	option.item_selected.emit(0)
	await VngRun.tree.process_frame
	assert_eq(services.settings.text_speed, 20.0, "选择“慢”应写入 20 字/秒")
	assert_eq(screen.typewriter_cps, 20.0, "文字速度应即时生效")
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(TEST_SETTINGS_PATH)), "设置应持久化")

	await VngInputSim.press_action(VngRun.tree, "ui_cancel")
	await VngRun.tree.process_frame
	assert_false(panel.is_open(), "ESC 应关闭设置面板")

	screen.queue_free()
	await VngRun.tree.process_frame


func _screen(services: VngServices, chapter: Dictionary) -> Control:
	return _screen_with_session(services, _session(services, chapter))


func _screen_with_session(services: VngServices, session: VngStorySession) -> Control:
	var screen: Control = StoryScreenScene.instantiate()
	screen.setup_session(services, session)
	VngRun.tree.root.add_child(screen)
	return screen


func _session(services: VngServices, chapter: Dictionary) -> VngStorySession:
	var chapter_id := str(chapter.get("chapter", ""))
	var manifest := {"entry": "%s.start" % chapter_id, "chapters": [chapter_id]}
	return VngStorySession.new(services, manifest, {chapter_id: chapter})


func _line_chapter() -> Dictionary:
	return {
		"chapter": "exp_lines",
		"nodes": {
			"start": {
				"id": "start",
				"steps": [
					{"op": "say", "who": "", "text": "第一行。"},
					{"op": "say", "who": "rin", "text": "第二行。"},
					{"op": "say", "who": "", "text": "第三行。"},
					{"op": "goto", "target": "END"},
				],
			},
		},
	}


func _choice_chapter() -> Dictionary:
	return {
		"chapter": "exp_choice",
		"nodes": {
			"start": {
				"id": "start",
				"steps": [
					{"op": "say", "who": "", "text": "自动一。"},
					{"op": "say", "who": "", "text": "自动二。"},
					{
						"op": "choice",
						"options": [
							{"text": "选项甲", "target": "END"},
							{"text": "选项乙", "target": "END"},
						],
					},
				],
			},
		},
	}


func _click(control: Control) -> void:
	await VngInputSim.click(VngRun.tree, control.get_global_rect().get_center())


func _hold_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	VngRun.tree.root.push_input(event)


func _release_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	VngRun.tree.root.push_input(event)


func _clear_read_root() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_READ_ROOT)
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))


func _remove_settings() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
