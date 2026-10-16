class_name CopierGame
extends Minigame
## A needle swings across the jam gauge. Press Space while it's in the green
## to yank the paper out a bit. Three good yanks frees it; two bad ones and
## the copier eats the page for good. Stress speeds the needle up.

const NEEDED := 3
const MAX_MISSES := 2

var pulls := 0
var misses := 0
var _phase := 0.0
var _speed := 1.0
var _zone_w := 0.2
var _zone_c := 0.5
var _gauge: Control
var _shake := 0.0


func app_title() -> String:
	return "COPYMASTER 9000  —  ERROR 4: PAPER JAM (AGAIN)"


func _build() -> void:
	time_limit = 13.0
	_speed = 0.8 + 0.8 * difficulty + Stress.value / 140.0
	_zone_w = lerpf(0.24, 0.13, difficulty)
	_new_zone()
	_gauge = Control.new()
	_gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gauge.clip_contents = true
	_gauge.draw.connect(_draw_gauge)
	body.add_child(_gauge)
	hint.text = "SPACE when the needle is in the green"
	Sfx.play("jam")


func _new_zone() -> void:
	_zone_c = randf_range(0.2, 0.8)


func _key(e: InputEventKey) -> void:
	if e.keycode != KEY_SPACE:
		return
	var needle := _needle()
	if absf(needle - _zone_c) <= _zone_w * 0.5:
		pulls += 1
		Sfx.play("turnstile", 0.8 + pulls * 0.15)
		if pulls >= NEEDED:
			finish("perfect" if misses == 0 else "ok")
		else:
			_new_zone()
	else:
		misses += 1
		_shake = 0.4
		Sfx.play("jam", 1.3)
		hint.text = "RRRIP. %d more and it's gone." % (MAX_MISSES - misses) if misses < MAX_MISSES else "The copier ate it."
		if misses >= MAX_MISSES:
			finish("fail")


func _needle() -> float:
	return 0.5 - 0.5 * cos(_phase * TAU)


func _tick(delta: float) -> void:
	_phase += delta * _speed * 0.5
	_shake = maxf(0.0, _shake - delta)
	_gauge.queue_redraw()


func _draw_gauge() -> void:
	var g := _gauge
	var w := g.size.x
	var off := Vector2(randf_range(-6, 6), randf_range(-6, 6)) * (_shake / 0.4)
	# copier body + paper
	var cop := Rect2(Vector2(w * 0.5 - 170, 18) + off, Vector2(340, 120))
	g.draw_rect(cop, Color("dfe2e6"))
	g.draw_rect(cop, UiStyle.INK, false, 4.0)
	g.draw_rect(Rect2(cop.position + Vector2(40, 52), Vector2(260, 16)), UiStyle.INK)
	var out := float(pulls) / NEEDED
	var paper := Rect2(Vector2(w * 0.5 - 60, 60) + off, Vector2(120, 40 + out * 90))
	g.draw_rect(paper, Color.WHITE)
	g.draw_rect(paper, UiStyle.INK, false, 3.0)
	for i in 3:
		g.draw_line(paper.position + Vector2(14, 70 + i * 16), paper.position + Vector2(106, 70 + i * 16), Color("c9c3d3"), 3.0)
	# gauge
	var gy := 230.0
	var gx0 := 60.0
	var gw := w - 120.0
	g.draw_rect(Rect2(gx0, gy, gw, 36), Color("e9e1cf"))
	g.draw_rect(Rect2(gx0 + gw * (_zone_c - _zone_w * 0.5), gy, gw * _zone_w, 36), Color("5ccf86"))
	g.draw_rect(Rect2(gx0, gy, gw, 36), UiStyle.INK, false, 3.0)
	var nx := gx0 + gw * _needle()
	g.draw_line(Vector2(nx, gy - 12), Vector2(nx, gy + 48), UiStyle.RED, 6.0)
	for i in NEEDED:
		var c := Vector2(w * 0.5 - 40 + i * 40, 200)
		g.draw_circle(c, 11, UiStyle.INK)
		g.draw_circle(c, 8, Color("5ccf86") if i < pulls else Color("e9e1cf"))
