# @tag fast
extends VngTest


func _state() -> VngStoryState:
	var state := VngStoryState.new()
	state.set_flag("met_yuki", true)
	state.set_flag("route_yuki", false)
	state.set_var("trust", 2)
	return state


func test_flags_and_literals() -> void:
	assert_true(VngCondition.evaluate_text("met_yuki", _state()).value)
	assert_false(VngCondition.evaluate_text("route_yuki", _state()).value)
	assert_true(VngCondition.evaluate_text("true", _state()).value)
	assert_false(VngCondition.evaluate_text("false", _state()).value)


func test_not_operators() -> void:
	assert_true(VngCondition.evaluate_text("not route_yuki", _state()).value)
	assert_true(VngCondition.evaluate_text("!route_yuki", _state()).value)
	assert_false(VngCondition.evaluate_text("not met_yuki", _state()).value)


func test_logical_operators() -> void:
	assert_true(VngCondition.evaluate_text("met_yuki && trust >= 2", _state()).value)
	assert_false(VngCondition.evaluate_text("met_yuki && trust > 2", _state()).value)
	assert_true(VngCondition.evaluate_text("route_yuki || trust == 2", _state()).value)
	assert_false(VngCondition.evaluate_text("route_yuki || trust == 9", _state()).value)


func test_precedence_and_parentheses() -> void:
	assert_true(VngCondition.evaluate_text("route_yuki || met_yuki && true", _state()).value)
	assert_true(VngCondition.evaluate_text("(route_yuki || met_yuki) && trust == 2", _state()).value)
	assert_false(VngCondition.evaluate_text("not (route_yuki || met_yuki)", _state()).value)


func test_comparisons() -> void:
	assert_true(VngCondition.evaluate_text("trust != 3", _state()).value)
	assert_true(VngCondition.evaluate_text("trust <= 2", _state()).value)
	assert_false(VngCondition.evaluate_text("trust < 2", _state()).value)
	assert_true(VngCondition.evaluate_text("met_yuki == true", _state()).value)


func test_negative_number() -> void:
	var state := VngStoryState.new()
	state.set_var("trust", -1)
	assert_true(VngCondition.evaluate_text("trust < 0", state).value)
	assert_true(VngCondition.evaluate_text("trust == -1", state).value)


func test_undefined_identifier_defaults_to_falsy() -> void:
	var undefined_names: Array = []
	var result := VngCondition.evaluate_text("unknown_flag", _state(), undefined_names)
	assert_true(result.ok)
	assert_null(result.value)
	assert_true(undefined_names.has("unknown_flag"))
	assert_false(result.value == true)


func test_undefined_in_not_is_false() -> void:
	var result := VngCondition.evaluate_text("not unknown_flag", _state())
	assert_true(result.ok)
	assert_true(result.value == true)


func test_undefined_var_in_comparison_is_zero() -> void:
	assert_false(VngCondition.evaluate_text("unknown_var >= 1", _state()).value == true)
	assert_true(VngCondition.evaluate_text("unknown_var <= 0", _state()).value == true)
	assert_true(VngCondition.evaluate_text("unknown_var == 0", _state()).value == true)
	assert_false(VngCondition.evaluate_text("unknown_flag == true", _state()).value == true)


func test_parse_error() -> void:
	var result := VngCondition.evaluate_text("met_yuki &&", _state())
	assert_false(result.ok)
	assert_ne(result.error, "")


func test_type_mismatch_is_error() -> void:
	var result := VngCondition.evaluate_text("trust == true", _state())
	assert_false(result.ok)


func test_short_circuit_avoids_undefined_right_side() -> void:
	assert_false(VngCondition.evaluate_text("route_yuki && unknown_flag", _state()).value)
	assert_true(VngCondition.evaluate_text("met_yuki || unknown_flag", _state()).value)
