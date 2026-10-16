class_name PauseMenu
extends CanvasLayer
## Esc menu. Runs while the tree is paused.

signal resume_pressed
signal title_pressed

var _resume: Button


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := UiStyle.root_control(self)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.07, 0.12, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.add_theme_constant_override("separation", 12)
	root.add_child(v)
	var t := UiStyle.loud_label("PAUSED", 64, UiStyle.YELLOW, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UiStyle.loud_label("Park doesn't know about this button.", 18, UiStyle.PAPER, 5)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_resume = _button(v, "Resume", func() -> void: resume_pressed.emit())
	_button(v, "Quit to title", func() -> void: title_pressed.emit())
	_button(v, "Quit game", func() -> void: get_tree().quit())
	visible = false


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 0)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func open() -> void:
	visible = true
	_resume.grab_focus.call_deferred()
