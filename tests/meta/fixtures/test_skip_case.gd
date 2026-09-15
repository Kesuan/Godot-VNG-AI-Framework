extends VngTest


func test_runs() -> void:
	assert_true(true)


# @skip not implemented yet
func test_skipped() -> void:
	fail("skipped test must not run")
