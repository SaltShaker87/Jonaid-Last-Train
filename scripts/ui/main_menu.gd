extends CanvasLayer
class_name MainMenu
## Title + briefing. English UI with Korean texture (GDD §21 locked call).

signal new_game_pressed
signal continue_pressed

var _root: Control
var menu_open := true

static func create() -> MainMenu:
	var m := MainMenu.new()
	m.name = "MainMenu"
	m.layer = 50
	return m

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var title := Label.new()
	title.text = "JONAID\nLAST TRAIN"
	title.add_theme_font_size_override("font_size", 72)
	title.position = Vector2(80, 80)
	title.size = Vector2(600, 200)
	_root.add_child(title)
	var sub := Label.new()
	sub.text = "A Korean salaryman simulator · Hansung Electronics (fictional)\nThird person in the world. First person only for lightbox + slides.\nWorld clock runs while you walk and type. Skills freeze the building, bill minutes on exit.\n\nWASD walk · mouse look · E interact · Q phone · F drop carry · Shift sprint (low stress + high body)\nWhite=errand · Gold=manual · Oxblood=heavy\n\n08:50 Tuesday. Tube on the desk. Vendor folder unpinned. Harin's slip in your bag.\nWin: still have the apartment key on day 60, fish alive, slides filed.\nLose: Hansung fires you (PIP 100) or Hana divorces you."
	sub.position = Vector2(80, 300)
	sub.size = Vector2(1100, 260)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(sub)
	var cont := Button.new()
	cont.text = "Continue — last morning"
	cont.position = Vector2(80, 585)
	cont.size = Vector2(420, 46)
	cont.visible = SaveIO.has_save()
	cont.pressed.connect(func(): continue_pressed.emit())
	_root.add_child(cont)
	var btn := Button.new()
	btn.text = "Start Tuesday 08:50 — badge in"
	btn.position = Vector2(80, 645)
	btn.size = Vector2(420, 56)
	btn.pressed.connect(func(): new_game_pressed.emit())
	_root.add_child(btn)
	var note := Label.new()
	note.text = "No Samsung marks, no real executives, no real car badges. The roast is the pitch. The build is original."
	note.position = Vector2(80, 715)
	note.size = Vector2(1100, 40)
	_root.add_child(note)

func hide_menu() -> void:
	_root.visible = false
	menu_open = false

func show_menu() -> void:
	_root.visible = true
	menu_open = true
