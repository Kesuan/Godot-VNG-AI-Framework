class_name VngFakeRng
extends VngRng

var _ints: Array[int] = []
var _floats: Array[float] = []


func expect_int(value: int) -> VngFakeRng:
	_ints.append(value)
	return self


func expect_float(value: float) -> VngFakeRng:
	_floats.append(value)
	return self


func pending() -> int:
	return _ints.size() + _floats.size()


func next_int() -> int:
	if _ints.is_empty():
		push_error("VngFakeRng: no scripted int left")
		return 0
	return _ints.pop_front()


func next_float() -> float:
	if not _floats.is_empty():
		return _floats.pop_front()
	if not _ints.is_empty():
		return float(_ints.pop_front())
	push_error("VngFakeRng: no scripted float left")
	return 0.0


func next_int_range(from: int, to: int) -> int:
	return clampi(next_int(), from, to)


func next_float_range(from: float, to: float) -> float:
	return clampf(next_float(), from, to)
