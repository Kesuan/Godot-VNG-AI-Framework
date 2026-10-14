class_name VngSettings
extends RefCounted

## 玩家偏好设置：JSON 持久化（默认 user://settings.json）。
## 与存档分离：设置跨存档全局有效，读写失败不影响游戏运行。

const DEFAULT_PATH := "user://settings.json"
const DEFAULT_BGM_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 0.8
const DEFAULT_TEXT_SPEED := 45.0  # 字/秒；<= 0 表示瞬间显示
const DEFAULT_AUTO_DELAY := 1.5   # 行完整显示后自动推进的等待秒数

var path: String
var bgm_volume := DEFAULT_BGM_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var text_speed := DEFAULT_TEXT_SPEED
var auto_delay := DEFAULT_AUTO_DELAY


func _init(p_path: String = DEFAULT_PATH, p_autoload := true) -> void:
	path = p_path
	if p_autoload:
		load_settings()


func load_settings() -> void:
	var data := _read()
	bgm_volume = clampf(_as_float(data.get("bgm_volume", bgm_volume), bgm_volume), 0.0, 1.0)
	sfx_volume = clampf(_as_float(data.get("sfx_volume", sfx_volume), sfx_volume), 0.0, 1.0)
	text_speed = clampf(_as_float(data.get("text_speed", text_speed), text_speed), 0.0, 100000.0)
	auto_delay = clampf(_as_float(data.get("auto_delay", auto_delay), auto_delay), 0.0, 10.0)


func save_settings() -> Error:
	var absolute := ProjectSettings.globalize_path(path)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return dir_error
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"schema": 1,
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"text_speed": text_speed,
		"auto_delay": auto_delay,
	}, "\t", true) + "\n")
	file.close()
	return OK


func _read() -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return {}
	var parsed := _parse_json(FileAccess.get_file_as_string(absolute))
	return parsed


static func _parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


static func _as_float(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return float(value)
	return fallback
