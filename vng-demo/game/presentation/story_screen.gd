extends Control

signal finished
signal title_requested

const StageScript := preload("res://game/presentation/stage.gd")
const AudioDirectorScript := preload("res://game/presentation/audio_director.gd")
const AssetLibraryScript := preload("res://game/presentation/asset_library.gd")
const MenuOverlayScript := preload("res://game/presentation/menu_overlay.gd")
const SaveSlotInfoScript := preload("res://game/presentation/save_slot_info.gd")

var typewriter_cps := 45.0

@onready var _stage: StageScript = $Stage
@onready var _audio: AudioDirectorScript = $AudioDirector
@onready var _name_label: Label = $NameLabel
@onready var _text_label: Label = $DialoguePanel/TextLabel
@onready var _choice_menu: VBoxContainer = $ChoiceMenu
@onready var _hint_label: Label = $HintLabel
@onready var _fade: ColorRect = $Fade
@onready var _menu: MenuOverlayScript = $MenuOverlay
@onready var _chapter_card: Label = $ChapterCard

var services: VngServices
var runtime: VngStoryRuntime
var session: VngStorySession
var display_names: Dictionary = {}
var assets: AssetLibraryScript = null
var save_store: VngSaveStore = null

var _setup_args: Dictionary = {}
var _typing := false
var _line_length := 0
var _visible_chars := 0.0
var _fade_tween: Tween = null
var _card_tween: Tween = null


func setup(
	p_services: VngServices,
	chapter: Dictionary,
	start_node: String,
	p_display_names: Dictionary = {},
	p_asset_library: AssetLibraryScript = null
) -> void:
	## 单章便捷入口（测试/简单场景）：包装为一个单章会话。
	var chapter_id: String = chapter.get("chapter", "")
	var manifest := {
		"entry": "%s.%s" % [chapter_id, start_node],
		"chapters": [chapter_id],
	}
	var p_session := VngStorySession.new(p_services, manifest, {chapter_id: chapter})
	setup_session(p_services, p_session, p_display_names, p_asset_library)


func setup_session(
	p_services: VngServices,
	p_session: VngStorySession,
	p_display_names: Dictionary = {},
	p_asset_library: AssetLibraryScript = null
) -> void:
	_setup_args = {"services": p_services, "session": p_session}
	display_names = p_display_names
	assets = p_asset_library


func _ready() -> void:
	if _setup_args.is_empty():
		return
	if assets == null:
		assets = AssetLibraryScript.new()
	services = _setup_args.services
	session = _setup_args.session
	save_store = VngSaveStore.new(services.save_root)
	services.input.clear()
	services.events.clear()
	services.events.subscribe("*", _on_event)
	_stage.assets = assets
	_audio.assets = assets
	_menu.resume_requested.connect(_on_menu_resume)
	_menu.save_requested.connect(_open_save_menu)
	_menu.load_requested.connect(_open_load_menu)
	_menu.title_requested.connect(_on_menu_title)
	_menu.slot_selected.connect(_on_slot_selected)
	_fade.modulate.a = 1.0
	var needs_repaint := session.runtime != null
	if not needs_repaint:
		session.start()
	runtime = session.runtime
	if needs_repaint:
		_repaint_from_state()
	_start_fade(0.0, 0.4)


func _process(delta: float) -> void:
	if services == null:
		return
	services.clock.tick(delta)
	if _typing:
		_visible_chars = minf(float(_line_length), _visible_chars + typewriter_cps * delta)
		_text_label.visible_characters = int(_visible_chars)
		if _visible_chars >= float(_line_length):
			_typing = false
	if session != null:
		session.pump()
		if session.runtime != null:
			runtime = session.runtime


func _exit_tree() -> void:
	if _audio != null:
		_audio.stop_all()
	if services != null:
		services.events.unsubscribe("*", _on_event)


func _unhandled_input(event: InputEvent) -> void:
	if services == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_menu()
		return
	if _menu.is_open():
		return
	if event.is_action_pressed("ui_accept"):
		request_advance()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			request_advance()


func request_advance() -> void:
	if session == null or session.finished or runtime == null:
		return
	if _menu.is_open():
		return
	if _typing:
		_finish_typing()
		return
	if runtime.waiting == VngStoryRuntime.WAITING_CHOICE:
		return
	services.input.push(VngCommand.advance())


func is_typing() -> bool:
	return _typing


func _finish_typing() -> void:
	_typing = false
	_visible_chars = float(_line_length)
	_text_label.visible_characters = -1


func _on_event(entry: Dictionary) -> void:
	var data: Dictionary = entry.get("data", {})
	match entry.get("type", ""):
		"line_shown":
			_show_line(data)
		"choice_presented":
			_show_choices(data)
		"bg_changed", "char_shown", "char_hidden":
			_handle_stage_event(entry.get("type", ""), data)
		"bgm_changed":
			_audio.play_bgm(data.get("asset", ""))
		"sfx_played":
			_audio.play_sfx(data.get("asset", ""))
		"chapter_started":
			_on_chapter_started(data)
		"story_finished":
			_on_story_finished()


func _handle_stage_event(type: String, data: Dictionary) -> void:
	match type:
		"bg_changed":
			_stage.show_bg(data)
		"char_shown":
			_stage.show_char(data)
		"char_hidden":
			_stage.hide_char(data)


