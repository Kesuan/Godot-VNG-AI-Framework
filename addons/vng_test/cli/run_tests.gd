extends SceneTree

const Discovery := preload("res://addons/vng_test/core/discovery.gd")
const Executor := preload("res://addons/vng_test/core/executor.gd")
const Orchestrator := preload("res://addons/vng_test/core/orchestrator.gd")

const VALUE_FLAGS := [
	"--root", "--timeout", "--hard-timeout", "--seed", "--jobs", "--filter", "--tags",
	"--only-ids", "--report-dir", "--min-tests", "--json-out",
]
const BOOL_FLAGS := [
	"--child", "--list", "--fast", "--rerun", "--isolate-all", "--quiet", "--json",
	"--flake-check", "--update-traces", "--help", "-h",
]

const USAGE := """VNG 测试运行器

用法: tools/test [选项] [-- <runner 选项>]

选项:
  --fast              仅运行 tests/unit（秒级反馈）
  --filter <glob>     过滤测试（文件路径 / file::test，含 * ? 通配；可重复）
  --tags <a,b>        仅运行含任一 tag 的用例（tag 来自 # @tag 注释）
  --rerun             仅重跑上次失败的用例（读取 results.json）
  --seed <n>          设置运行种子（默认 0，写入 VngRun.seed）
  --timeout <sec>     单用例软超时（默认 10）
  --hard-timeout <s>  单子进程硬超时，超时杀进程（默认 300）
  --jobs <n>          并行子进程数（默认 min(4, CPU)）
  --isolate-all       每个测试文件独立进程（默认仅 story/ 独立）
  --flake-check       全部跑两遍并比对用例状态（检测 flake）
  --update-traces     录制/更新 trace golden（显式批准，写入审计日志）
  --min-tests <n>     用例数低于 n 视为失败（防删测试变绿）
  --report-dir <dir>  报告输出目录（默认 res://test-results）
  --json              仅输出聚合 JSON 到 stdout
  --list              仅列出发现的测试文件
  --reimport          重新导入项目（工具包装层处理）
  --help              显示帮助

退出码: 0 通过 / 1 失败 / 2 框架错误 / 3 未发现测试
"""


func _init() -> void:
	_run()


func _run() -> void:
	var parsed := _parse_args(OS.get_cmdline_user_args())
	if parsed.get("error", "") != "":
		printerr(parsed.error)
		printerr(USAGE)
		quit(2)
		return
	var options: Dictionary = parsed.options

	if options.get("help", false):
		print(USAGE)
		quit(0)
		return

	if options.get("list", false):
		var files := Discovery.find_test_files(options.root)
		if files.is_empty():
			print("(未发现测试)")
		else:
			print("\n".join(files))
		quit(0)
		return

	if options.get("child", false):
		var executor := Executor.new()
		executor.tree = self
		executor.opts = options
		var code: int = await executor.run(PackedStringArray(options.files))
		quit(code)
		return

	var orchestrator := Orchestrator.new()
	orchestrator.opts = options
	quit(orchestrator.run())


func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"root": "res://tests",
		"timeout": 10.0,
		"hard_timeout": 300.0,
		"seed": 0,
		"jobs": mini(4, maxi(1, OS.get_processor_count())),
		"filter": [],
		"tags": [],
		"only_ids": [],
		"report_dir": "res://test-results",
		"min_tests": 0,
		"json_out": "",
		"child": false,
		"list": false,
		"fast": false,
		"rerun": false,
		"isolate_all": false,
		"quiet": false,
		"json": false,
		"flake_check": false,
		"update_traces": false,
		"help": false,
		"files": [],
	}
	var i := 0
	while i < args.size():
		var arg := args[i]
		if not arg.begins_with("-"):
			options.files.append(arg)
			i += 1
			continue
		if arg in BOOL_FLAGS:
			match arg:
				"-h", "--help":
					options.help = true
				"--child":
					options.child = true
				"--list":
					options.list = true
				"--fast":
					options.fast = true
				"--rerun":
					options.rerun = true
				"--isolate-all":
					options.isolate_all = true
				"--flake-check":
					options.flake_check = true
				"--update-traces":
					options.update_traces = true
				"--quiet":
					options.quiet = true
				"--json":
					options.json = true
			i += 1
			continue
		if not VALUE_FLAGS.has(arg):
			return {"error": "未知参数: %s" % arg, "options": options}
		if i + 1 >= args.size():
			return {"error": "参数缺少值: %s" % arg, "options": options}
		var value := args[i + 1]
		match arg:
			"--root":
				options.root = value.rstrip("/")
			"--timeout":
				options.timeout = maxf(0.1, float(value))
			"--hard-timeout":
				options.hard_timeout = maxf(1.0, float(value))
			"--seed":
				options.seed = int(value)
			"--jobs":
				options.jobs = maxi(1, int(value))
			"--filter":
				options.filter.append(value)
			"--tags":
				options.tags.append_array(_split_list(value))
			"--only-ids":
				options.only_ids.append_array(_split_list(value))
			"--report-dir":
				options.report_dir = value.rstrip("/")
			"--min-tests":
				options.min_tests = maxi(0, int(value))
			"--json-out":
				options.json_out = value
		i += 2
	return {"error": "", "options": options}


func _split_list(value: String) -> Array:
	var result: Array = []
	for part in value.split(","):
		var trimmed: String = part.strip_edges()
		if trimmed != "":
			result.append(trimmed)
	return result
