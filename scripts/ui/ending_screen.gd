extends CanvasLayer
class_name EndingScreen

var _root: Control
var _title: Label
var _body: Label

static func create() -> EndingScreen:
	var e := EndingScreen.new()
	e.name = "Ending"
	e.layer = 60
	return e

func _ready() -> void:
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.04, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 54)
	_title.position = Vector2(80, 80)
	_title.size = Vector2(1100, 80)
	_root.add_child(_title)
	_body = Label.new()
	_body.position = Vector2(80, 180)
	_body.size = Vector2(1100, 380)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_body)
	var btn := Button.new()
	btn.text = "Next morning / title"
	btn.position = Vector2(80, 580)
	btn.size = Vector2(300, 50)
	btn.pressed.connect(func(): get_tree().reload_current_scene())
	_root.add_child(btn)

func show_ending(kind: String, ending_id: String) -> void:
	visible = true
	var titles := {
		"fired": "FIRED — Hansung let you go",
		"divorced": "DIVORCED — the suitcase in the entry",
		"divorced_nuclear": "DIVORCED — one nuclear night",
		"key_still_works": "DAY 60 — the key still works",
		"corner_cubicle": "DAY 60 — corner cubicle",
		"sold_filter": "DAY 60 — we sold the filter",
		"chairman_bubbles": "Chairman Bubbles",
		"clerk_yoon_right": "Clerk Yoon was right",
		"quit_draft": "Unsent draft: you quit. Unemployed, married, fish alive.",
	}
	var bodies := {
		"fired": "PIP hit 100 because the slides were empty or Sora's number survived. Park can threaten you over the map. The system will not fire you for it — but it fired you for this.",
		"divorced": "Hana at zero for five mornings. Telegraphed by the suitcase. Her line stays: you hired someone so you could stay at the office.",
		"divorced_nuclear": "Promised recital missed, nanny in the apartment, first train home. One night, no appeal.",
		"key_still_works": "Hana steady, PIP clean, fish alive. Shoes off, door still open.",
		"corner_cubicle": "Face high, couch permanent. You won the floor and lost the living room.",
		"sold_filter": "Money fine, kids low. The tank hums. Nobody watches it.",
		"chairman_bubbles": "Tank empty. No jump scare. The ending stays quiet.",
		"clerk_yoon_right": "Every illegal trace refused. Yoon stamps nothing. You kept your hands clean.",
		"quit_draft": "Secret exit: a KakaoTalk draft that says you quit, after a nuclear near-miss.",
	}
	_title.text = titles.get(ending_id, kind.to_upper())
	_body.text = bodies.get(ending_id, "The day clock stopped for you.")
