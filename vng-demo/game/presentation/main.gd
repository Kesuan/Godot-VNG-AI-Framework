extends Node

const VnsStoryLoader := preload("res://addons/vns/vns_story.gd")
const TitleScreenScene := preload("res://game/presentation/title_screen.tscn")
const StoryScreenScene := preload("res://game/presentation/story_screen.tscn")

var boot: VngBootConfig
var services: VngServices
var story: Dictionary = {}

var _current_screen: Node = null


func _ready() -> void:
	boot = VngBootConfig.from_cmdline()
	for error in boot.errors:
		push_error("BootConfig: %s" % error)
	services = VngServices.new(boot.seed)
	services.save_root = boot.save_root
	story = VnsStoryLoader.load_compiled("res://game/story")
	if not story.ok:
		_show_failure(story.errors)
		return
	_show_title()


func _show_title() -> void:
	var screen: Node = TitleScreenScene.instantiate()
	screen.start_requested.connect(_start_story)
	screen.quit_requested.connect(_quit)
	_swap_screen(screen)


func _start_story() -> void:
	var entry: String = story.manifest.get("entry", "")
	var split := VnsStoryLoader.split_entry(entry)
	var chapter: Dictionary = story.chapters.get(split.get("chapter", ""), {})
	if chapter.is_empty():
		_show_failure([{"message": "entry 章节不存在: %s" % entry}])
		return
	var screen: Node = StoryScreenScene.instantiate()
	screen.setup(services, chapter, split.get("node", ""), _display_names())
	screen.finished.connect(_show_title)
	_swap_screen(screen)


func _display_names() -> Dictionary:
	var names := {}
	var characters: Dictionary = story.manifest.get("characters", {})
	for char_id in characters:
		var definition: Dictionary = characters[char_id]
		names[char_id] = definition.get("name", char_id)
	return names


func _quit() -> void:
	get_tree().quit()


func _swap_screen(screen: Node) -> void:
	if _current_screen != null and is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = screen
	add_child(screen)


func _show_failure(errors: Array) -> void:
	for error in errors:
		push_error("剧本加载失败: %s" % error.get("message", ""))
	var label := Label.new()
	label.text = "剧本加载失败，请查看控制台输出"
	label.position = Vector2(80, 80)
	add_child(label)
