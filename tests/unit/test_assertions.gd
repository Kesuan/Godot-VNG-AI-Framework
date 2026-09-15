# @tag fast
extends VngTest


func test_assert_eq_pass() -> void:
	assert_true(assert_eq(2, 2))
	assert_eq(failures.size(), 0)


func test_assert_eq_failure_records_values_and_location() -> void:
	var ok := assert_eq(1, 2, "mismatch")
	assert_false(ok)
	assert_eq(failures.size(), 1)
	var failure: Dictionary = failures[0]
	assert_eq(failure.get("expected", ""), "2")
	assert_eq(failure.get("actual", ""), "1")
	assert_eq(failure.get("message", ""), "mismatch")
	assert_true((failure.get("location", "") as String).contains("test_assertions.gd"))
	failures.clear()


func test_assert_ne_pass_and_fail() -> void:
	assert_true(assert_ne(1, 2))
	assert_false(assert_ne(3, 3))
	assert_eq(failures.size(), 1)
	failures.clear()


func test_assert_true_false() -> void:
	assert_true(assert_true(1))
	assert_true(assert_false(0))
	assert_false(assert_true(null))
	assert_false(assert_false("x"))
	assert_eq(failures.size(), 2)
	failures.clear()


func test_assert_null_and_not_null() -> void:
	assert_true(assert_null(null))
	assert_true(assert_not_null(0))
	assert_false(assert_null(1))
	assert_false(assert_not_null(null))
	assert_eq(failures.size(), 2)
	failures.clear()


func test_assert_in() -> void:
	assert_true(assert_in(2, [1, 2, 3]))
	assert_true(assert_in("b", {"a": 1, "b": 2}))
	assert_true(assert_in("ell", "hello"))
	assert_false(assert_in(9, [1, 2, 3]))
	assert_eq(failures.size(), 1)
	failures.clear()


func test_assert_near() -> void:
	assert_true(assert_near(1.0000001, 1.0))
	assert_false(assert_near(1.1, 1.0, 0.01))
	assert_eq(failures.size(), 1)
	failures.clear()


func test_fail_records_message() -> void:
	fail("boom")
	assert_eq(failures.size(), 1)
	assert_eq(failures[0].get("message", ""), "boom")
	failures.clear()


func test_assert_signal_pass() -> void:
	var timer := VngRun.tree.create_timer(0.05)
	assert_true(await assert_signal(timer, "timeout", 1.0))


func test_assert_signal_missing_records_failure() -> void:
	var node := Node.new()
	var ok: bool = await assert_signal(node, "no_such_signal", 0.1)
	assert_false(ok)
	assert_eq(failures.size(), 1)
	failures.clear()
	node.free()
