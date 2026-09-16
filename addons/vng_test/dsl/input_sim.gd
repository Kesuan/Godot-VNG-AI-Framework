extends RefCounted

const DESIGN_SIZE := Vector2i(1280, 720)


static func click(tree: SceneTree, position := Vector2(100.0, 100.0)) -> void:
	var window: Window = tree.root
	window.size = DESIGN_SIZE
	_push_motion(window, position)
	await tree.process_frame
	_push_button(window, position)
	await tree.process_frame


static func press_action(tree: SceneTree, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	tree.root.push_input(press)
	await tree.process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	tree.root.push_input(release)
	await tree.process_frame


static func _push_motion(window: Window, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	window.push_input(motion)


static func _push_button(window: Window, position: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = position
	click.global_position = position
	window.push_input(click)
