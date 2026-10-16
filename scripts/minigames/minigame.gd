class_name Minigame
extends Control
## Base for the WarioWare-style office tasks. Subclasses build their content
## into `body` in _build(), handle keys in _key(), and call finish(grade)
## with "perfect", "ok" or "fail". The base draws a fake desktop-app window,
## runs the countdown and stamps the result. The game clock keeps running.

signal finished(grade: String)

const WINDOW_SIZE := Vector2(800, 470)

var task: Dictionary = {}
var params: Dictionary = {}
var difficulty := 0.0
var time_limit := 15.0
var time_left := 15.0
var body: Control
var hint: Label

var _done := false
var _bar: ProgressBar
var _window: PanelContainer
var _stamp: Label


func setup(t: Dictionary, d: float) -> void:
	task = t
	params = t.get("params", {})
	difficulty = d
	# Already in the tree: plain set_anchors_preset would keep the old (zero) rect.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	_build_frame()
	_build()
	time_left = time_limit
	_window.scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.tween_property(_window, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- override

func app_title() -> String:
	return "Task"


func _build() -> void:
	pass


func _key(_e: InputEventKey) -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _on_timeout() -> void:
	finish("fail")


# ---------------------------------------------------------------- frame

func _build_frame() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.06, 0.1, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_window = PanelContainer.new()
	_window.custom_minimum_size = WINDOW_SIZE
	_window.add_theme_stylebox_override("panel", UiStyle.panel(Color("f7f4ee"), 14, 4, 0))
	_window.position = _window_origin()
	_window.pivot_offset = WINDOW_SIZE * 0.5
	add_child(_window)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_window.add_child(v)
	# title bar
	var bar := PanelContainer.new()
	var bar_style := UiStyle.panel(Color("3d5f8e"), 10, 0, 8)
	bar_style.corner_radius_bottom_left = 0
	bar_style.corner_radius_bottom_right = 0
	bar.add_theme_stylebox_override("panel", bar_style)
	v.add_child(bar)
	var bh := HBoxContainer.new()
	bar.add_child(bh)
	var title := Label.new()
	title.text = app_title()
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(title)
	for c in [Color("f6c445"), Color("4fae9f"), Color("e2475f")]:
		var dot := ColorRect.new()
		dot.color = c
		dot.custom_minimum_size = Vector2(14, 14)
		bh.add_child(dot)
	# Park's instruction
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 16)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(inner)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 10)
	inner.add_child(iv)
	var order := Label.new()
	order.text = "Park: \"%s\"" % task.get("title", "Do the thing.")
	order.add_theme_font_size_override("font_size", 20)
	order.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(order)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.add_theme_stylebox_override("background", UiStyle.panel(Color("e9e1cf"), 7, 2, 0))
	_bar.add_theme_stylebox_override("fill", UiStyle.panel(UiStyle.YELLOW, 7, 2, 0))
	iv.add_child(_bar)
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(0, 290)
	iv.add_child(body)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UiStyle.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(hint)
	_stamp = UiStyle.loud_label("", 84, UiStyle.YELLOW, 14)
	_stamp.set_anchors_preset(Control.PRESET_CENTER)
	_stamp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stamp.grow_vertical = Control.GROW_DIRECTION_BOTH
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.visible = false
	add_child(_stamp)


func _process(delta: float) -> void:
	if _done:
		return
	time_left -= delta
	_bar.value = clampf(time_left / time_limit, 0.0, 1.0)
	if time_left < time_limit * 0.25:
		(_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = UiStyle.RED
	# Stress gets into the hands: the window trembles.
	var s := maxf(0.0, Stress.value - 45.0) / 55.0
	_window.position = _window_origin() + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s * 4.0
	_tick(delta)
	if time_left <= 0.0 and not _done:
		_on_timeout()


func _window_origin() -> Vector2:
	return (get_viewport_rect().size - WINDOW_SIZE) * 0.5


func _input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or not event.is_pressed():
		return
	var k := event as InputEventKey
	if k.keycode == KEY_ESCAPE:
		return  # let pause through
	_key(k)
	get_viewport().set_input_as_handled()


func finish(grade: String) -> void:
	if _done:
		return
	_done = true
	_stamp.text = {"perfect": "PERFECT!", "ok": "DONE.", "fail": "FAILED"}.get(grade, grade.to_upper())
	_stamp.add_theme_color_override("font_color", {"perfect": UiStyle.YELLOW, "ok": UiStyle.TEAL, "fail": UiStyle.RED}.get(grade, UiStyle.PAPER))
	_stamp.visible = true
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.rotation = deg_to_rad(-8)
	_stamp.scale = Vector2(2.2, 2.2)
	var tw := create_tween()
	tw.tween_property(_stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.85)
	tw.tween_callback(func() -> void: finished.emit(grade))


## Grade helper: clean and quick is perfect, finished is ok.
func grade_for(mistakes: int, fast_fraction: float = 0.4) -> String:
	if mistakes == 0 and time_left > time_limit * fast_fraction:
		return "perfect"
	return "ok"


## A label with the shared look, added to `parent`.
func label(parent: Control, text: String, size: int = 20, color: Color = UiStyle.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
