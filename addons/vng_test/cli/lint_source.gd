extends SceneTree

const Scanner := preload("res://addons/vng_test/lint/source_scanner.gd")

const USAGE := """非确定性 API 扫描器

用法: tools/lint [--root <res://目录>]... [--allow <路径子串>]...

选项:
  --root <dir>    扫描目录（默认 res://game，可重复）
  --allow <text>  豁免路径（路径包含该子串时跳过，可重复）

退出码: 0 无违规 / 1 发现违规 / 2 参数错误
"""


func _init() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var roots: Array = []
	var allows: Array = []
	var i := 0
	while i < args.size():
		var arg: String = args[i]
		if arg == "--help" or arg == "-h":
			print(USAGE)
			quit(0)
			return
		if arg == "--root" or arg == "--allow":
			if i + 1 >= args.size():
				printerr("参数缺少值: %s" % arg)
				quit(2)
				return
			if arg == "--root":
				roots.append(args[i + 1].rstrip("/"))
			else:
				allows.append(args[i + 1])
			i += 2
			continue
		printerr("未知参数: %s" % arg)
		printerr(USAGE)
		quit(2)
		return

	if roots.is_empty():
		roots.append("res://game")
	var violations: Array = []
	for root in roots:
		_scan_dir(root, allows, violations)
	for violation in violations:
		print("%s:%d:%d: error: %s [%s]" % [
			violation.file, violation.line, violation.column, violation.message, violation.symbol
		])
	if violations.is_empty():
		print("非确定性 API 扫描通过（%s）" % ", ".join(PackedStringArray(roots)))
		quit(0)
		return
	printerr("发现 %d 处违规" % violations.size())
	quit(1)


func _scan_dir(dir_path: String, allows: Array, violations: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(full, allows, violations)
		elif entry.ends_with(".gd") and not _is_allowed(full, allows):
			violations.append_array(Scanner.scan_file(full))
		entry = dir.get_next()
	dir.list_dir_end()


func _is_allowed(path: String, allows: Array) -> bool:
	for allow in allows:
		if path.contains(allow):
			return true
	return false
