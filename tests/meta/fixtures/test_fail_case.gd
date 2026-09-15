extends VngTest


func test_ok() -> void:
	assert_eq("a", "a")


func test_fails() -> void:
	assert_eq(43, 42, "numbers differ")
