class_name StressFace
extends Control
## Jonaid's stress as a face: calm smile -> flat -> sweaty frown -> steaming
## scream. Drawn, no textures. Jitters when he's about to snap.

var value := 0.0
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := Vector2(size.x, size.y) * 0.5
	var band := Stress.band()
	if band == 3:
		c += Vector2(randf_range(-2, 2), randf_range(-2, 2))
	var r := s * 0.44
	var col: Color = [Color("ffe066"), Color("ffc24d"), Color("ff8a3d"), Color("ff4d4d")][band]
	draw_circle(c, r + 3.0, UiStyle.INK)
	draw_circle(c, r, col)
	var ink := UiStyle.INK
	var ex := r * 0.38
	var ey := -r * 0.18
	if band < 3:
		var eh := r * (0.16 if band < 2 else 0.22)
		for sx in [-1.0, 1.0]:
			draw_line(c + Vector2(sx * ex, ey - eh * 0.5), c + Vector2(sx * ex, ey + eh * 0.5), ink, 4.0, true)
	else:
		for sx in [-1.0, 1.0]:
			var e := c + Vector2(sx * ex, ey)
			draw_line(e + Vector2(-5, -5), e + Vector2(5, 5), ink, 3.5, true)
			draw_line(e + Vector2(-5, 5), e + Vector2(5, -5), ink, 3.5, true)
	var my := r * 0.38
	match band:
		0:
			draw_arc(c + Vector2(0, my - r * 0.22), r * 0.36, 0.35, PI - 0.35, 12, ink, 3.5, true)
		1:
			draw_line(c + Vector2(-r * 0.3, my), c + Vector2(r * 0.3, my), ink, 3.5, true)
		2:
			draw_arc(c + Vector2(0, my + r * 0.2), r * 0.3, PI + 0.5, TAU - 0.5, 12, ink, 3.5, true)
		_:
			var pts := PackedVector2Array()
			for i in 7:
				pts.append(c + Vector2(-r * 0.36 + i * r * 0.12, my + (4.0 if i % 2 else -4.0)))
			draw_polyline(pts, ink, 3.0, true)
	if band >= 2:
		var drop := c + Vector2(r * 0.85, -r * 0.45 + fmod(_t * 18.0, 10.0))
		draw_circle(drop, 5.0, Color("7fd3ff"))
	if band == 3:
		for i in 3:
			var p := c + Vector2(-r * 0.6 + i * r * 0.6, -r - 6.0 - fmod(_t * 30.0 + i * 7.0, 14.0))
			draw_circle(p, 4.0, Color(1, 1, 1, 0.8))
