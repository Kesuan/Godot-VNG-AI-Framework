# @tag fast
extends VngTest


func test_parse_all_flags() -> void:
	var config := VngBootConfig.parse(PackedStringArray([
		"--test-mode", "--seed=1234", "--save-root=user://test/run1",
	]))
	assert_true(config.test_mode)
	assert_eq(config.seed, 1234)
	assert_eq(config.save_root, "user://test/run1")
	assert_eq(config.errors.size(), 0)


func test_parse_space_separated_values() -> void:
	var config := VngBootConfig.parse(PackedStringArray(["--seed", "5", "--save-root", "user://x"]))
	assert_eq(config.seed, 5)
	assert_eq(config.save_root, "user://x")
	assert_false(config.test_mode)


func test_unknown_args_are_ignored() -> void:
	var config := VngBootConfig.parse(PackedStringArray(["--fullscreen", "--seed=2"]))
	assert_eq(config.seed, 2)
	assert_eq(config.errors.size(), 0)


func test_invalid_seed_records_error() -> void:
	var config := VngBootConfig.parse(PackedStringArray(["--seed=abc"]))
	assert_eq(config.errors.size(), 1)


func test_missing_value_records_error() -> void:
	var config := VngBootConfig.parse(PackedStringArray(["--seed"]))
	assert_eq(config.errors.size(), 1)


func test_defaults() -> void:
	var config := VngBootConfig.parse(PackedStringArray([]))
	assert_false(config.test_mode)
	assert_eq(config.seed, 0)
	assert_eq(config.save_root, "user://saves")
