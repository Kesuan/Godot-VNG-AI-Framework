# @tag fast
extends VngTest

const SampleChapter := preload("res://tests/fixtures/sample_chapter.gd")


func test_same_seed_same_event_trace_and_snapshot() -> void:
	var first := _play(41)
	var second := _play(41)
	assert_eq(first.events, second.events)
	assert_eq(first.snapshot, second.snapshot)
	assert_true((first.events as Array).size() > 0)


func test_different_seed_only_changes_rng() -> void:
	var first := _play(1)
	var second := _play(2)
	assert_eq(first.events, second.events)
	assert_eq(first.snapshot, second.snapshot)


func test_fake_rng_makes_choices_reproducible() -> void:
	var services := VngServices.for_tests(0)
	var fake := VngFakeRng.new()
	fake.expect_int(0)
	services.rng = fake
	var runtime := VngStoryRuntime.new(services, SampleChapter.build())
	runtime.start("prologue")
	assert_eq(services.rng.pick(["a", "b", "c"]), "a")
	assert_eq(fake.pending(), 0)


func _play(seed_value: int) -> Dictionary:
	var services := VngServices.for_tests(seed_value)
	var runtime := VngStoryRuntime.new(services, SampleChapter.build())
	runtime.start("prologue")
	runtime.advance()
	runtime.advance()
	runtime.choose(2)
	runtime.advance()
	return {
		"events": services.events.history(),
		"snapshot": runtime.snapshot(),
	}
