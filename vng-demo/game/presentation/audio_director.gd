extends Node

const AssetLibraryScript := preload("res://game/presentation/asset_library.gd")

@onready var _bgm_player: AudioStreamPlayer = $Bgm
@onready var _sfx_player: AudioStreamPlayer = $Sfx

var assets: AssetLibraryScript = null

var current_bgm := ""


func play_bgm(asset: String) -> void:
	if asset == "stop" or asset.is_empty():
		current_bgm = ""
		_bgm_player.stop()
		return
	if asset == current_bgm and _bgm_player.playing:
		return
	current_bgm = asset
	var stream: AudioStream = assets.bgm(asset) if assets != null else null
	if stream == null:
		_bgm_player.stop()
		return
	_bgm_player.stream = stream
	_bgm_player.play()


func play_sfx(asset: String) -> void:
	var stream: AudioStream = assets.sfx(asset) if assets != null else null
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()


func stop_all() -> void:
	current_bgm = ""
	_bgm_player.stop()
	_sfx_player.stop()
