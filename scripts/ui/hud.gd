class_name HUD
extends CanvasLayer
## In-game overlay: clock, stress face + bar, money, Hana's anger, the
## interaction prompt, notifications, location banner, day card and speech
## bubbles that follow whoever is talking. No 3D floating text anywhere.

const BUBBLE_MAX_W := 340.0

var _root: Control
var _clock: Label
var _day: Label
var _face: StressFace
var _stress_bar: ProgressBar
var _stress_lbl: Label
var _money: Label
var _anger_row: Control
var _anger_bar: ProgressBar
var _prompt: Control
var _prompt_lbl: Label
var _notify: PanelContainer
var _notify_lbl: Label
var _notify_queue: Array[String] = []
var _notify_t := 0.0
var _banner: Label
var _card: Control
var _card_title: Label
var _card_sub: Label
var _bubbles := {}  ## speaker instance id -> {node, panel, t}
var _bubble_layer: Control


func _ready() -> void:
	layer = 10
	_root = UiStyle.root_control(self)
	_build_status()
	_build_prompt()
	_build_notify()
	_build_banner()
	_bubble_layer = Control.new()
	_bubble_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bubble_layer)
	_build_card()
	Clock.minute_passed.connect(func(_m: int) -> void: _refresh_clock())
	Clock.day_started.connect(func(_d: int) -> void: _refresh_clock())
	Stress.changed.connect(_on_stress)
	Game.money_changed.connect(_on_money)
	Game.anger_changed.connect(_on_anger)
	Game.say_requested.connect(say)
	Game.notify_requested.connect(notify)
	_refresh_clock()
	_on_stress(Stress.value, 0.0)
	_on_money(Game.money, 0)
	_anger_row.visible = false


# ---------------------------------------------------------------- build

func _build_status() -> void:
	var box := PanelContainer.new()
	box.position = Vector2(16, 14)
	box.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PAPER, 16, 3, 12))
	_root.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	_day = Label.new()
	_day.add_theme_font_size_override("font_size", 16)
	_day.add_theme_color_override("font_color", UiStyle.DIM)
	v.add_child(_day)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 44)
	v.add_child(_clock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_face = StressFace.new()
	row.add_child(_face)
	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(sv)
	_stress_lbl = Label.new()
	_stress_lbl.add_theme_font_size_override("font_size", 15)
	sv.add_child(_stress_lbl)
	_stress_bar = _bar(Color("ff8a3d"))
	sv.add_child(_stress_bar)
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 24)
	v.add_child(_money)
	_anger_row = HBoxContainer.new()
	(_anger_row as HBoxContainer).add_theme_constant_override("separation", 8)
	v.add_child(_anger_row)
	var hl := Label.new()
	hl.text = "Hana"
	hl.add_theme_font_size_override("font_size", 15)
	_anger_row.add_child(hl)
	_anger_bar = _bar(UiStyle.RED)
	_anger_row.add_child(_anger_bar)


func _bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(150, 16)
	b.max_value = 100.0
	b.show_percentage = false
	var bg := UiStyle.panel(Color("e9e1cf"), 8, 2, 0)
	var fg := UiStyle.panel(fill, 8, 2, 0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _build_prompt() -> void:
	_prompt = HBoxContainer.new()
	(_prompt as HBoxContainer).add_theme_constant_override("separation", 10)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_bottom = -70
	_root.add_child(_prompt)
	var key := PanelContainer.new()
	key.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.YELLOW, 8, 3, 6))
	var kl := Label.new()
	kl.text = " E "
	kl.add_theme_font_size_override("font_size", 22)
	key.add_child(kl)
	_prompt.add_child(key)
	_prompt_lbl = UiStyle.loud_label("", 24, UiStyle.PAPER, 7)
	_prompt.add_child(_prompt_lbl)
	_prompt.visible = false


func _build_notify() -> void:
	_notify = PanelContainer.new()
	_notify.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.INK, 22, 0, 14))
	_notify.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notify.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notify.offset_top = 18
	_root.add_child(_notify)
	_notify_lbl = Label.new()
	_notify_lbl.add_theme_color_override("font_color", UiStyle.PAPER)
	_notify_lbl.add_theme_font_size_override("font_size", 20)
	_notify.add_child(_notify_lbl)
	_notify.visible = false


func _build_banner() -> void:
	_banner = UiStyle.loud_label("", 40, UiStyle.YELLOW, 10)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.offset_top = 120
	_banner.modulate.a = 0.0
	_root.add_child(_banner)


func _build_card() -> void:
	_card = ColorRect.new()
	(_card as ColorRect).color = Color(0.11, 0.1, 0.14, 0.92)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(v)
	_card_title = UiStyle.loud_label("", 96, UiStyle.YELLOW, 14)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_card_title)
	_card_sub = UiStyle.loud_label("", 26, UiStyle.PAPER, 6)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_card_sub)
	_card.modulate.a = 0.0
	_card.visible = false


# ---------------------------------------------------------------- updates

