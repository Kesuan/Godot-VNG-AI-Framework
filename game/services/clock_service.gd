class_name VngClock
extends RefCounted

var _now := 0.0


func now() -> float:
	return _now


func tick(delta: float) -> void:
	_now += delta


func set_now(value: float) -> void:
	_now = value
