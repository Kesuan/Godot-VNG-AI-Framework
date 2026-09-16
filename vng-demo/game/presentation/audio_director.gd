extends Node

const AUDIO_DIRS := {
	"bgm": "res://assets/audio/bgm/",
	"sfx": "res://assets/audio/sfx/",
}
const EXTENSIONS := ["ogg", "wav"]

@onready var _bgm_player: AudioStreamPlayer = $Bgm
@onready var _sfx_player: AudioStreamPlayer = $Sfx

var current_bgm := ""


func play_bgm(asset: String) -> void:
	if asset == "stop" or asset.is_empty():
		current_bgm = ""
		_bgm_player.stop()
		return
	if asset == current_bgm and _bgm_player.playing:
		return
	current_bgm = asset
	var stream := _load_stream("bgm", asset)
	if stream == null:
		_bgm_player.stop()
		return
	_bgm_player.stream = stream
	_bgm_player.play()


func play_sfx(asset: String) -> void:
	var stream := _load_stream("sfx", asset)
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()


func stop_all() -> void:
	current_bgm = ""
	_bgm_player.stop()
	_sfx_player.stop()


func _load_stream(kind: String, asset: String) -> AudioStream:
	var dir: String = AUDIO_DIRS.get(kind, "")
	for extension in EXTENSIONS:
		var path := "%s%s.%s" % [dir, asset, extension]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null
