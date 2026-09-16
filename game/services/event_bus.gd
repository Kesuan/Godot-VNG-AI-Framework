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
	_dispatch(type, entry)
	_dispatch("*", entry)
	return entry


func _dispatch(type: String, entry: Dictionary) -> void:
	var listeners: Array = _listeners.get(type, [])
	if listeners.is_empty():
		return
	var alive: Array = []
	for listener in listeners:
		var callable: Callable = listener
		if callable.is_valid():
			alive.append(callable)
	_listeners[type] = alive
	for callable in alive:
		callable.call(entry)


func listener_count(type: String = "*", include_dead := false) -> int:
	var listeners: Array = _listeners.get(type, [])
	if include_dead:
		return listeners.size()
	var count := 0
	for listener in listeners:
		if (listener as Callable).is_valid():
			count += 1
	return count


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
