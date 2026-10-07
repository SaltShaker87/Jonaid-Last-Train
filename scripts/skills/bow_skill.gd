extends SkillBase
class_name HoldSkill
## Kit: hold-zone. Covers bow, beer pour, filter prime (GDD §10).
## Hold the angle / flow in the sweet spot. Stress halves the sweet spot.
## Carry items make bow worse.

var title: String = "BOW"
var hold_time := 3.0
var need := 2.2  # seconds inside zone to win
var _inside := 0.0
var _total := 0.0
var _marker := 0.5  # 0..1
var _vel := 0.0
var _sweet_center := 0.5
var _sweet_half := 0.18
var _bar: Control
var _info: Label
var carry_penalty := false

static func create(p_title: String) -> HoldSkill:
	var s := HoldSkill.new()
	s.name = "HoldSkill_" + p_title
	s.title = p_title
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.is_heavy = false
	if p_title == "BOW":
		s.is_heavy = false  # manual per GDD
	return s

func _ready() -> void:
	visible = false
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.06, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_info = Label.new()
	_info.position = Vector2(24, 16)
	_info.size = Vector2(1200, 60)
	add_child(_info)
	_bar = HoldBar.new()
	_bar.skill = self
	_bar.position = Vector2(140, 220)
	_bar.size = Vector2(1000, 120)
	add_child(_bar)
	var hint := Label.new()
	hint.text = "Hold SPACE (or mouse button) to raise the marker. Release to let it fall. Keep it in the gold zone. Enter to finish early."
	hint.position = Vector2(24, 380)
	hint.size = Vector2(1200, 30)
	add_child(hint)

func start(p_stress: float, p_seed: int) -> void:
	super.start(p_stress, p_seed)
	_inside = 0.0
	_total = 0.0
	_marker = 0.5
	_vel = 0.0
	var scale := stress_scale()
	_sweet_half = 0.18 * scale
	if carry_penalty:
		_sweet_half *= 0.7
	_sweet_center = 0.45 + float(p_seed % 20) / 100.0
	_info.text = "%s — hold %.1fs in the zone. Stress %d (%s)%s" % [title, need, int(p_stress), StressSys.band_name(), " +CARRY penalty" if carry_penalty else ""]
	queue_redraw()

func _process(delta: float) -> void:
	if not visible or _done:
		return
	_total += delta
	var holding := Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	# Drift + noise
	var n := noise_px() * 0.004
	_vel += (0.55 if holding else -0.55) * delta
	_vel = clampf(_vel, -0.8, 0.8)
	_marker += _vel * delta + randf_range(-n, n)
	_marker = clampf(_marker, 0.0, 1.0)
	if absf(_marker - _sweet_center) <= _sweet_half:
		_inside += delta
	if _bar != null:
		_bar.queue_redraw()
	if _inside >= need:
		complete("clean")
	elif _total >= hold_time + 6.0:
		complete("sloppy" if _inside >= need * 0.5 else "fail")

func _input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_ENTER:
			if _inside >= need:
				complete("clean")
			elif _inside >= need * 0.5:
				complete("sloppy")
			else:
				complete("fail")


class HoldBar extends Control:
	var skill: HoldSkill
	func _draw() -> void:
		if skill == null:
			return
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.13, 0.12), true)
		var cx := skill._sweet_center * w
		var hw := skill._sweet_half * w
		draw_rect(Rect2(Vector2(cx - hw, 0), Vector2(hw * 2, h)), Color(0.85, 0.66, 0.25, 0.85), true)
		var mx := skill._marker * w
		draw_rect(Rect2(Vector2(mx - 4, -6), Vector2(8, h + 12)), Color(0.95, 0.93, 0.88), true)
