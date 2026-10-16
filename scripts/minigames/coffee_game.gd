class_name CoffeeGame
extends Minigame
## Memorise Park's order while it's on screen, then rebuild it one choice at
## a time with keys 1-4. Two wrong picks and Park "can taste the disrespect".

const STEPS := [
	["Drink", ["Americano", "Latte", "Barley tea", "Dalgona"]],
	["Shots", ["1 shot", "2 shots", "3 shots", "7 shots"]],
	["Ice", ["No ice", "2 cubes", "Exactly 5 cubes", "One big cube"]],
	["Stir", ["Clockwise", "Counter-clockwise", "Don't stir", "With a pen"]],
	["Cup", ["Paper cup", "His mug", "The golf trophy", "A beaker"]],
]

var order: Array[int] = []
var step := 0
var mistakes := 0
var memorise := 3.5
var _phase := "memorise"
var _show: Label
var _choices: VBoxContainer
var _picked: Label
var _steps := 4


func app_title() -> String:
	return "PANTRY OS  —  coffee_for_park.exe"


func _build() -> void:
	_steps = 4 if difficulty < 0.45 else 5
	memorise = lerpf(4.0, 2.6, difficulty)
	time_limit = memorise + 12.0
	for i in _steps:
		order.append(randi() % 4)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 10)
	body.add_child(v)
	_show = label(v, "", 30)
	_show.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	v.add_child(_choices)
	_picked = label(v, "", 18, UiStyle.DIM)
	_picked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var parts := PackedStringArray()
	for i in _steps:
		parts.append(STEPS[i][1][order[i]])
	_show.text = "Park's order:\n" + "  ·  ".join(parts)
	hint.text = "Memorise it!"


func _tick(_delta: float) -> void:
	if _phase == "memorise" and time_left < time_limit - memorise:
		_phase = "build"
		_show_step()


func _show_step() -> void:
	for c in _choices.get_children():
		c.queue_free()
	if step >= _steps:
		return
	_show.text = "%s?" % STEPS[step][0]
	for i in 4:
		label(_choices, "%d   %s" % [i + 1, STEPS[step][1][i]], 24)
	hint.text = "Press 1-4"


func _key(e: InputEventKey) -> void:
	if _phase != "build" or step >= _steps:
		return
	var n := e.unicode - 49
	if n < 0 or n > 3:
		return
	if n != order[step]:
		mistakes += 1
		Sfx.play("buzz", 1.5)
	else:
		Sfx.play("turnstile", 1.4)
	_picked.text += ("" if step == 0 else " · ") + STEPS[step][1][n]
	step += 1
	if step >= _steps:
		if mistakes >= 2:
			hint.text = "Park can taste the disrespect."
			finish("fail")
		else:
			finish(grade_for(mistakes, 0.25))
	else:
		_show_step()
