extends Control

const PlaceholderAssets := preload("res://game/presentation/placeholder_assets.gd")
const AssetLibraryScript := preload("res://game/presentation/asset_library.gd")

const DEFAULT_FADE := 0.35
const CHAR_SLOT := Vector2(520, 600)
const CHAR_PLACEHOLDER_SIZE := Vector2(260, 440)
const CHAR_BOTTOM_MARGIN := 110.0

@onready var _background: ColorRect = $Background
@onready var _background_image: TextureRect = $BackgroundImage
@onready var _background_label: Label = $BackgroundLabel
@onready var _characters: Control = $Characters

var assets: AssetLibraryScript = null

var _current_bg := ""
var _char_panels := {}
var _char_states := {}


func show_bg(data: Dictionary) -> void:
	var asset: String = data.get("asset", "")
	if asset == _current_bg:
		return
	_current_bg = asset
	var duration := _duration(float(data.get("fade", -1.0)))
	_background_label.text = asset
	var texture: Texture2D = assets.background(asset) if assets != null else null
	if texture != null:
		_background_image.texture = texture
		_background_image.visible = true
		_background_image.modulate.a = 0.0
		_background_label.visible = false
		var image_tween := create_tween()
		image_tween.tween_property(_background_image, "modulate:a", 1.0, duration)
	else:
		_background_image.texture = null
		_background_image.visible = false
		_background_label.visible = true
		var color_tween := create_tween()
		color_tween.tween_property(_background, "color", PlaceholderAssets.bg_color(asset), duration)


func show_char(data: Dictionary) -> void:
	var char_id: String = data.get("char", "")
	var expr: String = data.get("expr", "")
	var pos: String = data.get("pos", "")
	var duration := _duration(float(data.get("fade", -1.0)))
	var panel: Control = _char_panels.get(char_id, null)
	if panel == null:
		panel = _create_char_panel(char_id)
		_char_panels[char_id] = panel
	var ratio: float = PlaceholderAssets.pos_ratio(pos)
	panel.position = Vector2(size.x * ratio - CHAR_SLOT.x * 0.5, size.y - CHAR_BOTTOM_MARGIN - CHAR_SLOT.y)

	var texture: Texture2D = assets.character(char_id, expr) if assets != null else null
	var state := {"expr": expr, "pos": pos, "texture": texture}
	if _char_states.get(char_id, {}) == state:
		return
	_char_states[char_id] = state

	var sprite: TextureRect = panel.get_node("Sprite")
	var placeholder: ColorRect = panel.get_node("Placeholder")
	var tag: Label = panel.get_node("Tag")
	sprite.texture = texture
	sprite.visible = texture != null
	placeholder.visible = texture == null
	tag.visible = texture == null
	tag.text = "%s\n%s\n%s" % [char_id, expr, pos]
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, duration)


func hide_char(data: Dictionary) -> void:
	var char_id: String = data.get("char", "")
	var panel: Control = _char_panels.get(char_id, null)
	if panel == null:
		return
	_char_panels.erase(char_id)
	_char_states.erase(char_id)
	var duration := _duration(float(data.get("fade", -1.0)))
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, duration)
	tween.tween_callback(panel.queue_free)


func _create_char_panel(char_id: String) -> Control:
	var panel := Control.new()
	panel.name = char_id
	panel.size = CHAR_SLOT
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0

	var placeholder := ColorRect.new()
	placeholder.name = "Placeholder"
	placeholder.color = PlaceholderAssets.char_color(char_id)
	placeholder.size = CHAR_PLACEHOLDER_SIZE
	placeholder.position = Vector2((CHAR_SLOT.x - CHAR_PLACEHOLDER_SIZE.x) * 0.5, CHAR_SLOT.y - CHAR_PLACEHOLDER_SIZE.y)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(placeholder)

	var sprite := TextureRect.new()
	sprite.name = "Sprite"
	sprite.size = CHAR_SLOT
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.visible = false
	panel.add_child(sprite)

	var tag := Label.new()
	tag.name = "Tag"
	tag.position = placeholder.position + Vector2(14, 14)
	tag.size = Vector2(CHAR_PLACEHOLDER_SIZE.x - 28.0, 140.0)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.add_theme_font_size_override("font_size", 20)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tag)

	_characters.add_child(panel)
	return panel


func _duration(fade: float) -> float:
	return fade if fade > 0.0 else DEFAULT_FADE
