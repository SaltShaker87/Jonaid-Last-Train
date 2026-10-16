class_name TitleScreen
extends CanvasLayer
## Title over a slowly orbiting shot of the office.

signal start_pressed

var _best: Label
var _start: Button


func _ready() -> void:
	layer = 30
	var root := UiStyle.root_control(self)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.07, 0.12, 0.55)
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 560
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(60, 90)
	v.add_theme_constant_override("separation", 6)
	root.add_child(v)
	v.add_child(UiStyle.loud_label("JONAID", 110, UiStyle.YELLOW, 16))
	v.add_child(UiStyle.loud_label("LAST TRAIN  ·  막차", 34, UiStyle.PAPER, 8))
	var tag := UiStyle.loud_label("A salaryman survival game.\nNobody wins. Some people last longer.", 20, Color("d9d2e6"), 5)
	v.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	v.add_child(gap)
	_start = Button.new()
	_start.text = "Clock in"
	_start.custom_minimum_size = Vector2(260, 0)
	_start.pressed.connect(func() -> void: start_pressed.emit())
	v.add_child(_start)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(260, 0)
	quit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 24)
	v.add_child(gap2)
	_best = UiStyle.loud_label("", 20, UiStyle.PAPER, 5)
	v.add_child(_best)
	var keys := UiStyle.loud_label("WASD move · Mouse look · Shift run · E use · Esc pause", 16, Color("bdb5cc"), 4)
	keys.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	keys.position = Vector2(60, -48)
	keys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(keys)


func open() -> void:
	visible = true
	if Game.best_days > 0:
		_best.text = "Best: %d day%s · %s earned" % [Game.best_days, "" if Game.best_days == 1 else "s", Game.won(Game.best_money)]
	else:
		_best.text = "Best: nobody has survived yet."
	_start.grab_focus.call_deferred()
