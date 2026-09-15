class_name VngBootConfig
extends RefCounted

var test_mode := false
var seed := 0
var save_root := "user://saves"
var errors: Array[String] = []


static func from_cmdline() -> VngBootConfig:
	return parse(OS.get_cmdline_user_args())


static func parse(args: PackedStringArray) -> VngBootConfig:
	var config := VngBootConfig.new()
	var i := 0
	while i < args.size():
		var arg: String = args[i]
		var key := arg
		var value := ""
		if arg.contains("="):
			key = arg.get_slice("=", 0)
			value = arg.get_slice("=", 1)
		match key:
			"--test-mode":
				config.test_mode = true
				i += 1
			"--seed", "--save-root":
				if value == "":
					if i + 1 >= args.size():
						config.errors.append("参数缺少值: %s" % key)
						i += 1
						continue
					value = args[i + 1]
					i += 2
				else:
					i += 1
				if key == "--seed":
					if value.is_valid_int():
						config.seed = int(value)
					else:
						config.errors.append("--seed 需要整数: %s" % value)
				else:
					config.save_root = value
			_:
				i += 1
	return config
