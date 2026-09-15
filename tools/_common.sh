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
