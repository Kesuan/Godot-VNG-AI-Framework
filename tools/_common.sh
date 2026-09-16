#!/usr/bin/env bash

vng_resolve_godot() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		return 0
	elif command -v godot >/dev/null 2>&1; then
		GODOT_BIN="$(command -v godot)"
	elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
		GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
	else
		echo "找不到 Godot 可执行文件，请设置 GODOT_BIN 环境变量" >&2
		return 1
	fi
}

vng_ensure_import() {
	local root="$1"
	local cache="$root/.godot/global_script_class_cache.cfg"
	local needs_import=0
	if [[ ! -f "$cache" ]]; then
		needs_import=1
	else
		local changed_classes
		changed_classes="$(find "$root/game" "$root/addons" "$root/tests" -name '*.gd' -newer "$cache" -print0 2>/dev/null |
			xargs -0 grep -hoE '^class_name [A-Za-z_][A-Za-z0-9_]*' 2>/dev/null | awk '{print $2}' | sort -u)"
		for cls in $changed_classes; do
			if ! grep -q "\"$cls\"" "$cache"; then
				needs_import=1
				break
			fi
		done
	fi
	if [[ "$needs_import" == "1" ]]; then
		echo "导入项目资源与脚本类缓存..." >&2
		if ! "$GODOT_BIN" --headless --no-header --path "$root" --import >/dev/null 2>&1; then
			echo "项目导入失败，请检查工程配置" >&2
			return 1
		fi
	fi
}

VNG_WATCHDOG_PID=""

vng_kill_watchdog() {
	if [[ -n "${VNG_WATCHDOG_PID:-}" ]]; then
		kill "$VNG_WATCHDOG_PID" 2>/dev/null
		VNG_WATCHDOG_PID=""
	fi
}

vng_run_with_watchdog() {
	local project="$1"
	local script_path="$2"
	shift 2
	local watchdog_sec="${VNG_TEST_WATCHDOG_SEC:-1800}"

	"$GODOT_BIN" --headless --no-header --path "$project" --script "$script_path" -- "$@" &
	local runner_pid=$!

	(
		elapsed=0
		while kill -0 "$runner_pid" 2>/dev/null; do
			if [[ "$elapsed" -ge "$watchdog_sec" ]]; then
				echo "runner 超过硬超时 ${watchdog_sec}s，强制终止（可用 VNG_TEST_WATCHDOG_SEC 调整）" >&2
				pkill -P "$runner_pid" 2>/dev/null
				kill -9 "$runner_pid" 2>/dev/null
				break
			fi
			sleep 1
			elapsed=$((elapsed + 1))
		done
	) &
	VNG_WATCHDOG_PID=$!
	local watchdog_pid=$VNG_WATCHDOG_PID

	trap vng_kill_watchdog EXIT

	wait "$runner_pid"
	local code=$?

	vng_kill_watchdog
	wait "$watchdog_pid" 2>/dev/null

	if [[ "$code" -gt 128 ]]; then
		echo "runner 被信号终止（exit=${code}）" >&2
		return 2
	fi
	return "$code"
}
