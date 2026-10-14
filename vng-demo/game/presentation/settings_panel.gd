extends Control

## 设置面板：音量 / 文字速度 / 自动播放间隔。改动即刻生效并持久化。

signal changed
signal closed

const TEXT_SPEEDS := [20.0, 45.0, 80.0, 0.0]  # 慢 / 标准 / 快 / 瞬间（0 = 瞬间）
const AUTO_DELAYS := [1.0, 1.5, 2.5, 4.0]

var settings: VngSettings = null

var _syncing := false

@onready var _bgm_slider: HSlider = $Panel/BgmRow/Slider
@onready var _bgm_value: Label = $Panel/BgmRow/Value
@onready var _sfx_slider: HSlider = $Panel/SfxRow/Slider
@onready var _sfx_value: Label = $Panel/SfxRow/Value
@onready var _text_speed: OptionButton = $Panel/TextSpeedOption
@onready var _auto_delay: OptionButton = $Panel/AutoDelayOption
@onready var _back_button: Button = $Panel/BackButton


func _ready() -> void:
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_text_speed.item_selected.connect(_on_text_speed_selected)
	_auto_delay.item_selected.connect(_on_auto_delay_selected)
	_back_button.pressed.connect(_on_back_pressed)
	hide()


func is_open() -> bool:
	return visible


func open(p_settings: VngSettings) -> void:
	settings = p_settings
	_sync_controls()
	show()
	move_to_front()
	_back_button.grab_focus()


func close() -> void:
	hide()


func _sync_controls() -> void:
	if settings == null:
		return
	_syncing = true
	_bgm_slider.value = settings.bgm_volume
	_bgm_value.text = "%d%%" % roundi(settings.bgm_volume * 100.0)
	_sfx_slider.value = settings.sfx_volume
	_sfx_value.text = "%d%%" % roundi(settings.sfx_volume * 100.0)
	_text_speed.selected = _closest_index(TEXT_SPEEDS, settings.text_speed)
	_auto_delay.selected = _closest_index(AUTO_DELAYS, settings.auto_delay)
	_syncing = false


func _on_bgm_changed(value: float) -> void:
	if _syncing or settings == null:
		return
	settings.bgm_volume = clampf(value, 0.0, 1.0)
	_bgm_value.text = "%d%%" % roundi(settings.bgm_volume * 100.0)
	_commit()


func _on_sfx_changed(value: float) -> void:
	if _syncing or settings == null:
		return
	settings.sfx_volume = clampf(value, 0.0, 1.0)
	_sfx_value.text = "%d%%" % roundi(settings.sfx_volume * 100.0)
	_commit()


func _on_text_speed_selected(index: int) -> void:
	if _syncing or settings == null:
		return
	settings.text_speed = float(TEXT_SPEEDS[index])
	_commit()


func _on_auto_delay_selected(index: int) -> void:
	if _syncing or settings == null:
		return
	settings.auto_delay = float(AUTO_DELAYS[index])
	_commit()


func _on_back_pressed() -> void:
	close()
	closed.emit()


func _commit() -> void:
	if settings != null:
		settings.save_settings()
	changed.emit()


func _closest_index(values: Array, value: float) -> int:
	var best := 0
	var best_distance := absf(float(values[0]) - value)
	for i in range(1, values.size()):
		var distance := absf(float(values[i]) - value)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best
