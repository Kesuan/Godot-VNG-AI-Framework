class_name VngServices
extends RefCounted

var rng: VngRng
var clock: VngClock
var input: VngInputHub
var events: VngEventBus
var save_root: String = "user://saves"
var settings: VngSettings
var read_log: VngReadLog


func _init(seed_value: int = 0) -> void:
	rng = VngRealRng.new()
	rng.set_seed(seed_value)
	clock = VngClock.new()
	input = VngInputHub.new()
	events = VngEventBus.new()
	events.clock = clock
	settings = VngSettings.new()
	read_log = VngReadLog.new()


static func for_tests(seed_value: int = 0) -> VngServices:
	var services := VngServices.new(seed_value)
	var fake_clock := VngFakeClock.new()
	services.clock = fake_clock
	services.events.clock = fake_clock
	services.save_root = "user://vng_test/saves"
	services.settings = VngSettings.new("user://vng_test/settings.json", false)
	services.read_log = VngReadLog.new("user://vng_test/read")
	return services
