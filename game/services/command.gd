class_name VngCommand
extends RefCounted

const TYPE_ADVANCE := "advance"
const TYPE_CHOOSE := "choose"
const TYPE_SKIP := "skip"
const TYPE_AUTO_TOGGLE := "auto_toggle"
const TYPE_SKIP_TO := "skip_to"


static func advance() -> Dictionary:
	return {"type": TYPE_ADVANCE}


static func choose(index: int) -> Dictionary:
	return {"type": TYPE_CHOOSE, "index": index}


static func skip() -> Dictionary:
	return {"type": TYPE_SKIP}


static func auto_toggle() -> Dictionary:
	return {"type": TYPE_AUTO_TOGGLE}


static func skip_to(node_id: String) -> Dictionary:
	return {"type": TYPE_SKIP_TO, "node": node_id}
