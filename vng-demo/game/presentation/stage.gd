extends Control

const PlaceholderAssets := preload("res://game/presentation/placeholder_assets.gd")

const DEFAULT_FADE := 0.35
const CHAR_SIZE := Vector2(260, 440)
const CHAR_BOTTOM_MARGIN := 110.0

@onready var _background: ColorRect = $Background
@onready var _background_label: Label = $BackgroundLabel
@onready var _characters: Control = $Characters

var _char_panels := {}


func show_bg(data: Dictionary) -> void:
	var asset: String = data.get("asset", "")
	var duration := _duration(float(data.get("fade", -1.0)))
	_background_label.text = asset
	var tween := create_tween()
	tween.tween_property(_background, "color", PlaceholderAssets.bg_color(asset), duration)


func show_char(data: Dictionary) -> void:
	var char_id: String = data.get("char", "")
	var expr: String = data.get("expr", "")
	var pos: String = data.get("pos", "")
	var duration := _duration(float(data.get("fade", -1.0)))
	var panel: ColorRect = _char_panels.get(char_id, null)
	if panel == null:
		panel = ColorRect.new()
		panel.color = PlaceholderAssets.char_color(char_id)
		panel.size = CHAR_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag := Label.new()
		tag.name = "Tag"
		tag.position = Vector2(14, 14)
		tag.size = Vector2(CHAR_SIZE.x - 28.0, 140.0)
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag.add_theme_font_size_override("font_size", 20)
		panel.add_child(tag)
		panel.modulate.a = 0.0
		_characters.add_child(panel)
		_char_panels[char_id] = panel
	var ratio: float = PlaceholderAssets.pos_ratio(pos)
	panel.position = Vector2(size.x * ratio - CHAR_SIZE.x * 0.5, size.y - CHAR_SIZE.y - CHAR_BOTTOM_MARGIN)
	(panel.get_node("Tag") as Label).text = "%s\n%s\n%s" % [char_id, expr, pos]
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, duration)


func hide_char(data: Dictionary) -> void:
	var char_id: String = data.get("char", "")
	var panel: ColorRect = _char_panels.get(char_id, null)
	if panel == null:
		return
	_char_panels.erase(char_id)
	var duration := _duration(float(data.get("fade", -1.0)))
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, duration)
	tween.tween_callback(panel.queue_free)


func _duration(fade: float) -> float:
	return fade if fade > 0.0 else DEFAULT_FADE
