class_name VngInputHub
extends RefCounted

var _queue: Array[Dictionary] = []


func push(command: Dictionary) -> void:
	_queue.append(command)


func pop() -> Dictionary:
	if _queue.is_empty():
		return {}
	return _queue.pop_front()


func has_pending() -> bool:
	return not _queue.is_empty()


func pending_count() -> int:
	return _queue.size()


func clear() -> void:
	_queue.clear()
