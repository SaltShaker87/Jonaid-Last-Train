class_name StampGame
extends Minigame
## Documents slide under the 도장 on a conveyor. Space stamps. Stamp every
## real document, never the decoys (lunch menu, Park's divorce papers...).
## Missing a real one or stamping a decoy is a mistake.

const DOCS := 10
const DECOYS := ["LUNCH MENU", "A CAT PHOTO", "PARK'S DIVORCE PAPERS", "YOUR OWN RESIGNATION", "THE FIRE EXIT MAP"]

var stamp_word := "APPROVED"
var docs: Array[Dictionary] = []  ## {x, decoy, label, stamped}
var mistakes := 0
var _speed := 220.0
var _spawn_gap := 230.0
var _lane: Control
var _press := 0.0
var _resolved := 0


func app_title() -> String:
	return "도장 Approval Station  —  %d documents, 0 reading" % DOCS


func _build() -> void:
	stamp_word = String(params.get("stamp", "APPROVED"))
	_speed = lerpf(210.0, 330.0, difficulty)
	_spawn_gap = lerpf(240.0, 190.0, difficulty)
	time_limit = (DOCS * _spawn_gap + 900.0) / _speed + 1.5
	var decoy_count := 2 + int(round(difficulty * 2.0))
	var decoy_slots := {}
	while decoy_slots.size() < decoy_count:
		decoy_slots[randi_range(1, DOCS - 1)] = true
	for i in DOCS:
		var d := decoy_slots.has(i)
		docs.append({"x": 880.0 + i * _spawn_gap, "decoy": d, "label": DECOYS[randi() % DECOYS.size()] if d else "REQUEST #%d" % randi_range(100, 999), "stamped": false, "done": false})
	_lane = Control.new()
	_lane.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lane.clip_contents = true
	_lane.draw.connect(_draw_lane)
	body.add_child(_lane)
	hint.text = "SPACE to stamp %s · don't stamp the red ones" % stamp_word


func _stamp_x() -> float:
	return _lane.size.x * 0.5


func _key(e: InputEventKey) -> void:
	if e.keycode != KEY_SPACE:
		return
	_press = 0.18
	Sfx.play("turnstile", 0.7)
	var hit := false
	for d in docs:
		if d["done"]:
			continue
		if absf(float(d["x"]) - _stamp_x()) < 62.0:
			d["stamped"] = true
			d["done"] = true
			hit = true
			_resolved += 1
			if d["decoy"]:
				mistakes += 1
				hint.text = "You stamped %s %s. Nobody will notice. Probably." % [d["label"], stamp_word]
			break
	if not hit:
		mistakes += 1  # stamped the conveyor belt


func _tick(delta: float) -> void:
	_press = maxf(0.0, _press - delta)
	for d in docs:
		d["x"] = float(d["x"]) - _speed * delta
		if not d["done"] and float(d["x"]) < _stamp_x() - 70.0:
			d["done"] = true
			_resolved += 1
			if not d["decoy"]:
				mistakes += 1
	if _resolved >= DOCS:
		finish("perfect" if mistakes == 0 else ("ok" if mistakes <= 2 else "fail"))
	_lane.queue_redraw()


func _on_timeout() -> void:
	finish("ok" if mistakes <= 2 else "fail")


func _draw_lane() -> void:
	var g := _lane
	var font := UiStyle.font()
	var belt_y := 150.0
	g.draw_rect(Rect2(0, belt_y + 70, g.size.x, 24), Color("6b6475"))
	for i in 20:
		var x := fmod(i * 60.0 - (Time.get_ticks_msec() / 1000.0) * _speed, g.size.x + 60.0)
		g.draw_line(Vector2(x, belt_y + 72), Vector2(x - 14, belt_y + 92), Color("4d4757"), 3.0)
	for d in docs:
		var x := float(d["x"])
		if x < -100.0 or x > g.size.x + 100.0:
			continue
		var r := Rect2(Vector2(x - 55, belt_y - 50), Vector2(110, 120))
		g.draw_rect(r, Color("ffe1e1") if d["decoy"] else Color.WHITE)
		g.draw_rect(r, UiStyle.RED if d["decoy"] else UiStyle.INK, false, 3.0)
		var lbl: String = d["label"]
		g.draw_string(font, r.position + Vector2(6, 22), lbl, HORIZONTAL_ALIGNMENT_LEFT, 98, 12, UiStyle.RED if d["decoy"] else UiStyle.INK)
		for i in 3:
			g.draw_line(r.position + Vector2(10, 44 + i * 14), r.position + Vector2(100, 44 + i * 14), Color("d6d0de"), 3.0)
		if d["stamped"]:
			g.draw_circle(r.position + Vector2(55, 92), 22, Color(0.85, 0.16, 0.2, 0.85))
			g.draw_string(font, r.position + Vector2(18, 97), stamp_word.left(7), HORIZONTAL_ALIGNMENT_CENTER, 74, 13, Color.WHITE)
	# the stamp
	var sx := _stamp_x()
	var drop := 60.0 if _press > 0.0 else 0.0
	g.draw_rect(Rect2(sx - 20, 0 + drop, 40, 50), Color("d2a85a"))
	g.draw_rect(Rect2(sx - 30, 48 + drop, 60, 18), Color("c5303a"))
	g.draw_rect(Rect2(sx - 30, 48 + drop, 60, 18), UiStyle.INK, false, 3.0)
	g.draw_string(font, Vector2(16, 30), "mistakes: %d" % mistakes, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiStyle.RED if mistakes > 0 else UiStyle.DIM)
