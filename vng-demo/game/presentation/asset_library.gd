extends RefCounted

const VnsAssetPaths := preload("res://addons/vns/vns_asset_paths.gd")

const DEFAULT_ROOT := "res://assets"

var asset_root: String

var _textures := {}
var _streams := {}
var _missing: Array[String] = []


func _init(p_root: String = DEFAULT_ROOT) -> void:
	asset_root = p_root.rstrip("/")


func background(asset_id: String) -> Texture2D:
	return _texture(VnsAssetPaths.bg_candidates(asset_id, asset_root), "bg/%s" % asset_id)


func character(char_id: String, expr: String) -> Texture2D:
	return _texture(VnsAssetPaths.char_candidates(char_id, expr, asset_root), "char/%s/%s" % [char_id, expr])


func bgm(asset_id: String) -> AudioStream:
	return _stream(VnsAssetPaths.bgm_candidates(asset_id, asset_root), "bgm/%s" % asset_id)


func sfx(asset_id: String) -> AudioStream:
	return _stream(VnsAssetPaths.sfx_candidates(asset_id, asset_root), "sfx/%s" % asset_id)


func missing_report() -> PackedStringArray:
	return PackedStringArray(_missing)


func clear_cache() -> void:
	_textures.clear()
	_streams.clear()
	_missing.clear()


func _texture(candidates: PackedStringArray, label: String) -> Texture2D:
	if _textures.has(label):
		return _textures[label]
	for candidate in candidates:
		var texture := _load_texture(candidate)
		if texture != null:
			_textures[label] = texture
			return texture
	_textures[label] = null
	_note_missing(label)
	return null


func _stream(candidates: PackedStringArray, label: String) -> AudioStream:
	if _streams.has(label):
		return _streams[label]
	for candidate in candidates:
		var stream := _load_audio(candidate)
		if stream != null:
			_streams[label] = stream
			return stream
	_streams[label] = null
	_note_missing(label)
	return null


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource: Variant = load(path)
		if resource is Texture2D:
			return resource
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _load_audio(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var resource: Variant = load(path)
		if resource is AudioStream:
			return resource
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
	return null


func _note_missing(label: String) -> void:
	if not _missing.has(label):
		_missing.append(label)
