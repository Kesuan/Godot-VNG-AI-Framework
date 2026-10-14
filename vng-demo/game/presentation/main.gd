extends Node

const VnsStoryLoader := preload("res://addons/vns/vns_story.gd")
const TitleScreenScene := preload("res://game/presentation/title_screen.tscn")
const StoryScreenScene := preload("res://game/presentation/story_screen.tscn")
const EndingScreenScene := preload("res://game/presentation/ending_screen.tscn")
const MenuOverlayScene := preload("res://game/presentation/menu_overlay.tscn")
const SettingsPanelScene := preload("res://game/presentation/settings_panel.tscn")
const SaveSlotInfoScript := preload("res://game/presentation/save_slot_info.gd")

const SAVE_SLOTS := ["auto", "slot1", "slot2", "slot3"]

var boot: VngBootConfig
var services: VngServices
var story: Dictionary = {}

var _current_screen: Node = null
var _load_overlay: Control = null
var _settings_panel: Control = null


func _ready() -> void:
	boot = VngBootConfig.from_cmdline()
	for error in boot.errors:
		push_error("BootConfig: %s" % error)
	services = VngServices.new(boot.seed)
	services.save_root = boot.save_root
	story = VnsStoryLoader.load_compiled("res://game/story")
	if not story.ok:
		_show_failure(story.errors)
		return
	_show_title()


func _show_title() -> void:
	_close_load_overlay()
	_close_settings()
	var screen: Node = TitleScreenScene.instantiate()
	screen.start_requested.connect(_start_story)
	screen.continue_requested.connect(_continue_story)
	screen.load_requested.connect(_open_load_menu)
	screen.settings_requested.connect(_open_settings)
	screen.quit_requested.connect(_quit)
	_swap_screen(screen)
	screen.set_saves_visible(not _latest_save().is_empty())


func _start_story() -> void:
	var session := _new_session()
	var entry := session.entry_for(session.first_chapter_id())
	if session.resolve_entry(entry).is_empty():
		_show_failure(session.errors)
		return
	_show_story(session)


func _continue_story() -> void:
	var save := _latest_save()
	if save.is_empty():
		_show_title()
		return
	var session := _new_session()
	if not session.load_save(save):
		_show_failure(session.errors)
		return
	_show_story(session)


func _open_load_menu() -> void:
	if _load_overlay == null or not is_instance_valid(_load_overlay):
		_load_overlay = MenuOverlayScene.instantiate()
		add_child(_load_overlay)
		_load_overlay.slot_selected.connect(_on_load_slot_selected)
	_load_overlay.open_slots("load", SaveSlotInfoScript.infos(_save_store(), story.manifest, "load"), true)
	_load_overlay.move_to_front()


func _on_load_slot_selected(slot: String) -> void:
	var save := _save_store().read(slot)
	if save.is_empty():
		_load_overlay.set_status("%s 为空" % SaveSlotInfoScript.slot_name(slot))
		return
	var session := _new_session()
	if not session.load_save(save):
		var errors := session.errors
		var message := "读取失败"
		if not errors.is_empty():
			message = str(errors[errors.size() - 1].get("message", message))
		_load_overlay.set_status(message)
		return
	_show_story(session)


func _close_load_overlay() -> void:
	if _load_overlay != null and is_instance_valid(_load_overlay):
		_load_overlay.close()


func _open_settings() -> void:
	if _settings_panel == null or not is_instance_valid(_settings_panel):
		_settings_panel = SettingsPanelScene.instantiate()
		add_child(_settings_panel)
	_settings_panel.open(services.settings)


func _close_settings() -> void:
	if _settings_panel != null and is_instance_valid(_settings_panel):
		_settings_panel.close()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_panel != null and is_instance_valid(_settings_panel) and _settings_panel.is_open():
		_close_settings()
		get_viewport().set_input_as_handled()
		return
	if _load_overlay != null and is_instance_valid(_load_overlay) and _load_overlay.is_open():
		_close_load_overlay()
		get_viewport().set_input_as_handled()


func _new_session() -> VngStorySession:
	return VngStorySession.new(services, story.get("manifest", {}), story.get("chapters", {}))


func _show_story(session: VngStorySession) -> void:
	_close_load_overlay()
	_close_settings()
	var screen: Node = StoryScreenScene.instantiate()
	screen.setup_session(services, session, _display_names())
	screen.finished.connect(_on_story_finished.bind(session))
	screen.title_requested.connect(_show_title)
	_swap_screen(screen)


func _on_story_finished(session: VngStorySession) -> void:
	var ending: Dictionary = session.ending()
	if ending.is_empty():
		_show_title()
		return
	_show_ending(ending)


func _show_ending(ending: Dictionary) -> void:
	var screen: Node = EndingScreenScene.instantiate()
	screen.setup(ending)
	screen.continue_requested.connect(_show_title)
	_swap_screen(screen)


func _save_store() -> VngSaveStore:
	return VngSaveStore.new(services.save_root)


func _latest_save() -> Dictionary:
	var store := _save_store()
	var best: Dictionary = {}
	var best_seq := -1
	var best_time := -1.0
	for slot in SAVE_SLOTS:
		var save := store.read(slot)
		if save.is_empty():
			continue
		var seq := int(save.get("save_seq", 0))
		var play_time := float(save.get("play_time", 0.0))
		if seq > best_seq or (seq == best_seq and play_time > best_time):
			best_seq = seq
			best_time = play_time
			best = save
	return best


func _display_names() -> Dictionary:
	var names := {}
	var characters: Dictionary = story.manifest.get("characters", {})
	for char_id in characters:
		var definition: Dictionary = characters[char_id]
		names[char_id] = definition.get("name", char_id)
	return names


func _quit() -> void:
	get_tree().quit()


func _swap_screen(screen: Node) -> void:
	if _current_screen != null and is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = screen
	add_child(screen)


func _show_failure(errors: Array) -> void:
	for error in errors:
		push_error("剧本加载失败: %s" % error.get("message", ""))
	var label := Label.new()
	label.text = "剧本加载失败，请查看控制台输出"
	label.position = Vector2(80, 80)
	add_child(label)
