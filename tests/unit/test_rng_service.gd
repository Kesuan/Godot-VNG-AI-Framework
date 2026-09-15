# @tag fast
extends VngTest


func test_same_seed_same_sequence() -> void:
	var a := VngRealRng.new()
	a.set_seed(1234)
	var b := VngRealRng.new()
	b.set_seed(1234)
	for i in 20:
		assert_eq(a.next_int(), b.next_int())


func test_different_seed_differs() -> void:
	var a := VngRealRng.new()
	a.set_seed(1)
	var b := VngRealRng.new()
	b.set_seed(2)
	var same := true
	for i in 10:
		if a.next_int() != b.next_int():
			same = false
	assert_false(same)


func test_state_round_trip() -> void:
	var rng := VngRealRng.new()
	rng.set_seed(7)
	rng.next_int()
	rng.next_int()
	var saved := rng.save_state()
	var expected := rng.next_int()
	rng.restore_state(saved)
	assert_eq(rng.next_int(), expected)


func test_fake_scripted_values() -> void:
	var fake := VngFakeRng.new()
	fake.expect_int(3).expect_int(1)
	assert_eq(fake.next_int(), 3)
	assert_eq(fake.next_int(), 1)
	assert_eq(fake.pending(), 0)


func test_pick_uses_overridden_source() -> void:
	var fake := VngFakeRng.new()
	fake.expect_int(1)
	assert_eq(fake.pick(["a", "b", "c"]), "b")
	assert_eq(fake.pending(), 0)


func test_pick_and_ranges() -> void:
	var rng := VngRealRng.new()
	rng.set_seed(99)
	assert_in(rng.pick(["a", "b", "c"]), ["a", "b", "c"])
	assert_eq(rng.next_int_range(5, 5), 5)
	assert_true(rng.next_float() >= 0.0 and rng.next_float() < 1.0)


func test_shuffle_is_deterministic_with_seed() -> void:
	var a := ["a", "b", "c", "d", "e"]
	var b := ["a", "b", "c", "d", "e"]
	var rng_a := VngRealRng.new()
	rng_a.set_seed(42)
	rng_a.shuffle(a)
	var rng_b := VngRealRng.new()
	rng_b.set_seed(42)
	rng_b.shuffle(b)
	assert_eq(a, b)
	assert_ne(a, ["a", "b", "c", "d", "e"])
