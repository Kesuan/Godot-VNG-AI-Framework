class_name VngPlaythrough
extends RefCounted

const TraceGolden := preload("res://addons/vng_test/dsl/trace_golden.gd")

var services: VngServices
var runtime: VngStoryRuntime
var chapter: Dictionary

var _test: Object
var _reported_errors := 0


func _init(p_chapter: Dictionary, p_test: Object, seed_value := 0) -> void:
	chapter = p_chapter
	_test = p_test
	services = VngServices.for_tests(seed_value)
	runtime = VngStoryRuntime.new(services, chapter)


func start_scene(node: String) -> VngPlaythrough:
	runtime.start(node)
	return _check_runtime()


func advance() -> VngPlaythrough:
	runtime.advance()
	return _check_runtime()


func choose(index: int) -> VngPlaythrough:
	runtime.choose(index)
	return _check_runtime()


func choose_text(text: String) -> VngPlaythrough:
	var index := -1
	for option in runtime.visible_choices():
		if option.get("text", "") == text:
			index = int(option.get("index", -1))
			break
	if index == -1:
		_test.fail("选项文本不存在: '%s'（当前选项: %s）" % [text, str(_choice_texts())])
		return self
	return choose(index)


func skip_to(node: String) -> VngPlaythrough:
	runtime.skip_to(node)
	return _check_runtime()


func trace() -> Array:
	return TraceGolden.reduce(services.events.history())


func expect_line(text: String, message := "") -> VngPlaythrough:
	_test.assert_eq(runtime.current_line.get("text", ""), text, _m(message, "当前台词（%s）" % _context()))
	return self


func expect_speaker(who: String, message := "") -> VngPlaythrough:
	_test.assert_eq(runtime.current_line.get("who", ""), who, _m(message, "当前说话者（%s）" % _context()))
	return self


func expect_choices(texts: Array, message := "") -> VngPlaythrough:
	_test.assert_eq(_choice_texts(), texts, _m(message, "当前选项（%s）" % _context()))
	return self


func expect_flag(name: String, expected := true, message := "") -> VngPlaythrough:
	if expected and not runtime.state.has_flag(name):
		_test.fail(_m(message, "flag '%s' 未设置（%s）" % [name, _context()]))
		return self
	_test.assert_eq(runtime.state.get_flag(name), expected, _m(message, "flag '%s'（%s）" % [name, _context()]))
	return self


func expect_var(name: String, expected: int, message := "") -> VngPlaythrough:
	if not runtime.state.has_var(name):
		_test.fail(_m(message, "var '%s' 未设置（%s）" % [name, _context()]))
		return self
	_test.assert_eq(runtime.state.get_var(name), expected, _m(message, "var '%s'（%s）" % [name, _context()]))
	return self


func expect_scene(node: String, message := "") -> VngPlaythrough:
	_test.assert_eq(runtime.node_id, node, _m(message, "当前节点（%s）" % _context()))
	return self


func expect_waiting(kind: String, message := "") -> VngPlaythrough:
	_test.assert_eq(runtime.waiting, kind, _m(message, "等待状态（%s）" % _context()))
	return self


func expect_ended(message := "") -> VngPlaythrough:
	_test.assert_true(runtime.ended, _m(message, "剧本应已结束（%s）" % _context()))
	return self


func expect_no_errors(message := "") -> VngPlaythrough:
	if runtime.errors.is_empty():
		return self
	var first: Dictionary = runtime.errors[0]
	_test.fail(_m(message, "存在 %d 个运行时错误，首个: %s" % [runtime.errors.size(), first.get("message", "")]))
	return self


func expect_trace(name: String, message := "") -> VngPlaythrough:
	var path: String = VngRun.trace_dir.path_join(name + ".trace.json")
	var actual := trace()
	if VngRun.update_traces:
		var write_error := TraceGolden.save_golden(path, name, actual)
		if write_error != OK:
			_test.fail(_m(message, "trace golden 写入失败: %s (%s)" % [path, error_string(write_error)]))
		else:
			print("TRACE UPDATED %s（%d events）" % [path, actual.size()])
		return self
	var golden := TraceGolden.load_golden(path)
	if golden.is_empty():
		_test.fail(_m(message, "trace golden 不存在: %s（如需录制请显式运行 tools/test --update-traces）" % path))
		return self
	var result := TraceGolden.compare(golden.get("events", []), actual)
	if not result.equal:
		_test.fail(_m(message, "trace 与 golden 不一致: %s\n%s" % [path, TraceGolden.format_diff(result.differences)]))
	return self


func _choice_texts() -> Array:
	var texts: Array = []
	for option in runtime.visible_choices():
		texts.append(option.get("text", ""))
	return texts


func _context() -> String:
	return "%s:%d" % [runtime.node_id, runtime.step_index]


func _m(message: String, fallback: String) -> String:
	return message if message != "" else fallback


func _check_runtime() -> VngPlaythrough:
	if runtime.errors.size() > _reported_errors:
		for i in range(_reported_errors, runtime.errors.size()):
			var runtime_error: Dictionary = runtime.errors[i]
			_test.fail("运行时错误: %s（节点 %s 步骤 %d）" % [
				runtime_error.get("message", ""),
				runtime_error.get("node", ""),
				int(runtime_error.get("step", -1)),
			])
		_reported_errors = runtime.errors.size()
	return self
