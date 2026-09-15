class_name VngRng
extends RefCounted


func set_seed(value: int) -> void:
	pass


func next_int() -> int:
	return 0


func next_float() -> float:
	return 0.0


func next_int_range(from: int, to: int) -> int:
	return from


func next_float_range(from: float, to: float) -> float:
	return from


func pick(values: Array) -> Variant:
	if values.is_empty():
		return null
	return values[next_int() % values.size()]


func shuffle(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := next_int_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp


func save_state() -> int:
	return 0


func restore_state(state: int) -> void:
	pass
