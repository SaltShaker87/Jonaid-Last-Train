class_name TaskList
extends VBoxContainer
## Park's list as sticky notes down the right edge of the HUD: what, where,
## when it's due and what it pays. Due-soon notes turn red and shake; finished
## ones get stamped and peel off.

const NOTE_W := 270.0
const NOTE_COLORS := [Color("ffe680"), Color("ffd0e0"), Color("c9f0ff"), Color("d6f5c4")]

var _notes := {}  ## uid -> {panel, due_label}
var _header: Label
var _t := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	# A fixed-width column hugging the right edge.
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -(NOTE_W + 16.0)
	offset_right = -16.0
	offset_top = 14.0
	custom_minimum_size = Vector2(NOTE_W, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header = UiStyle.loud_label("PARK'S LIST", 22, UiStyle.YELLOW, 7)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_header)
	Tasks.task_added.connect(_on_added)
	Tasks.task_removed.connect(_on_removed)
	_refresh_header()


func _process(delta: float) -> void:
	_t += delta
	for uid in _notes:
		var n: Dictionary = _notes[uid]
		var t: Dictionary = n["task"]
		var left := float(t["due"]) - Clock.minutes
		var due := n["due"] as Label
		due.text = "due %s  ·  %s" % [Clock.format(float(t["due"])), Game.won(int(t.get("pay", 0)))]
		var urgent := left < 15.0
		due.add_theme_color_override("font_color", UiStyle.RED if urgent else UiStyle.DIM)
		var p := n["panel"] as Control
		if not bool(n.get("leaving", false)):
			p.rotation = deg_to_rad(float(n["tilt"])) + (sin(_t * 30.0) * 0.03 if left < 8.0 else 0.0)


func _on_added(t: Dictionary) -> void:
	var panel := PanelContainer.new()
	var col: Color = NOTE_COLORS[int(t["uid"]) % NOTE_COLORS.size()]
	var style := UiStyle.panel(col, 4, 3, 10)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(NOTE_W, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var title := Label.new()
	title.text = String(t.get("title", "?"))
	title.add_theme_font_size_override("font_size", 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(NOTE_W - 24, 0)
	v.add_child(title)
	var where := Label.new()
	where.text = "→ " + String(t.get("where", ""))
	where.add_theme_font_size_override("font_size", 15)
	where.add_theme_color_override("font_color", Color("3d5f8e"))
	v.add_child(where)
	var due := Label.new()
	due.add_theme_font_size_override("font_size", 15)
	v.add_child(due)
	add_child(panel)
	var tilt := randf_range(-2.5, 2.5)
	panel.pivot_offset = Vector2(NOTE_W * 0.5, 30)
	_notes[t["uid"]] = {"panel": panel, "due": due, "task": t, "tilt": tilt}
	panel.modulate.a = 0.0
	panel.scale = Vector2(1.3, 1.3)
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh_header()


func _on_removed(t: Dictionary, outcome: String) -> void:
	if not _notes.has(t["uid"]):
		return
	var n: Dictionary = _notes[t["uid"]]
	_notes.erase(t["uid"])
	n["leaving"] = true
	var panel := n["panel"] as PanelContainer
	if outcome != "cleared":
		var stamp := UiStyle.loud_label({"perfect": "PERFECT", "ok": "DONE", "fail": "FAILED", "expired": "LATE",
			"abandoned": "ABANDONED"}.get(outcome, outcome.to_upper()), 30,
			UiStyle.TEAL if outcome in ["perfect", "ok"] else UiStyle.RED, 7)
		stamp.rotation = deg_to_rad(-12)
		stamp.position = Vector2(40, 10)
		panel.add_child(stamp)
	var tw := panel.create_tween()
	tw.tween_interval(0.9 if outcome != "cleared" else 0.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(_refresh_header)
	_refresh_header()


func _refresh_header() -> void:
	var n := _notes.size()
	_header.text = "PARK'S LIST  (%d)" % n if n > 0 else "PARK'S LIST  (empty?!)"
