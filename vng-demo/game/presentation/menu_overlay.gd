extends Control

## 游戏内菜单：主菜单 / 存档槽 / 读档槽 三态。
## 只负责展示与发出意图，实际存档读写由剧情屏完成。

signal resume_requested
signal title_requested
signal save_requested
signal load_requested
signal settings_requested
signal slot_selected(slot: String)
signal closed

var mode := "closed"  # closed / menu / save / load

var _standalone := false

@onready var _title: Label = $Panel/Title
@onready var _menu_buttons: VBoxContainer = $Panel/MenuButtons
@onready var _slot_list: VBoxContainer = $Panel/SlotList
@onready var _status: Label = $Panel/StatusLabel
@onready var _back_button: Button = $Panel/BackButton


func _ready() -> void:
	_menu_buttons.get_node("ResumeButton").pressed.connect(_on_resume_pressed)
	_menu_buttons.get_node("SaveButton").pressed.connect(_on_save_pressed)
	_menu_buttons.get_node("LoadButton").pressed.connect(_on_load_pressed)
	_menu_buttons.get_node("SettingsButton").pressed.connect(_on_settings_pressed)
	_menu_buttons.get_node("TitleButton").pressed.connect(_on_title_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	hide()


func is_open() -> bool:
	return mode != "closed"


func open_menu() -> void:
	mode = "menu"
	_title.text = "菜单"
	_status.text = ""
	_clear_slots()
	_menu_buttons.visible = true
	_slot_list.visible = false
	_back_button.visible = false
	show()
	(_menu_buttons.get_node("ResumeButton") as Button).grab_focus()


func open_slots(p_mode: String, infos: Array, p_standalone := false) -> void:
	mode = p_mode
	_standalone = p_standalone
	_title.text = "保存到…" if p_mode == "save" else "读取存档"
	_status.text = ""
	_menu_buttons.visible = false
	_slot_list.visible = true
	_back_button.visible = true
	_clear_slots()
	var first: Button = null
	for info in infos:
		var button := Button.new()
		button.text = str(info.get("label", ""))
		button.custom_minimum_size = Vector2(400, 56)
		button.disabled = bool(info.get("disabled", false))
		button.pressed.connect(_on_slot_pressed.bind(str(info.get("slot", ""))))
		_slot_list.add_child(button)
		if first == null and not button.disabled:
			first = button
	show()
	if first != null:
		first.grab_focus()
	else:
		_back_button.grab_focus()


func set_status(text: String) -> void:
	_status.text = text


func slot_buttons() -> Array:
	var buttons: Array = []
	for child in _slot_list.get_children():
		buttons.append(child)
	return buttons


func close() -> void:
	mode = "closed"
	_menu_buttons.visible = true
	_slot_list.visible = false
	_back_button.visible = false
	hide()


func _on_resume_pressed() -> void:
	close()
	resume_requested.emit()


func _on_save_pressed() -> void:
	save_requested.emit()


func _on_load_pressed() -> void:
	load_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_title_pressed() -> void:
	title_requested.emit()


func _on_slot_pressed(slot: String) -> void:
	slot_selected.emit(slot)


func _on_back_pressed() -> void:
	if _standalone:
		close()
		closed.emit()
	else:
		open_menu()


func _clear_slots() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
