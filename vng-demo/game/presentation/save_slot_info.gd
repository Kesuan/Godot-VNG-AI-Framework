extends RefCounted

## 存档槽位展示信息：名称 / 章节标题 / 游戏时长 / 台词预览。

const SLOT_ORDER := ["auto", "slot1", "slot2", "slot3"]
const SLOT_NAMES := {"auto": "自动存档", "slot1": "存档 1", "slot2": "存档 2", "slot3": "存档 3"}


static func infos(store: VngSaveStore, manifest: Dictionary, mode: String) -> Array:
	var result: Array = []
	for slot in SLOT_ORDER:
		var info := {"slot": slot, "disabled": false, "label": ""}
		if slot == "auto" and mode == "save":
			info["label"] = "%s（自动维护）" % slot_name(slot)
			info["disabled"] = true
		else:
			var save := store.read(slot)
			if save.is_empty():
				info["label"] = "%s · 空" % slot_name(slot)
				info["disabled"] = mode == "load"
			else:
				info["label"] = label(slot, save, manifest)
		result.append(info)
	return result


static func label(slot: String, save: Dictionary, manifest: Dictionary) -> String:
	var chapter := str(save.get("chapter", ""))
	var chapter_title := chapter_name(manifest, chapter)
	var preview := str((save.get("line", {}) as Dictionary).get("text", "")).replace("\n", " ")
	if preview.length() > 14:
		preview = preview.substr(0, 14) + "…"
	var time := format_time(float(save.get("play_time", 0.0)))
	var detail := str(save.get("node", ""))
	if preview != "":
		detail += "：" + preview
	return "%s · %s · %s\n%s" % [slot_name(slot), chapter_title, time, detail]


static func slot_name(slot: String) -> String:
	return str(SLOT_NAMES.get(slot, slot))


static func format_time(seconds: float) -> String:
	var total := int(maxf(0.0, seconds))
	return "%02d:%02d" % [total / 60, total % 60]


static func chapter_name(manifest: Dictionary, chapter_id: String) -> String:
	var titles: Dictionary = manifest.get("titles", {})
	return str(titles.get(chapter_id, chapter_id))
