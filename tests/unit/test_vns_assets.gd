# @tag fast
extends VngTest

const Paths := preload("res://addons/vns/vns_asset_paths.gd")
const Report := preload("res://addons/vns/vns_asset_report.gd")

const ROOT := "user://vng_test_assets"


func before_each() -> void:
	_clean_dir(ROOT)


func test_bg_candidates_order() -> void:
	var candidates := Paths.bg_candidates("station_rain", ROOT)
	assert_eq(candidates.size(), 3)
	assert_eq(candidates[0], ROOT + "/bg/station_rain.png")
	assert_eq(candidates[1], ROOT + "/bg/station_rain.webp")
	assert_eq(candidates[2], ROOT + "/bg/station_rain.jpg")


func test_char_candidates_include_default_fallback() -> void:
	var candidates := Paths.char_candidates("rin", "smile", ROOT)
	assert_eq(candidates.size(), 6)
	assert_eq(candidates[0], ROOT + "/char/rin/smile.png")
	assert_eq(candidates[3], ROOT + "/char/rin/default.png")
	assert_eq(Paths.char_candidates("rin", "default", ROOT).size(), 3)
	assert_eq(Paths.char_candidates("rin", "", ROOT).size(), 0)


func test_audio_candidates() -> void:
	assert_eq(Paths.bgm_candidates("bgm_rain", ROOT)[0], ROOT + "/audio/bgm/bgm_rain.ogg")
	assert_eq(Paths.sfx_candidates("thunder", ROOT)[1], ROOT + "/audio/sfx/thunder.wav")


func test_first_existing_prefers_declared_order() -> void:
	_touch(ROOT + "/bg/both.webp")
	_touch(ROOT + "/bg/both.png")
	assert_eq(Paths.first_existing(Paths.bg_candidates("both", ROOT)), ROOT + "/bg/both.png")
	assert_eq(Paths.first_existing(Paths.bg_candidates("none", ROOT)), "")


func test_report_finds_and_reports_missing() -> void:
	_touch(ROOT + "/bg/present_bg.png")
	_touch(ROOT + "/char/rin/default.png")
	_touch(ROOT + "/audio/bgm/bgm_rain.ogg")
	var report := Report.build(_chapters(), _manifest(), ROOT)
	assert_eq(report.summary.total, 5)
	assert_eq(report.summary.found, 3)
	assert_eq(report.summary.missing, 2)
	assert_false(report.ok)
	var bg_entry: Variant = _entry(report, "bg/present_bg")
	assert_not_null(bg_entry)
	assert_eq(bg_entry.found, ROOT + "/bg/present_bg.png")
	assert_false(bg_entry.fallback)
	var char_entry: Variant = _entry(report, "char/rin/smile")
	assert_not_null(char_entry)
	assert_true(char_entry.fallback)
	assert_eq(char_entry.found, ROOT + "/char/rin/default.png")
	var missing_entry: Variant = _entry(report, "sfx/missing_sfx")
	assert_not_null(missing_entry)
	assert_eq(missing_entry.found, "")


func test_report_ignores_bgm_stop_and_hide() -> void:
	var report := Report.build(_chapters(), _manifest(), ROOT)
	for entry in report.entries:
		assert_ne(entry.get("id", ""), "stop")
		assert_ne(entry.get("kind", ""), "hide")


func test_report_format_contains_checklist() -> void:
	_touch(ROOT + "/bg/present_bg.png")
	var report := Report.build(_chapters(), _manifest(), ROOT)
	var text := Report.format(report)
	assert_true(text.contains("[x] bg/present_bg"))
	assert_true(text.contains("[ ] bg/absent_bg"))
	assert_true(text.contains("待投放"))
	assert_true(text.contains("未使用"))


func test_unused_manifest_entries() -> void:
	var report := Report.build(_chapters(), _manifest(), ROOT)
	var labels: Array = []
	for entry in report.unused:
		labels.append("%s/%s" % [entry.get("kind", ""), entry.get("id", "")])
	assert_in("bg/unused_bg", labels)


func _chapters() -> Dictionary:
	return {
		"chapter1": {
			"nodes": {
				"start": {
					"steps": [
						{"op": "bg", "asset": "present_bg"},
						{"op": "bg", "asset": "absent_bg"},
						{"op": "bgm", "asset": "bgm_rain"},
						{"op": "bgm", "asset": "stop"},
						{"op": "sfx", "asset": "missing_sfx"},
						{"op": "show", "char": "rin", "expr": "smile"},
						{"op": "hide", "char": "rin"},
						{"op": "goto", "target": "END"},
					],
				},
			},
		},
	}


func _manifest() -> Dictionary:
	return {
		"assets": {
			"bg": ["present_bg", "absent_bg", "unused_bg"],
			"bgm": ["bgm_rain"],
			"sfx": ["missing_sfx"],
		},
	}


func _entry(report: Dictionary, label: String) -> Variant:
	for entry in report.entries:
		if entry.get("label", "") == label:
			return entry
	return null


func _touch(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_string("x")
	file.close()


func _clean_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir := DirAccess.open(absolute)
	_remove_recursive(dir)
	DirAccess.remove_absolute(absolute)


func _remove_recursive(dir: DirAccess) -> void:
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	for sub_dir in dir.get_directories():
		var child := DirAccess.open(dir.get_current_dir().path_join(sub_dir))
		_remove_recursive(child)
		dir.remove(sub_dir)
