# @tag fast
extends VngTest


class CountingListener:
	extends Node

	var count := 0

	func on_event(_entry: Dictionary) -> void:
		count += 1


func test_emit_notifies_and_records_history() -> void:
	var bus := VngEventBus.new()
	var listener := CountingListener.new()
	bus.subscribe("ping", listener.on_event)
	bus.emit_event("ping", {"n": 1})
	bus.emit_event("ping")
	assert_eq(listener.count, 2)
	assert_eq(bus.size(), 2)
	assert_eq(bus.event_types(), PackedStringArray(["ping", "ping"]))
	var entry: Dictionary = bus.history()[0]
	assert_eq(entry.get("data", {}).get("n", 0), 1)
	assert_eq(int(entry.get("seq", 0)), 1)
	listener.free()


func test_wildcard_listener_receives_all_events() -> void:
	var bus := VngEventBus.new()
	var seen: Array = []
	bus.subscribe("*", func(entry): seen.append(entry.get("type", "")))
	bus.emit_event("a")
	bus.emit_event("b")
	assert_eq(seen, ["a", "b"])
	assert_eq(bus.listener_count(), 1)


func test_unsubscribe_stops_delivery() -> void:
	var bus := VngEventBus.new()
	var listener := CountingListener.new()
	bus.subscribe("ping", listener.on_event)
	bus.emit_event("ping")
	bus.unsubscribe("ping", listener.on_event)
	bus.emit_event("ping")
	assert_eq(listener.count, 1)
	assert_eq(bus.listener_count("ping"), 0)
	listener.free()


func test_freed_listener_is_pruned_without_error() -> void:
	var bus := VngEventBus.new()
	var listener := CountingListener.new()
	bus.subscribe("ping", listener.on_event)
	bus.emit_event("ping")
	assert_eq(listener.count, 1)
	listener.free()
	bus.emit_event("ping")
	assert_eq(bus.listener_count("ping"), 0)


func test_recording_disabled_skips_history() -> void:
	var bus := VngEventBus.new()
	bus.recording = false
	bus.emit_event("ping")
	assert_eq(bus.size(), 0)


func test_clock_timestamp_is_recorded() -> void:
	var clock := VngFakeClock.new()
	clock.advance(2.5)
	var bus := VngEventBus.new()
	bus.clock = clock
	var entry := bus.emit_event("tick")
	assert_eq(float(entry.get("t", 0.0)), 2.5)
