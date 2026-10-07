extends SkillBase
class_name TraceSkill
## Kit: trace. Heavy, first-person lightbox (GDD §10 DO NOT COPY).
## Follow the site boundary. Shaky line gets rejected.
## Stress drifts the mask / shakes the trace. Forced error at 81+.

var _points: PackedVector2Array = PackedVector2Array()
var _drawn: PackedVector2Array = PackedVector2Array()
var _tracing := false
var _forced_done := false
var _time := 0.0
var _lag_buf: PackedVector2Array = PackedVector2Array()
var _info: Label
var _draw: Control
var _mouse := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

static func create() -> TraceSkill:
	var s := TraceSkill.new()
	s.name = "TraceSkill"
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.is_heavy = true
	return s

func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_info = Label.new()
	_info.text = "LIGHTBOX TRACE — follow the ivory boundary. Click-drag with mouse. Enter to submit."
	_info.position = Vector2(24, 16)
	_info.size = Vector2(1200, 30)
	add_child(_info)
	_draw = TraceCanvas.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.skill = self
	add_child(_draw)

func start(p_stress: float, p_seed: int) -> void:
	super.start(p_stress, p_seed)
	_rng.seed = p_seed * 7919 + 13
	_points.clear()
	_drawn.clear()
	_lag_buf.clear()
	_time = 0.0
	_forced_done = false
	# Site boundary: rounded rect path (legally distinct, always readable stamp nearby).
	var r := Rect2(Vector2(340, 180), Vector2(600, 380))
	var n := 48
	for i in n:
		var t := float(i) / float(n) * TAU
		var p := Vector2(r.get_center().x + cos(t) * r.size.x * 0.5, r.get_center().y + sin(t) * r.size.y * 0.5)
		_points.append(p)
	# Stamp text drawn by canvas.
	if StressSys.has_forced_error() and not _forced_done:
		# Forced error: first 15% of drawn points get a jerk (recoverable).
		_forced_done = true
	_info.text = "LIGHTBOX 21:40 — stress %d (%s). Trace the boundary. Forced wobble above 80." % [int(p_stress), StressSys.band_name()]
	queue_redraw()

func _process(delta: float) -> void:
	if not visible or _done:
		return
	_time += delta
	if _tracing:
		var target := get_global_mouse_position()
		# Lag frames simulate heavy hands.
		_lag_buf.append(target)
		var lag := StressSys.lag_frames()
		while _lag_buf.size() > lag + 1:
			_lag_buf.remove_at(0)
		var p: Vector2 = _lag_buf[0] if _lag_buf.size() > lag else target
		# Noise shake.
		var n := noise_px()
		if n > 0.0:
			p += Vector2(randf_range(-n, n), randf_range(-n, n))
		_drawn.append(p)
		if _draw != null:
			_draw.queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_tracing = mb.pressed
			if not _tracing and _drawn.size() > 10:
				pass
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_ENTER:
			_grade_and_finish()

func _grade_and_finish() -> void:
	if _drawn.size() < 20:
		complete("fail")
		return
	# Accuracy: mean distance from drawn to nearest boundary point.
	var err := 0.0
	for p in _drawn:
		var best := 1e9
		for q in _points:
			best = minf(best, p.distance_to(q))
		err += best
	err /= float(_drawn.size())
	# Scale tolerance by stress window so high stress is funny but recoverable.
	var tol_clean := 14.0
	var tol_sloppy := 30.0
	var grade := "fail"
	if err <= tol_clean:
		grade = "clean"
	elif err <= tol_sloppy:
		grade = "sloppy"
	complete(grade)


class TraceCanvas extends Control:
	var skill: TraceSkill
	func _draw() -> void:
		if skill == null:
			return
		# Lightbox glow
		draw_rect(Rect2(Vector2(300, 140), Vector2(680, 460)), Color(0.92, 0.90, 0.82, 0.14), true)
		draw_rect(Rect2(Vector2(300, 140), Vector2(680, 460)), Color(0.91, 0.87, 0.77), false, 3.0)
		# Stamp
		draw_string(ThemeDB.fallback_font, Vector2(360, 560), "DO NOT COPY", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.55, 0.10, 0.12))
		# Boundary
		if skill._points.size() > 1:
			draw_polyline(skill._points + PackedVector2Array([skill._points[0]]), Color(0.95, 0.93, 0.82), 2.0)
		# Drawn line
		if skill._drawn.size() > 1:
			draw_polyline(skill._drawn, Color(0.85, 0.66, 0.25), 3.0)
