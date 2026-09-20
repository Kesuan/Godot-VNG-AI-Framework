extends RefCounted

const IMAGE_EXTENSIONS := ["png", "webp", "jpg"]
const AUDIO_EXTENSIONS := ["ogg", "wav"]

const BG_DIR := "bg"
const CHAR_DIR := "char"
const BGM_DIR := "audio/bgm"
const SFX_DIR := "audio/sfx"

const KIND_ORDER := ["bg", "char", "bgm", "sfx"]
const DEFAULT_ROOT := "res://assets"


static func bg_candidates(asset_id: String, asset_root := DEFAULT_ROOT) -> PackedStringArray:
	return _file_candidates(_root(asset_root).path_join(BG_DIR), asset_id, IMAGE_EXTENSIONS)


static func char_candidates(char_id: String, expr: String, asset_root := DEFAULT_ROOT) -> PackedStringArray:
	var dir := _root(asset_root).path_join(CHAR_DIR).path_join(char_id)
	var candidates := PackedStringArray()
	candidates.append_array(_file_candidates(dir, expr, IMAGE_EXTENSIONS))
	if expr != "" and expr != "default":
		candidates.append_array(_file_candidates(dir, "default", IMAGE_EXTENSIONS))
	return candidates


static func bgm_candidates(asset_id: String, asset_root := DEFAULT_ROOT) -> PackedStringArray:
	return _file_candidates(_root(asset_root).path_join(BGM_DIR), asset_id, AUDIO_EXTENSIONS)


static func sfx_candidates(asset_id: String, asset_root := DEFAULT_ROOT) -> PackedStringArray:
	return _file_candidates(_root(asset_root).path_join(SFX_DIR), asset_id, AUDIO_EXTENSIONS)


static func candidates_for(kind: String, asset_id: String, expr: String, asset_root := DEFAULT_ROOT) -> PackedStringArray:
	match kind:
		"bg":
			return bg_candidates(asset_id, asset_root)
		"char":
			return char_candidates(asset_id, expr, asset_root)
		"bgm":
			return bgm_candidates(asset_id, asset_root)
		"sfx":
			return sfx_candidates(asset_id, asset_root)
	return PackedStringArray()


static func first_existing(candidates: PackedStringArray) -> String:
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


static func _root(asset_root: String) -> String:
	var root: String = asset_root if asset_root != "" else DEFAULT_ROOT
	return root.rstrip("/")


static func _file_candidates(dir: String, id: String, extensions: Array) -> PackedStringArray:
	var candidates := PackedStringArray()
	if id.is_empty():
		return candidates
	for extension in extensions:
		candidates.append("%s.%s" % [dir.path_join(id), extension])
	return candidates
