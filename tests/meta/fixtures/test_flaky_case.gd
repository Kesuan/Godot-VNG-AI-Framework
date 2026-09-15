extends VngTest

const MARKER := "user://vng_test/flaky_marker.txt"


func test_flaky_once() -> void:
	if FileAccess.file_exists(MARKER):
		assert_true(true)
		return
	var file := FileAccess.open(MARKER, FileAccess.WRITE)
	file.store_string("seen")
	file.close()
	fail("first run fails on purpose")
