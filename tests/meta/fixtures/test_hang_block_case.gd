extends VngTest


func test_after_hang() -> void:
	assert_true(true)


func test_hangs() -> void:
	while true:
		pass
