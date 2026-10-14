# @tag fast
extends VngTest

const PATH := "user://vng_test/settings_probe.json"


func before_each() -> void:
	_remove_file()


func after_each() -> void:
	_remove_file()


func test_defaults_when_file_missing() -> void:
	var settings := VngSettings.new(PATH, true)
	assert_eq(settings.bgm_volume, VngSettings.DEFAULT_BGM_VOLUME)
	assert_eq(settings.sfx_volume, VngSettings.DEFAULT_SFX_VOLUME)
	assert_eq(settings.text_speed, VngSettings.DEFAULT_TEXT_SPEED)
	assert_eq(settings.auto_delay, VngSettings.DEFAULT_AUTO_DELAY)


func test_round_trip() -> void:
	var first := VngSettings.new(PATH, false)
	first.bgm_volume = 0.3
	first.sfx_volume = 0.6
	first.text_speed = 80.0
	first.auto_delay = 2.5
	assert_eq(first.save_settings(), OK)
	var second := VngSettings.new(PATH, true)
	assert_eq(second.bgm_volume, 0.3)
	assert_eq(second.sfx_volume, 0.6)
	assert_eq(second.text_speed, 80.0)
	assert_eq(second.auto_delay, 2.5)


func test_corrupted_file_falls_back_to_defaults() -> void:
	_write_text("{ not valid json")
	var settings := VngSettings.new(PATH, true)
	assert_eq(settings.bgm_volume, VngSettings.DEFAULT_BGM_VOLUME)
	assert_eq(settings.text_speed, VngSettings.DEFAULT_TEXT_SPEED)


func test_values_are_clamped() -> void:
	_write_text('{"bgm_volume": 5, "sfx_volume": -2, "text_speed": -10, "auto_delay": 999}')
	var settings := VngSettings.new(PATH, true)
	assert_eq(settings.bgm_volume, 1.0)
	assert_eq(settings.sfx_volume, 0.0)
	assert_eq(settings.text_speed, 0.0)
	assert_eq(settings.auto_delay, 10.0)


func test_missing_keys_keep_defaults() -> void:
	_write_text('{"bgm_volume": 0.5}')
	var settings := VngSettings.new(PATH, true)
	assert_eq(settings.bgm_volume, 0.5)
	assert_eq(settings.sfx_volume, VngSettings.DEFAULT_SFX_VOLUME)
	assert_eq(settings.text_speed, VngSettings.DEFAULT_TEXT_SPEED)


func _write_text(text: String) -> void:
	var absolute := ProjectSettings.globalize_path(PATH)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_file() -> void:
	var absolute := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