func _show_line(data: Dictionary) -> void:
	var who: String = data.get("who", "")
	var display: String = display_names.get(who, who)
	_name_label.text = display
	_name_label.visible = who != ""
	var text: String = data.get("text", "")
	_text_label.text = text
	_line_length = text.length()
	_visible_chars = 0.0
	_typing = _line_length > 0
	_text_label.visible_characters = 0


func _show_choices(data: Dictionary) -> void:
	_clear_choices()
	_finish_typing()
	for option in data.get("options", []):
		var button := Button.new()
		button.text = option.get("text", "")
		button.custom_minimum_size = Vector2(320, 44)
		var index: int = option.get("index", -1)
		button.pressed.connect(_on_choice_pressed.bind(index))
		_choice_menu.add_child(button)
	_choice_menu.visible = true
	_hint_label.visible = false
	if _choice_menu.get_child_count() > 0:
		(_choice_menu.get_child(0) as Button).grab_focus()


func _on_choice_pressed(index: int) -> void:
	_choice_menu.visible = false
	_clear_choices()
	_hint_label.visible = true
	services.input.push(VngCommand.choose(index))


func _clear_choices() -> void:
	for child in _choice_menu.get_children():
		child.queue_free()


func _on_chapter_started(data: Dictionary) -> void:
	_show_chapter_card(session.chapter_title(str(data.get("chapter", ""))))
	call_deferred("_autosave")


func _autosave() -> void:
	if not is_inside_tree() or save_store == null or session == null:
		return
	var data := session.save_data()
	if data.is_empty():
		return
	_write_slot("auto", data)


func _on_story_finished() -> void:
	_choice_menu.visible = false
	_menu.close()
	_start_fade(1.0, 0.4)
	if _fade_tween != null:
		_fade_tween.tween_callback(func(): finished.emit())


func _toggle_menu() -> void:
	if session == null or session.finished:
		return
	if _menu.is_open():
		_menu.close()
	else:
		_menu.open_menu()


func _on_menu_resume() -> void:
	pass


func _on_menu_title() -> void:
	title_requested.emit()


func _open_save_menu() -> void:
	_menu.open_slots("save", _slot_infos("save"))


func _open_load_menu() -> void:
	_menu.open_slots("load", _slot_infos("load"))


func _on_slot_selected(slot: String) -> void:
	if _menu.mode == "save":
		_save_to_slot(slot)
	else:
		_load_from_slot(slot)


func _slot_infos(mode: String) -> Array:
	return SaveSlotInfoScript.infos(save_store, session.manifest, mode)


func _slot_name(slot: String) -> String:
	return SaveSlotInfoScript.slot_name(slot)


func _write_slot(slot: String, data: Dictionary) -> Error:
	data["save_seq"] = save_store.max_sequence() + 1
	return save_store.write(slot, data)


func _save_to_slot(slot: String) -> void:
	var data := session.save_data()
	if data.is_empty():
		_menu.set_status("当前没有可保存的进度")
		return
	var error := _write_slot(slot, data)
	if error != OK:
		_menu.set_status("保存失败: %s" % error_string(error))
		return
	_menu.open_slots("save", _slot_infos("save"))
	_menu.set_status("已保存到「%s」" % _slot_name(slot))


func _load_from_slot(slot: String) -> void:
	var save := save_store.read(slot)
	if save.is_empty():
		_menu.set_status("该槽位为空")
		return
	if not session.load_save(save):
		var message := "读取失败"
		if not session.errors.is_empty():
			message = str(session.errors[session.errors.size() - 1].get("message", message))
		_menu.set_status(message)
		return
	runtime = session.runtime
	_repaint_from_state()
	_menu.close()


func _repaint_from_state() -> void:
	if runtime == null:
		return
	_typing = false
	_clear_choices()
	_choice_menu.visible = false
	_stage.reset()
	var stage_state: Dictionary = runtime.stage
	_stage.show_bg({"asset": str(stage_state.get("bg", ""))})
	var chars: Dictionary = stage_state.get("chars", {})
	for char_id in chars:
		var char_state: Dictionary = chars[char_id]
		_stage.show_char({
			"char": char_id,
			"expr": char_state.get("expr", ""),
			"pos": char_state.get("pos", ""),
		})
	_audio.play_bgm(str(stage_state.get("bgm", "")))
	_hint_label.visible = true
	if runtime.waiting == VngStoryRuntime.WAITING_SAY:
		_show_line(runtime.current_line)
		_finish_typing()
	elif runtime.waiting == VngStoryRuntime.WAITING_CHOICE:
		_show_choices({"options": runtime.visible_choices()})


func _show_chapter_card(title: String) -> void:
	if title.is_empty():
		return
	_chapter_card.text = title
	_chapter_card.modulate.a = 0.0
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	_card_tween = create_tween()
	_card_tween.tween_property(_chapter_card, "modulate:a", 1.0, 0.35)
	_card_tween.tween_interval(1.4)
	_card_tween.tween_property(_chapter_card, "modulate:a", 0.0, 0.6)


func _start_fade(target_alpha: float, duration: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "modulate:a", target_alpha, duration)
