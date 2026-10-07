extends SkillBase
class_name DigitsSkill
## Kit: form digits. Covers G90 booking board, signature, whiskey receipt (GDD §10).
## Three slots, a clock, a deposit, numbers that cannot legally close.
## Stress adds a misplaced digit.

var title: String = "BOOKING"
var target_sum: int = 180000
var slots: Array = [0, 0, 0]
var cursor: int = 0
var time_left: float = 60.0
var deposit_risk: int = 600000
var _info: Label
var _grid: Label
var _rng := RandomNumberGenerator.new()
var _typo_injected := false

static func create(p_title: String) -> DigitsSkill:
	var s := DigitsSkill.new()
	s.name = "DigitsSkill_" + p_title
	s.title = p_title
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.is_heavy = true if p_title == "G90" else false
	return s

func _ready() -> void:
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_info = Label.new()
	_info.position = Vector2(24, 16)
	_info.size = Vector2(1200, 80)
	add_child(_info)
	_grid = Label.new()
	_grid.position = Vector2(24, 120)
	_grid.size = Vector2(1200, 400)
	_grid.add_theme_font_size_override("font_size", 28)
	add_child(_grid)

func start(p_stress: float, p_seed: int) -> void:
	super.start(p_stress, p_seed)
	_rng.seed = p_seed * 131 + 7
	cursor = 0
	time_left = 60.0
	_typo_injected = false
	# GDD: budget 180,000 for three black luxury cars — cannot legally close.
	# Performed solutions: convoy story / dim sedan / card signature hole.
	if title == "G90":
		slots = [60000, 60000, 60000]
	else:
		slots = [0, 0, 0]
	_refresh()
	_info.text = "%s — Type digits 0-9, Left/Right to move, Enter to file. Stress %d may misplace a digit." % [title, int(p_stress)]

func _process(delta: float) -> void:
	if not visible or _done:
		return
	time_left -= delta
	if time_left <= 0.0:
		_grade()
	_refresh()

func _input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode >= KEY_0 and k.keycode <= KEY_9:
			var d := int(k.keycode - KEY_0)
			# Stress misplaced digit (GDD: stress adds a misplaced digit).
			if StressSys.band() >= StressSys.Band.SHAKE and randf() < 0.18 and not _typo_injected:
				d = (d + 1) % 10
				_typo_injected = true
				_info.text = "%s — hands slipped! A digit went sideways. Fix it." % title
			slots[cursor] = slots[cursor] * 10 + d
			if slots[cursor] > 999999:
				slots[cursor] = d
			_refresh()
		elif k.keycode == KEY_LEFT:
			cursor = posmod(cursor - 1, 3)
			_refresh()
		elif k.keycode == KEY_RIGHT:
			cursor = posmod(cursor + 1, 3)
			_refresh()
		elif k.keycode == KEY_BACKSPACE:
			slots[cursor] = int(slots[cursor] / 10)
			_refresh()
		elif k.keycode == KEY_ENTER:
			_grade()

func _refresh() -> void:
	if _grid == null:
		return
	var total: int = int(slots[0]) + int(slots[1]) + int(slots[2])
	var txt := ""
	for i in 3:
		var mark := ">" if i == cursor else " "
		txt += "%s SLOT %d: %d won\n" % [mark, i + 1, int(slots[i])]
	txt += "\nTotal: %d / budget %d\nTime: %.0fs\n" % [total, target_sum, maxf(time_left, 0.0)]
	if title == "G90":
		txt += "Convoy story: keep total <= 180,000 with 3 cars, or sign the card (600,000 hole).\n"
	_grid.text = txt

func _grade() -> void:
	var total: int = int(slots[0]) + int(slots[1]) + int(slots[2])
	if title == "G90":
		if total <= target_sum and slots[0] > 0 and slots[1] > 0 and slots[2] > 0:
			complete("clean")   # convoy story told well
		elif total <= target_sum + 60000:
			complete("sloppy")  # dim sedan, survive walkaround
		else:
			complete("fail")    # hole gets deeper
	else:
		complete("clean" if total > 0 else "fail")
