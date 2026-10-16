class_name ExcelGame
extends Minigame
## Copy the numbers off Park's napkin into the spreadsheet, one cell at a
## time (digits + Enter). Some tasks end with a TOTAL row Park insists is
## added up by hand. Under stress the napkin digits wobble.

var labels: Array = []
var values: Array[int] = []
var row := 0
var entry := ""
var mistakes := 0
var _cells: Array[Label] = []
var _rows: Array[PanelContainer] = []
var _napkin_nums: Array[Label] = []
var _t := 0.0


func app_title() -> String:
	return "Excelsior  —  Q3_numbers_DO_NOT_TOUCH (3).xlsx"


func _build() -> void:
	labels = (params.get("labels", ["A", "B", "C"]) as Array).duplicate()
	var digits := 2 + int(round(difficulty * 2.0))
	for i in labels.size():
		values.append(randi_range(int(pow(10, digits - 1)), int(pow(10, digits)) - 1))
	if bool(params.get("total", false)):
		labels.append("TOTAL (by hand)")
		var s := 0
		for v in values:
			s += v
		values.append(s)
	time_limit = 6.0 + values.size() * lerpf(4.0, 2.8, difficulty) + (6.0 if bool(params.get("total", false)) else 0.0)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 24)
	body.add_child(h)
	# Park's napkin
	var napkin := PanelContainer.new()
	napkin.custom_minimum_size = Vector2(230, 0)
	napkin.add_theme_stylebox_override("panel", UiStyle.panel(Color("fffbe9"), 4, 2, 14))
	napkin.rotation = deg_to_rad(-3)
	h.add_child(napkin)
	var nv := VBoxContainer.new()
	napkin.add_child(nv)
	label(nv, "napkin (stained)", 15, UiStyle.DIM)
	for i in values.size():
		if i == values.size() - 1 and bool(params.get("total", false)):
			label(nv, "TOTAL = ???", 22, UiStyle.RED)
			break
		_napkin_nums.append(label(nv, "%s: %d" % [labels[i], values[i]], 24))
	# the sheet
	var sheet := VBoxContainer.new()
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_theme_constant_override("separation", 4)
	h.add_child(sheet)
	for i in values.size():
		var r := PanelContainer.new()
		r.add_theme_stylebox_override("panel", UiStyle.panel(Color.WHITE, 2, 2, 6))
		sheet.add_child(r)
		var rh := HBoxContainer.new()
		r.add_child(rh)
		var l := label(rh, "%s" % labels[i], 20)
		l.custom_minimum_size = Vector2(190, 0)
		var c := label(rh, "", 22)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_cells.append(c)
		_rows.append(r)
	hint.text = "Type the number · Enter to commit · Backspace fixes"
	_refresh()


func _key(e: InputEventKey) -> void:
	if row >= values.size():
		return
	if e.keycode == KEY_BACKSPACE:
		entry = entry.left(maxi(0, entry.length() - 1))
	elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		if entry == "":
			return
		if int(entry) == values[row]:
			row += 1
			entry = ""
			Sfx.play("turnstile", 1.6)
			if row >= values.size():
				finish(grade_for(mistakes))
		else:
			mistakes += 1
			entry = ""
			Sfx.play("buzz", 1.4)
			_flash(_rows[row])
	elif e.unicode >= 48 and e.unicode <= 57 and entry.length() < 7:
		entry += char(e.unicode)
	_refresh()


func _tick(delta: float) -> void:
	_t += delta
	var wobble := maxf(0.0, Stress.value - 35.0) / 65.0
	for i in _napkin_nums.size():
		_napkin_nums[i].position.x = sin(_t * 9.0 + i * 1.7) * 5.0 * wobble


func _refresh() -> void:
	for i in _cells.size():
		var style := UiStyle.panel(Color.WHITE, 2, 2, 6)
		if i < row:
			_cells[i].text = str(values[i])
			style.bg_color = Color("dff5ea")
		elif i == row:
			_cells[i].text = entry + "|"
			style.bg_color = Color("fff1b8")
			style.border_color = Color("3d5f8e")
			style.set_border_width_all(3)
		else:
			_cells[i].text = ""
		_rows[i].add_theme_stylebox_override("panel", style)


func _flash(c: Control) -> void:
	c.modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(c, "modulate", Color.WHITE, 0.4)
