class_name VngStoryState
extends RefCounted

var flags: Dictionary = {}
var vars: Dictionary = {}


func has_flag(name: String) -> bool:
	return flags.has(name)


func get_flag(name: String, default_value := false) -> bool:
	if flags.has(name):
		return bool(flags[name])
	return default_value


func set_flag(name: String, value: bool) -> void:
	flags[name] = value


func has_var(name: String) -> bool:
	return vars.has(name)


func get_var(name: String, default_value := 0) -> int:
	if vars.has(name):
		return int(vars[name])
	return default_value


func set_var(name: String, value: int) -> void:
	vars[name] = value


func snapshot() -> Dictionary:
	return {"flags": flags.duplicate(true), "vars": vars.duplicate(true)}


func restore(data: Dictionary) -> void:
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	vars = (data.get("vars", {}) as Dictionary).duplicate(true)


func clear() -> void:
	flags.clear()
	vars.clear()
