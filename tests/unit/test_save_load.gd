# @tag fast
extends VngTest

const SampleChapter := preload("res://tests/fixtures/sample_chapter.gd")


func test_capture_apply_round_trip() -> void:
	var services := VngServices.for_tests(5)
	var runtime := VngStoryRuntime.new(services, SampleChapter.build())
	runtime.start("prologue")
	runtime.advance()
	var save := VngSave.capture(runtime, services)
	var snapshot_before := runtime.snapshot()
	runtime.advance()
	runtime.choose(1)
	assert_true(runtime.state.get_flag("route_yuki"))
	assert_true(runtime.ended == false)
	assert_true(VngSave.apply(runtime, services, save))
	assert_eq(runtime.snapshot(), snapshot_before)


func test_json_round_trip_restores_state() -> void:
	var services := VngServices.for_tests(5)
	var runtime := VngStoryRuntime.new(services, SampleChapter.build())
	runtime.start("prologue")
	runtime.advance()
	runtime.advance()
	var save := VngSave.capture(runtime, services)
	var snapshot_before := runtime.snapshot()
	var restored := VngSave.from_json(VngSave.to_json(save))
	assert_true(VngSave.apply(runtime, services, restored))
	assert_eq(runtime.snapshot(), snapshot_before)
	assert_eq(runtime.waiting, VngStoryRuntime.WAITING_CHOICE)


func test_rng_state_survives_save() -> void:
	var services := VngServices.for_tests(5)
	var runtime := VngStoryRuntime.new(services, SampleChapter.build())
	runtime.start("prologue")
	services.rng.next_int()
	var save := VngSave.capture(runtime, services)
	var expected := services.rng.next_int()
	services.rng.next_int()
	assert_true(VngSave.apply(runtime, services, save))
	assert_eq(services.rng.next_int(), expected)


func test_version_mismatch_is_rejected() -> void:
	var services := VngServices.for_tests(5)
	var runtime := VngStoryRuntime.new(services, SampleChapter.build())
	runtime.start("prologue")
	var save := VngSave.capture(runtime, services)
	save["version"] = 999
	assert_false(VngSave.apply(runtime, services, save))
	assert_eq(runtime.errors.size(), 1)


func test_chapter_mismatch_is_rejected() -> void:
	var services := VngServices.for_tests(5)
	var runtime := VngStoryRuntime.new(services, SampleChapter.build())
	runtime.start("prologue")
	var save := VngSave.capture(runtime, services)
	save["chapter"] = "chapter99"
	assert_false(VngSave.apply(runtime, services, save))


func test_save_store_round_trip() -> void:
	var store := VngSaveStore.new("user://vng_test/saves")
	if store.exists("slot1"):
		store.erase("slot1")
	assert_eq(store.write("slot1", {"node": "prologue", "step": 2}), OK)
	assert_true(store.exists("slot1"))
	assert_eq(store.read("slot1").get("step", -1), 2)
	assert_in("slot1", store.list_slots())
	store.erase("slot1")
	assert_false(store.exists("slot1"))


func test_save_store_rejects_bad_slot_names() -> void:
	var store := VngSaveStore.new("user://vng_test/saves")
	assert_eq(store.write("../evil", {}), ERR_INVALID_PARAMETER)
	assert_eq(store.read("bad/slot"), {})
	assert_false(store.exists(""))
