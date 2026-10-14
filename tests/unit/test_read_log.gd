# @tag fast
extends VngTest

const ROOT := "user://vng_test/read_probe"


func before_each() -> void:
	_clear_root()


func after_each() -> void:
	_clear_root()


func test_mark_and_persist_across_instances() -> void:
	var log := VngReadLog.new(ROOT)
	log.bind("hash_a")
	var key := VngReadLog.line_key("", "第一行。")
	assert_false(log.is_read(key))
	log.mark_read(key)
	assert_true(log.is_read(key))
	assert_eq(log.count(), 1)

	var reloaded := VngReadLog.new(ROOT)
	reloaded.bind("hash_a")
	assert_true(reloaded.is_read(key))


func test_story_hashes_are_isolated() -> void:
	var log := VngReadLog.new(ROOT)
	log.bind("hash_a")
	var key := VngReadLog.line_key("rin", "你好。")
	log.mark_read(key)

	var other := VngReadLog.new(ROOT)
	other.bind("hash_b")
	assert_false(other.is_read(key))
	other.mark_read(key)
	assert_true(other.is_read(key))

	var again_a := VngReadLog.new(ROOT)
	again_a.bind("hash_a")
	assert_true(again_a.is_read(key))
	assert_eq(again_a.count(), 1)


func test_cap_drops_oldest_records() -> void:
	var log := VngReadLog.new(ROOT, 3)
	log.bind("hash_cap")
	var keys: Array = []
	for i in 4:
		var key := "key_%d" % i
		keys.append(key)
		log.mark_read(key)
	assert_false(log.is_read(str(keys[0])), "超出容量应丢弃最旧记录")
	assert_true(log.is_read(str(keys[3])))
	assert_eq(log.count(), 3)

	var reloaded := VngReadLog.new(ROOT, 3)
	reloaded.bind("hash_cap")
	assert_false(reloaded.is_read(str(keys[0])))
	assert_true(reloaded.is_read(str(keys[3])))


func test_clear_removes_records() -> void:
	var log := VngReadLog.new(ROOT)
	log.bind("hash_clear")
	var key := VngReadLog.line_key("", "会被清掉。")
	log.mark_read(key)
	log.clear()
	assert_false(log.is_read(key))
	assert_eq(log.count(), 0)
	var reloaded := VngReadLog.new(ROOT)
	reloaded.bind("hash_clear")
	assert_false(reloaded.is_read(key))


func test_line_key_normalizes_edges_but_not_identity() -> void:
	assert_eq(VngReadLog.line_key("a", " x "), VngReadLog.line_key("a", "x"))
	assert_ne(VngReadLog.line_key("a", "x"), VngReadLog.line_key("b", "x"))
	assert_ne(VngReadLog.line_key("a", "x"), VngReadLog.line_key("a", "y"))


func _clear_root() -> void:
	var absolute := ProjectSettings.globalize_path(ROOT)
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
