extends CanvasLayer
class_name PauseMenu
## Escape pause. The clock already respects get_tree().paused (DayClock);
## this node runs with process_mode ALWAYS so it can un-pause itself.

var _game: Node
var _root: Control

static func create(game: Node) -> PauseMenu:
	var p := PauseMenu.new()
	p.name = "PauseMenu"
	p.layer = 70
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p._game = game
	return p

func _ready() -> void:
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.04, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var label := Label.new()
	label.text = "PAUSED — the building clock stops with you"
	label.add_theme_font_size_override("font_size", 40)
	label.position = Vector2(80, 140)
	label.size = Vector2(1100, 60)
	_root.add_child(label)
	var hint := Label.new()
	hint.text = "WASD walk · mouse look · E interact · Q phone · F drop carry · Shift sprint\nWhite=errand · Gold=manual · Oxblood=heavy\n[Esc] resume"
	hint.position = Vector2(80, 240)
	hint.size = Vector2(1100, 120)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(hint)
	var resume := Button.new()
	resume.text = "Resume"
	resume.position = Vector2(80, 420)
	resume.size = Vector2(240, 56)
	resume.pressed.connect(func(): _game.call("toggle_pause"))
	_root.add_child(resume)
	var quit := Button.new()
	quit.text = "Quit to title"
	quit.position = Vector2(360, 420)
	quit.size = Vector2(240, 56)
	quit.pressed.connect(func(): _game.call("quit_to_title"))
	_root.add_child(quit)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_ESCAPE and visible:
			_game.call("toggle_pause")
