class_name VngRealRng
extends VngRng

var _rng := RandomNumberGenerator.new()


func set_seed(value: int) -> void:
	_rng.seed = value


func next_int() -> int:
	return _rng.randi()


func next_float() -> float:
	return _rng.randf()


func next_int_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func next_float_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func save_state() -> int:
	return _rng.state


func restore_state(state: int) -> void:
	_rng.state = state
