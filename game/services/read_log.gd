class_name VngReadLog
extends RefCounted

## 已读台词记录（跳过已读用）：按 story_hash 隔离，JSON 持久化。
## 行 ID 采用内容哈希（who|text），文本改动即视为未读；容量超限丢弃最旧记录。

const DEFAULT_ROOT := "user://read"
const DEFAULT_CAP := 5000

var root: String
var cap: int

var _story_hash := ""
var _order: Array = []
var _known := {}


func _init(p_root: String = DEFAULT_ROOT, p_cap: int = DEFAULT_CAP) -> void:
	root = p_root.rstrip("/")
	cap = maxi(1, p_cap)


func bind(story_hash: String) -> void:
	if story_hash == _story_hash:
		return
	_story_hash = story_hash
	_order = []
	_known = {}
	_load()


func is_read(line_id: String) -> bool:
	return _known.has(line_id)


func mark_read(line_id: String) -> void:
	if line_id.is_empty() or _known.has(line_id):
		return
	_known[line_id] = true
	_order.append(line_id)
	if _order.size() > cap:
		var dropped: String = _order.pop_front()
		_known.erase(dropped)
	_save()


func clear() -> void:
	_order = []
	_known = {}
	if _story_hash != "":
		_erase()


func count() -> int:
	return _order.size()


static func line_key(who: String, text: String) -> String:
	return ("%s\n%s" % [who, text.strip_edges()]).sha256_text()


func _file_path() -> String:
	return root.path_join(_story_hash + ".json")


func _load() -> void:
	if _story_hash.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(_file_path())
	if not FileAccess.file_exists(absolute):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(absolute)) != OK:
		return
	if not (json.data is Dictionary):
		return
	var lines: Variant = (json.data as Dictionary).get("lines", [])
	if not (lines is Array):
		return
	for line_id in lines:
		var id := str(line_id)
		if id.is_empty() or _known.has(id):
			continue
		_known[id] = true
		_order.append(id)
	while _order.size() > cap:
		var dropped: String = _order.pop_front()
		_known.erase(dropped)


func _save() -> void:
	if _story_hash.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(_file_path())
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"schema": 1, "lines": _order}, "\t", true) + "\n")
	file.close()


func _erase() -> void:
	var absolute := ProjectSettings.globalize_path(_file_path())
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
