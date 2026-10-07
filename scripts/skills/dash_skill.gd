extends SkillBase
class_name DashSkill
## Kit: path-dash fallback overlay for platform / crowd (GDD §10 Last train).
## The real skill is the path in Station; this overlay is used if the player
## triggers the dash from the turnstile with high stress, or for testing.
## Clean line if left at 22:50 and stress < 60. Stumble costs the door at 80+.

var lanes := 3
var steps := 12
var pos := 1
var step := 0
var stumbles := 0
var _info: Label
var _view: Label

static func create() -> DashSkill:
	var s := DashSkill.new()
	s.name = "DashSkill"
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.is_heavy = true
	return s

func _ready() -> void:
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.09, 0.10, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_info = Label.new()
	_info.position = Vector2(24, 12)
	_info.size = Vector2(1200, 40)
	add_child(_info)
	_view = Label.new()
	_view.position = Vector2(24, 60)
	_view.size = Vector2(1200, 500)
	_view.add_theme_font_size_override("font_size", 26)
	add_child(_view)

func start(p_stress: float, p_seed: int) -> void:
	super.start(p_stress, p_seed)
	pos = 1
	step = 0
	stumbles = 0
	_info.text = "PLATFORM DASH — A/D move lane, W or Enter step forward. Don't cut corners at 80+ stress."
	_refresh()

func _input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_A:
			_move_lane(-1)
		elif k.keycode == KEY_D:
			_move_lane(1)
		elif k.keycode == KEY_W or k.keycode == KEY_ENTER:
			_step()

func _move_lane(d: int) -> void:
	# Cutting two lanes at once at high stress = stumble (GDD §8).
	pos = clampi(pos + d, 0, lanes - 1)
	_refresh()

func _step() -> void:
	step += 1
	# Corner-cut stumble check.
	if StressSys.value >= 80.0 and randf() < 0.25:
		stumbles += 1
	elif StressSys.value >= 61.0 and randf() < 0.10:
		stumbles += 1
	if step >= steps:
		if stumbles == 0:
			complete("clean")
		elif stumbles <= 1:
			complete("sloppy")
		else:
			complete("fail")
		return
	_refresh()

func _refresh() -> void:
	if _view == null:
		return
	var txt := "Step %d/%d  Stumbles %d  Stress %d\n\n" % [step, steps, stumbles, int(StressSys.value)]
	for r in range(steps - step):
		var line := ""
		for c in lanes:
			line += "[J]" if (r == 0 and c == pos) else "[ ]"
		txt += line + "\n"
	txt += "\nDoors shut on their own clock. Taxi only after the doors shut."
	_view.text = txt
