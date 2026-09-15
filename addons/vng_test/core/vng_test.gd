class_name VngTest
extends RefCounted

const BASE_SOURCE := "res://addons/vng_test/core/vng_test.gd"

var failures: Array[Dictionary] = []


func before_all() -> void:
	pass


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func after_all() -> void:
	pass


func fail(message: String) -> void:
	_record_failure(message)


func assert_eq(actual: Variant, expected: Variant, message := "") -> bool:
	if actual == expected:
		return true
	_record_failure(_msg(message, "assert_eq failed"), expected, actual, true)
	return false


func assert_ne(actual: Variant, not_expected: Variant, message := "") -> bool:
	if actual != not_expected:
		return true
	_record_failure(_msg(message, "assert_ne failed"), not_expected, actual, true)
	return false


func assert_true(value: Variant, message := "") -> bool:
	if value:
		return true
	_record_failure(_msg(message, "assert_true failed"), true, value, true)
	return false


func assert_false(value: Variant, message := "") -> bool:
	if not value:
		return true
	_record_failure(_msg(message, "assert_false failed"), false, value, true)
	return false


func assert_null(value: Variant, message := "") -> bool:
	if value == null:
		return true
	_record_failure(_msg(message, "assert_null failed"), null, value, true)
	return false


func assert_not_null(value: Variant, message := "") -> bool:
	if value != null:
		return true
	_record_failure(_msg(message, "assert_not_null failed"), "not null", value, true)
	return false


func assert_in(item: Variant, container: Variant, message := "") -> bool:
	var found := false
	if container is String:
		found = item is String and (container as String).contains(item as String)
	elif container is Array:
		found = (container as Array).has(item)
	elif container is PackedStringArray:
		found = (container as PackedStringArray).has(item)
	elif container is Dictionary:
		found = (container as Dictionary).has(item)
	else:
		_record_failure(_msg(message, "assert_in: container is not searchable"), "Array/Dictionary/String", container, true)
		return false
	if found:
		return true
	_record_failure(_msg(message, "assert_in failed"), "contains %s" % _stringify(item), container, true)
	return false


func assert_near(actual: Variant, expected: Variant, epsilon := 0.00001, message := "") -> bool:
	if not (actual is float or actual is int) or not (expected is float or expected is int):
		_record_failure(_msg(message, "assert_near: non-numeric operand"), expected, actual, true)
		return false
	if absf(float(actual) - float(expected)) <= epsilon:
		return true
	_record_failure(_msg(message, "assert_near failed (epsilon %s)" % _stringify(epsilon)), expected, actual, true)
	return false


func assert_signal(emitter: Object, signal_name: String, timeout_sec := 1.0, message := "") -> bool:
	if emitter == null or not emitter.has_signal(signal_name):
		_record_failure(_msg(message, "assert_signal: signal '%s' not found" % signal_name), signal_name, "<missing>", true)
		return false
	var fired := [false]
	var callback := func(_a = null, _b = null, _c = null, _d = null) -> void:
		fired[0] = true
	emitter.connect(signal_name, callback, CONNECT_ONE_SHOT)
	var tree: SceneTree = VngRun.tree
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not fired[0] and tree != null and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if emitter.is_connected(signal_name, callback):
		emitter.disconnect(signal_name, callback)
	if not fired[0]:
		_record_failure(
			_msg(message, "assert_signal: '%s' not emitted within %.1fs" % [signal_name, timeout_sec]),
			"emitted", "not emitted", true
		)
		return false
	return true


func _msg(message: String, fallback: String) -> String:
	return message if message != "" else fallback


func _record_failure(message: String, expected: Variant = null, actual: Variant = null, has_values := false) -> void:
	var entry := {
		"message": message,
		"location": _caller_location(),
	}
	if has_values:
		entry["expected"] = _stringify(expected)
		entry["actual"] = _stringify(actual)
	failures.append(entry)


func _caller_location() -> String:
	var stack := get_stack()
	for i in range(1, stack.size()):
		var frame: Dictionary = stack[i]
		var source: String = frame.get("source", "")
		if source != BASE_SOURCE:
			return "%s:%d" % [source, int(frame.get("line", 0))]
	return BASE_SOURCE


static func _stringify(value: Variant) -> String:
	if value == null:
		return "null"
	return var_to_str(value)
