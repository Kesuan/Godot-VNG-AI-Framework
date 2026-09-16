extends Control

signal start_requested
signal quit_requested


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func set_title(text: String) -> void:
	title_label.text = text


func _on_start_pressed() -> void:
	start_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()


@onready var title_label: Label = $Title
@onready var start_button: Button = $StartButton
@onready var quit_button: Button = $QuitButton
