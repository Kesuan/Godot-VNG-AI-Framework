extends Control

signal finished

const StageScript := preload("res://game/presentation/stage.gd")
const AudioDirectorScript := preload("res://game/presentation/audio_director.gd")

var typewriter_cps := 45.0

@onready var _stage: StageScript = $Stage
@onready var _audio: AudioDirectorScript = $AudioDirector
@onready var _name_label: Label = $NameLabel
@onready var _text_label: Label = $DialoguePanel/TextLabel
@onready var _choice_menu: VBoxContainer = $ChoiceMenu
@onready var _hint_label: Label = $HintLabel
@onready var _fade: ColorRect = $Fade

var services: VngServices
var runtime: VngStoryRuntime
var display_names: Dictionary = {}

var _setup_args: Dictionary = {}
var _typing := false
var _line_length := 0
var _visible_chars := 0.0
var _fade_tween: Tween = null


func setup(p_services: VngServices, chapter: Dictionary, start_node: String, p_display_names: Dictionary = {}) -> void:
	_setup_args = {"services": p_services, "chapter": chapter, "node": start_node}
	display_names = p_display_names


func _ready() -> void:
	if _setup_args.is_empty():
		return
	services = _setup_args.services
	services.input.clear()
	services.events.clear()
	services.events.subscribe("*", _on_event)
	runtime = VngStoryRuntime.new(services, _setup_args.chapter)
	_fade.modulate.a = 1.0
	runtime.start(_setup_args.node)
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
	runtime.pump()


func _exit_tree() -> void:
	if _audio != null:
		_audio.stop_all()
	if services != null:
		services.events.unsubscribe("*", _on_event)


func _unhandled_input(event: InputEvent) -> void:
	if services == null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		return
	if event.is_action_pressed("ui_accept"):
		request_advance()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			request_advance()


func request_advance() -> void:
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
		"story_ended":
			_on_story_ended()


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


func _on_story_ended() -> void:
	_choice_menu.visible = false
	_start_fade(1.0, 0.4)
	if _fade_tween != null:
		_fade_tween.tween_callback(func(): finished.emit())


func _start_fade(target_alpha: float, duration: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "modulate:a", target_alpha, duration)
