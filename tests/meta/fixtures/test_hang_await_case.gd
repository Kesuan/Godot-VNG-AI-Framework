extends VngTest

signal never_happens


func test_after() -> void:
	assert_true(true)


func test_awaits_forever() -> void:
	await never_happens
