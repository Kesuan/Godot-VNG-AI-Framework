extends RefCounted

const BG_PALETTE := [
	Color("2b3a55"),
	Color("5c4d7d"),
	Color("7d5a5a"),
	Color("4d6b5a"),
	Color("6b5a3f"),
	Color("3f5a6b"),
	Color("5a4d6b"),
	Color("6b4d5a"),
]

const CHAR_PALETTE := [
	Color("8a5a6b"),
	Color("5a6b8a"),
	Color("6b8a5a"),
	Color("8a7a5a"),
]

const POS_RATIOS := {
	"left": 0.25,
	"center": 0.5,
	"right": 0.75,
}


static func bg_color(asset: String) -> Color:
	return _color_for(asset, BG_PALETTE)


static func char_color(char_id: String) -> Color:
	return _color_for(char_id, CHAR_PALETTE)


static func pos_ratio(pos: String) -> float:
	return POS_RATIOS.get(pos, 0.5)


static func _color_for(id: String, palette: Array) -> Color:
	if id.is_empty():
		return Color("1a1c22")
	var total := 0
	for i in id.length():
		total += id.unicode_at(i)
	return palette[total % palette.size()]
