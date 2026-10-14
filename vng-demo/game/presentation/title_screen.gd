extends Control

signal start_requested
signal continue_requested
signal load_requested
signal settings_requested
signal quit_requested


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func set_title(text: String) -> void:
	title_label.text = text


func set_saves_visible(shown: bool) -> void:
	continue_button.visible = shown
	continue_button.disabled = not shown
	load_button.visible = shown
	load_button.disabled = not shown


func _on_start_pressed() -> void:
	start_requested.emit()


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_load_pressed() -> void:
	load_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()


@onready var title_label: Label = $Title
@onready var start_button: Button = $StartButton
@onready var continue_button: Button = $ContinueButton
@onready var load_button: Button = $LoadButton
@onready var settings_button: Button = $SettingsButton
@onready var quit_button: Button = $QuitButton