func _process(delta: float) -> void:
	_update_notify(delta)
	_update_bubbles(delta)


func _refresh_clock() -> void:
	_clock.text = Clock.now_string()
	_day.text = "%s · DAY %d" % [Clock.weekday_name().to_upper(), Clock.day]


func _on_stress(v: float, _d: float) -> void:
	_face.value = v
	_stress_bar.value = v
	_stress_lbl.text = "STRESS · %s" % Stress.band_name()


func _on_money(v: int, d: int) -> void:
	_money.text = Game.won(v)
	if d != 0:
		var tw := create_tween()
		_money.modulate = UiStyle.TEAL if d > 0 else UiStyle.RED
		tw.tween_property(_money, "modulate", Color.WHITE, 0.8)


func _on_anger(v: float, _d: float) -> void:
	_anger_bar.value = v
	if v > 0.0:
		_anger_row.visible = true


func show_anger(on: bool) -> void:
	_anger_row.visible = on


func set_prompt(target: Interactable) -> void:
	if target == null:
		_prompt.visible = false
		return
	_prompt_lbl.text = target.prompt
	_prompt.visible = true


func notify(text: String) -> void:
	_notify_queue.append(text)


func _update_notify(delta: float) -> void:
	if _notify_t > 0.0:
		_notify_t -= delta
		if _notify_t <= 0.4:
			_notify.modulate.a = maxf(_notify_t / 0.4, 0.0)
		if _notify_t <= 0.0:
			_notify.visible = false
	elif not _notify_queue.is_empty():
		_notify_lbl.text = _notify_queue.pop_front()
		_notify.visible = true
		_notify.modulate.a = 1.0
		_notify.reset_size()
		_notify_t = 3.8


func banner(text: String) -> void:
	_banner.text = text
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.8)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)


## Full-screen title card (start of day, etc.). Awaitable.
func card(title: String, sub: String, hold: float = 1.8) -> void:
	_card_title.text = title
	_card_sub.text = sub
	_card.visible = true
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.3)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 0.6)
	await tw.finished
	_card.visible = false


# ---------------------------------------------------------------- bubbles

func say(speaker: Node3D, text: String, seconds: float = 3.5) -> void:
	if speaker == null:
		notify(text)
		return
	var id := speaker.get_instance_id()
	if _bubbles.has(id):
		(_bubbles[id]["panel"] as Control).queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(Color.WHITE, 16, 3, 12))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var w := UiStyle.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 8.0
	lbl.custom_minimum_size = Vector2(minf(w, BUBBLE_MAX_W), 0)
	panel.add_child(lbl)
	var tail := Polygon2D.new()
	tail.color = Color.WHITE
	tail.polygon = PackedVector2Array([Vector2(-10, -3), Vector2(10, -3), Vector2(0, 14)])
	var tail_line := Line2D.new()
	tail_line.points = PackedVector2Array([Vector2(-10, 0), Vector2(0, 14), Vector2(10, 0)])
	tail_line.width = 3.0
	tail_line.default_color = UiStyle.INK
	panel.add_child(tail)
	panel.add_child(tail_line)
	_bubble_layer.add_child(panel)
	panel.scale = Vector2(0.6, 0.6)
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubbles[id] = {"node": speaker, "panel": panel, "t": seconds, "tail": tail, "line": tail_line}


func _update_bubbles(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var screen := get_viewport().get_visible_rect().size
	for id in _bubbles.keys():
		var b: Dictionary = _bubbles[id]
		var panel := b["panel"] as PanelContainer
		b["t"] = float(b["t"]) - delta
		# The speaker may have been freed with its location; check before casting.
		var raw: Variant = b["node"]
		if float(b["t"]) <= 0.0 or not is_instance_valid(raw) or not (raw as Node3D).is_inside_tree():
			panel.queue_free()
			_bubbles.erase(id)
			continue
		var node := raw as Node3D
		if float(b["t"]) < 0.3:
			panel.modulate.a = float(b["t"]) / 0.3
		if cam == null:
			continue
		var anchor: Vector3 = node.call("speech_anchor") if node.has_method("speech_anchor") else node.global_position + Vector3.UP * 2.2
		if cam.is_position_behind(anchor):
			panel.visible = false
			continue
		panel.visible = true
		var p := cam.unproject_position(anchor)
		var sz := panel.size
		panel.pivot_offset = Vector2(sz.x * 0.5, sz.y)
		var pos := p - Vector2(sz.x * 0.5, sz.y + 16.0)
		pos.x = clampf(pos.x, 8.0, screen.x - sz.x - 8.0)
		pos.y = clampf(pos.y, 8.0, screen.y - sz.y - 90.0)
		panel.position = pos
		var tail_x := clampf(p.x - pos.x, 18.0, sz.x - 18.0)
		(b["tail"] as Polygon2D).position = Vector2(tail_x, sz.y)
		(b["line"] as Line2D).position = Vector2(tail_x, sz.y - 1.0)
