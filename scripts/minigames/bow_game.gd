class_name BowGame
extends Minigame
## Director Choi is here. Hold Space to bow deeper, let go to come up.
## Keep the bow inside the target band until the Sincerity bar fills.
## Too deep is sarcastic. Stress makes the back wobble.

var angle := 0.0
var sincerity := 0.0
var overbows := 0
var _lo := 82.0
var _hi := 98.0
var _held := false
var _over := false
var _t := 0.0
var _view: Control


func app_title() -> String:
	return "ETIQUETTE.SYS  —  Director Choi has entered the room"


func _build() -> void:
	time_limit = 11.0
	var band := lerpf(16.0, 9.0, difficulty)
	_lo = 90.0 - band * 0.5
	_hi = 90.0 + band * 0.5
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.clip_contents = true
	_view.draw.connect(_draw_view)
	body.add_child(_view)
	hint.text = "Hold SPACE to bow · keep it in the gold band"


func _key(_e: InputEventKey) -> void:
	pass  # polled in _tick so holding works


func _tick(delta: float) -> void:
	_t += delta
	_held = Input.is_key_pressed(KEY_SPACE)
	var rate := 95.0 if _held else -70.0
	angle = clampf(angle + rate * delta, 0.0, 130.0)
	var wobble := maxf(0.0, Stress.value - 35.0) / 65.0 * 9.0 * sin(_t * 11.0)
	var a := angle + wobble
	if a > 112.0:
		if not _over:
			_over = true
			overbows += 1
			hint.text = "Too deep! Now it's sarcastic."
			Sfx.play("buzz", 1.2)
	elif a < 105.0:
		_over = false
	if a >= _lo and a <= _hi:
		sincerity += delta / 2.2
	if sincerity >= 1.0:
		finish(grade_for(overbows, 0.35))
	_view.queue_redraw()


func _draw_view() -> void:
	var g := _view
	var c := Vector2(g.size.x * 0.33, 185)
	var r := 140.0
	# arc gauge from upright (0) to 130 degrees
	for i in 66:
		var a0 := deg_to_rad(-90.0 + i * 2.0)
		var deg := i * 2.0
		var col := Color("e9e1cf")
		if deg >= _lo and deg <= _hi:
			col = UiStyle.YELLOW
		elif deg > 112.0:
			col = Color("ffb3bd")
		g.draw_line(c + Vector2(cos(a0), sin(a0)) * (r - 18), c + Vector2(cos(a0), sin(a0)) * r, col, 10.0)
	var wobble := maxf(0.0, Stress.value - 35.0) / 65.0 * 9.0 * sin(_t * 11.0)
	var a := deg_to_rad(-90.0 + angle + wobble)
	# Jonaid as a stick of bent dignity
	var hip := c
	var head := hip + Vector2(cos(a), sin(a)) * 95.0
	g.draw_line(hip, hip + Vector2(0, 75), UiStyle.INK, 14.0)
	g.draw_line(hip, head, Color("414858"), 22.0)
	g.draw_circle(head + Vector2(cos(a), sin(a)) * 26.0, 30.0, Color("f1c9a5"))
	g.draw_circle(head + Vector2(cos(a), sin(a)) * 26.0, 30.0, UiStyle.INK, false, 3.0)
	# sincerity bar
	var bx := g.size.x * 0.66
	var font := UiStyle.font()
	g.draw_string(font, Vector2(bx, 60), "SINCERITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.INK)
	g.draw_rect(Rect2(bx, 76, 200, 30), Color("e9e1cf"))
	g.draw_rect(Rect2(bx, 76, 200 * clampf(sincerity, 0, 1), 30), UiStyle.TEAL)
	g.draw_rect(Rect2(bx, 76, 200, 30), UiStyle.INK, false, 3.0)
	g.draw_string(font, Vector2(bx, 150), "%d°" % int(angle + wobble), HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UiStyle.INK)
	g.draw_string(font, Vector2(bx, 190), "target %d-%d°" % [int(_lo), int(_hi)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiStyle.DIM)
