class_name VngEventBus
extends RefCounted

var clock: VngClock = null
var recording := true

var _history: Array[Dictionary] = []
var _listeners := {}
var _seq := 0


func emit_event(type: String, data: Dictionary = {}) -> Dictionary:
	_seq += 1
	var entry := {
		"seq": _seq,
		"type": type,
		"data": data.duplicate(true),
	}
	if clock != null:
		entry["t"] = clock.now()
	if recording:
		_history.append(entry)
	for listener in _listeners.get(type, []):
		(listener as Callable).call(entry)
	for listener in _listeners.get("*", []):
		(listener as Callable).call(entry)
	return entry


func subscribe(type: String, listener: Callable) -> void:
	var list: Array = _listeners.get(type, [])
	list.append(listener)
	_listeners[type] = list


func unsubscribe(type: String, listener: Callable) -> void:
	var list: Array = _listeners.get(type, [])
	list.erase(listener)
	_listeners[type] = list


func history() -> Array:
	return _history.duplicate(true)


func event_types() -> PackedStringArray:
	var types := PackedStringArray()
	for entry in _history:
		types.append(entry.get("type", ""))
	return types


func size() -> int:
	return _history.size()


func clear() -> void:
	_history.clear()
