# @tag story
extends VngTest

const StoryScreenScene := preload("res://game/presentation/story_screen.tscn")
const AssetLibraryScript := preload("res://game/presentation/asset_library.gd")

const ASSET_ROOT := "user://vng_test_assets"


func before_each() -> void:
	_clean_dir(ASSET_ROOT)
	_write_png(ASSET_ROOT + "/bg/test_bg.png", Color(0.2, 0.4, 0.8))
	_write_png(ASSET_ROOT + "/char/rin/smile.png", Color(0.8, 0.4, 0.4))
	_write_png(ASSET_ROOT + "/char/lin/default.png", Color(0.4, 0.8, 0.4))
	_write_wav(ASSET_ROOT + "/audio/bgm/test_bgm.wav")
	VngRun.tree.root.size = Vector2i(1280, 720)


func test_background_and_audio_hit_and_missing() -> void:
	var screen: Control = await _start_screen(_media_chapter())
	var image: TextureRect = screen.get_node("Stage/BackgroundImage")
	var label: Label = screen.get_node("Stage/BackgroundLabel")
	var bgm: AudioStreamPlayer = screen.get_node("AudioDirector/Bgm")
	var sfx: AudioStreamPlayer = screen.get_node("AudioDirector/Sfx")

	assert_not_null(image.texture, "存在 bg/test_bg.png 时应使用真实贴图")
	assert_true(image.visible)
	assert_false(label.visible)
	assert_not_null(bgm.stream, "存在 bgm/test_bgm.wav 时应加载音频")
	assert_eq(screen.get_node("AudioDirector").current_bgm, "test_bgm")

	await _advance(screen)
	assert_null(image.texture, "缺少 bg/missing_bg 时应回退占位")
	assert_false(image.visible)
	assert_true(label.visible)
	assert_eq(label.text, "missing_bg")
	assert_null(sfx.stream, "缺少 sfx/missing_sfx 时不应有音频流")

	var missing: PackedStringArray = screen.assets.missing_report()
	assert_in("bg/missing_bg", missing)
	assert_in("sfx/missing_sfx", missing)

	screen.queue_free()
	await VngRun.tree.process_frame


func test_character_texture_default_fallback_and_placeholder() -> void:
	var screen: Control = await _start_screen(_char_chapter())
	var rin: Control = screen.get_node("Stage/Characters/rin")
	assert_true((rin.get_node("Sprite") as TextureRect).visible, "存在 char/rin/smile.png 时应显示贴图")
	assert_not_null((rin.get_node("Sprite") as TextureRect).texture)
	assert_false((rin.get_node("Placeholder") as ColorRect).visible)
	assert_false((rin.get_node("Tag") as Label).visible)

	await _advance(screen)
	var lin: Control = screen.get_node("Stage/Characters/lin")
	assert_true((lin.get_node("Sprite") as TextureRect).visible, "缺少 angry 时应回退到 default")
	assert_not_null((lin.get_node("Sprite") as TextureRect).texture)

	await _advance(screen)
	var ghost: Control = screen.get_node("Stage/Characters/ghost")
	assert_true((ghost.get_node("Placeholder") as ColorRect).visible, "无任何立绘文件时应回退占位色块")
	assert_false((ghost.get_node("Sprite") as TextureRect).visible)
	assert_true((ghost.get_node("Tag") as Label).visible)
	assert_in("char/ghost/smile", screen.assets.missing_report())

	await _advance(screen)
	assert_true(screen.runtime.ended)
	assert_eq(screen.runtime.errors.size(), 0)

	screen.queue_free()
	await VngRun.tree.process_frame


func test_asset_library_caches_and_records_missing() -> void:
	var library := AssetLibraryScript.new(ASSET_ROOT)
	var first := library.background("test_bg")
	var second := library.background("test_bg")
	assert_not_null(first)
	assert_eq(first, second, "同一资源应命中缓存")
	assert_null(library.background("nope_bg"))
	assert_eq(library.missing_report().size(), 1)
	assert_in("bg/nope_bg", library.missing_report())


func _start_screen(chapter: Dictionary) -> Control:
	var services := VngServices.new(3)
	var screen: Control = StoryScreenScene.instantiate()
	screen.typewriter_cps = 100000.0
	screen.setup(services, chapter, "start", {}, AssetLibraryScript.new(ASSET_ROOT))
	VngRun.tree.root.add_child(screen)
	await VngRun.tree.process_frame
	return screen


func _advance(screen: Control) -> void:
	var services: VngServices = screen.services
	services.input.push(VngCommand.advance())
	await VngRun.tree.process_frame
	await VngRun.tree.process_frame


func _media_chapter() -> Dictionary:
	return {
		"chapter": "asset_media",
		"nodes": {
			"start": {
				"id": "start",
				"steps": [
					{"op": "bg", "asset": "test_bg"},
					{"op": "bgm", "asset": "test_bgm"},
					{"op": "say", "who": "", "text": "第一句。"},
					{"op": "bg", "asset": "missing_bg"},
					{"op": "sfx", "asset": "missing_sfx"},
					{"op": "say", "who": "", "text": "第二句。"},
					{"op": "goto", "target": "END"},
				],
			},
		},
	}


func _char_chapter() -> Dictionary:
	return {
		"chapter": "asset_char",
		"nodes": {
			"start": {
				"id": "start",
				"steps": [
					{"op": "show", "char": "rin", "expr": "smile", "pos": "center"},
					{"op": "say", "who": "", "text": "A"},
					{"op": "show", "char": "lin", "expr": "angry", "pos": "right"},
					{"op": "say", "who": "", "text": "B"},
					{"op": "show", "char": "ghost", "expr": "smile", "pos": "left"},
					{"op": "say", "who": "", "text": "C"},
					{"op": "goto", "target": "END"},
				],
			},
		},
	}


func _write_png(path: String, color: Color) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.save_png(absolute)


func _write_wav(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	wav.data = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	wav.save_to_wav(absolute)


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
