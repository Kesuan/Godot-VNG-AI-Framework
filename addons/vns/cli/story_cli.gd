extends SceneTree

const Util := preload("res://addons/vns/vns_util.gd")
const Compiler := preload("res://addons/vns/vns_compiler.gd")

const USAGE := """剧本工具

用法: tools/story <build|check|lint> [--story-dir <目录>]

命令:
  build   编译 .vns → compiled/*.json（含结构校验与 lint）
  check   校验编译产物是否最新（源文件已改未重编则报错）
  lint    仅做结构与图分析检查，不写文件

选项:
  --story-dir <dir>  剧本目录（默认 res://game/story）

退出码: 0 通过 / 1 有错误 / 2 参数错误
"""


func _init() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or args[0] == "--help" or args[0] == "-h":
		print(USAGE)
		quit(0)
		return
	var command: String = args[0]
	if not ["build", "check", "lint"].has(command):
		printerr("未知命令: %s" % command)
		printerr(USAGE)
		quit(2)
		return
	var story_dir := "res://game/story"
	var i := 1
	while i < args.size():
		if args[i] == "--story-dir":
			if i + 1 >= args.size():
				printerr("--story-dir 缺少值")
				quit(2)
				return
			story_dir = args[i + 1]
			i += 2
			continue
		printerr("未知参数: %s" % args[i])
		printerr(USAGE)
		quit(2)
		return
	story_dir = story_dir.rstrip("/")

	match command:
		"build":
			var result := Compiler.build_story(story_dir)
			_report(result)
			if not result.ok:
				quit(1)
				return
			print("已编译 %d 个章节 → %s/compiled" % [result.written.size(), story_dir])
			quit(0)
		"check":
			var result := Compiler.check_story(story_dir)
			_report(result)
			for stale in result.get("stale", []):
				printerr("产物已过期: %s（运行 tools/story build）" % stale)
			for missing in result.get("missing", []):
				printerr("缺少编译产物: %s（运行 tools/story build）" % missing)
			if not result.ok:
				quit(1)
				return
			print("编译产物已是最新（%d warnings）" % result.warnings.size())
			quit(0)
		"lint":
			var result := Compiler.compile_story(story_dir)
			_report(result)
			if not result.errors.is_empty():
				quit(1)
				return
			print("lint 通过（%d warnings）" % result.warnings.size())
			quit(0)


func _report(result: Dictionary) -> void:
	for diagnostic in result.get("errors", []):
		printerr(Util.format_diagnostic(diagnostic))
	for diagnostic in result.get("warnings", []):
		print(Util.format_diagnostic(diagnostic))
