extends VngTest


func test_runtime_error() -> void:
	var value = null
	value.missing_method()


func test_ok_after() -> void:
	assert_true(true)
