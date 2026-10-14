extends Control

## 结局页面：展示达成的结局（标题 / 副标题），回到标题。

signal continue_requested

var _ending: Dictionary = {}

@onready var _title: Label = $Panel/Title
@onready var _subtitle: Label = $Panel/Subtitle
@onready var _continue_button: Button = $Panel/ContinueButton
@onready var _fade: ColorRect = $Fade


func setup(ending: Dictionary) -> void:
	_ending = ending


func _ready() -> void:
	_title.text = str(_ending.get("title", "完"))
	var subtitle := str(_ending.get("subtitle", ""))
	_subtitle.text = subtitle
	_subtitle.visible = subtitle != ""
	_continue_button.pressed.connect(_on_continue_pressed)
	_fade.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, 0.5)


func _on_continue_pressed() -> void:
	continue_requested.emit()
