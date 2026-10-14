extends Control

## 回顾面板：展示本次会话的对白 / 旁白 / 选项选择 / 章节分隔。

signal closed

@onready var _scroll: ScrollContainer = $Panel/Scroll
@onready var _list: VBoxContainer = $Panel/Scroll/List
@onready var _back_button: Button = $Panel/BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	hide()


func is_open() -> bool:
	return visible


func open(entries: Array) -> void:
	_clear()
	for entry in entries:
		_list.add_child(_make_label(entry))
	show()
	move_to_front()
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
	_back_button.grab_focus()


func close() -> void:
	hide()


func line_count() -> int:
	return _list.get_child_count()


func _make_label(entry: Dictionary) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kind := str(entry.get("type", "say"))
	var text := str(entry.get("text", ""))
	match kind:
		"choice":
			label.text = "▷ " + text
			label.modulate = Color(0.75, 0.82, 1.0)
		"chapter":
			label.text = "—  %s  —" % text
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.modulate = Color(0.7, 0.7, 0.7)
		_:
			var who := str(entry.get("who", ""))
			label.text = ("%s：%s" % [who, text]) if who != "" else text
	return label


func _on_back_pressed() -> void:
	close()
	closed.emit()


func _clear() -> void:
	for child in _list.get_children():
		child.queue_free()
