extends SkillBase
class_name SlidesSkill
## Kit: assemble-slides. Heavy, first person at your PC (GDD §10 Friday slides).
## Drop figures into the vendor pack, catch Sora's bad number if she sniped you.
## Stress inserts typos and swapped axes. PIP reads the file at 18:00.

var figures: Array = []       # {id, value, bad:bool, placed:bool}
var pack_slots: Array = [ -1, -1, -1, -1 ]
var cursor: int = 0
var time_left: float = 90.0
var typos: int = 0
var _info: Label
var _view: Label
var _rng := RandomNumberGenerator.new()

static func create() -> SlidesSkill:
	var s := SlidesSkill.new()
	s.name = "SlidesSkill"
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.is_heavy = true
	return s

func _ready() -> void:
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_info = Label.new()
	_info.position = Vector2(24, 12)
	_info.size = Vector2(1232, 70)
	add_child(_info)
	_view = Label.new()
	_view.position = Vector2(24, 90)
	_view.size = Vector2(1232, 560)
	_view.add_theme_font_size_override("font_size", 24)
	add_child(_view)

func start(p_stress: float, p_seed: int) -> void:
	super.start(p_stress, p_seed)
	_rng.seed = p_seed * 101 + 3
	cursor = 0
	time_left = 90.0
	typos = 0
	pack_slots = [-1, -1, -1, -1]
	figures.clear()
	var sniped: bool = GameState.sora_sniped
	for i in 5:
		var bad := false
		if sniped and i == 2:
			bad = true  # Sora's bad number planted in the pile
		figures.append({"id": i, "value": 40 + _rng.randi_range(0, 50), "bad": bad, "placed": false})
	# Stress swaps two figures' apparent values (swapped axes).
	if StressSys.band() >= StressSys.Band.SHAKE and figures.size() >= 2:
		var a: Dictionary = figures[0]
		var b: Dictionary = figures[1]
		var tmp = a["value"]
		a["value"] = b["value"]
		b["value"] = tmp
		typos += 1
	_refresh()
	_info.text = "VENDOR PACK — 1..5 place figure, Q/W clear slot, Enter file. Catch the bad number. Stress %d." % int(p_stress)

func _process(delta: float) -> void:
	if not visible or _done:
		return
	time_left -= delta
	if time_left <= 0.0:
		_grade()
	_refresh_time()

func _refresh_time() -> void:
	_refresh()

func _input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode >= KEY_1 and k.keycode <= KEY_5:
			_place(int(k.keycode - KEY_1))
		elif k.keycode == KEY_ENTER:
			_grade()

func _place(fig_idx: int) -> void:
	if fig_idx < 0 or fig_idx >= figures.size():
		return
	var f: Dictionary = figures[fig_idx]
	if f["placed"]:
		return
	# Find first empty pack slot.
	for i in pack_slots.size():
		if int(pack_slots[i]) == -1:
			# Stress typo: small chance to place wrong figure.
			if StressSys.band() >= StressSys.Band.WARM and randf() < 0.12:
				typos += 1
				_info.text = "Typo! Hands slipped — check the axes."
			pack_slots[i] = fig_idx
			f["placed"] = true
			break
	_refresh()

func _refresh() -> void:
	if _view == null:
		return
	var txt := "PACK: "
	for i in pack_slots.size():
		var pi := int(pack_slots[i])
		if pi == -1:
			txt += "[ slot %d: empty ] " % (i + 1)
		else:
			var f: Dictionary = figures[pi]
			txt += "[ slot %d: fig%d=%d%s ] " % [i + 1, pi + 1, int(f["value"]), "?" if bool(f["bad"]) else ""]
	txt += "\n\nPILE:\n"
	for i in figures.size():
		var g: Dictionary = figures[i]
		txt += "  %d: fig%d value %d %s\n" % [i + 1, i + 1, int(g["value"]), "(placed)" if bool(g["placed"]) else ""]
	txt += "\nTime %.0fs  Typos %d  Sora sniped: %s\n" % [maxf(time_left, 0.0), typos, "YES — find it" if GameState.sora_sniped else "no"]
	txt += "File clean = PIP safe. Bad number surviving = PIP up."
	_view.text = txt

func _grade() -> void:
	# Empty slots = fail. Bad number surviving = sloppy at best, PIP hit.
	var bad_survived := false
	var empty := 0
	for i in pack_slots.size():
		var pi := int(pack_slots[i])
		if pi == -1:
			empty += 1
		elif bool((figures[pi] as Dictionary)["bad"]):
			bad_survived = true
	if empty > 0:
		complete("fail")
	elif bad_survived:
		complete("sloppy")
	elif typos > 1:
		complete("sloppy")
	else:
		complete("clean")
