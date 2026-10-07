extends CanvasLayer
class_name HUD
## Diegetic-first HUD (GDD §15). Clock + stress on the phone, glanceable.
## Interaction prompts are the only floating type. Weight is color.

var clock_label: Label
var day_label: Label
var stress_bar: ProgressBar
var stress_label: Label
var prompt_label: Label
var board_label: Label
var toast_label: Label
var _toast_t := 0.0

static func create() -> HUD:
	var h := HUD.new()
	h.name = "HUD"
	h.layer = 10
	return h

func _ready() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_top = 10
	top.offset_right = -16
	top.add_theme_constant_override("separation", 24)
	add_child(top)
	day_label = Label.new()
	day_label.add_theme_font_size_override("font_size", 20)
	top.add_child(day_label)
	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 28)
	top.add_child(clock_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	stress_label = Label.new()
	stress_label.text = "STRESS"
	top.add_child(stress_label)
	stress_bar = ProgressBar.new()
	stress_bar.min_value = 0
	stress_bar.max_value = 100
	stress_bar.custom_minimum_size = Vector2(200, 22)
	stress_bar.show_percentage = false
	top.add_child(stress_bar)
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-400, -140)
	prompt_label.size = Vector2(800, 40)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(prompt_label)
	board_label = Label.new()
	board_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	board_label.position = Vector2(-360, 60)
	board_label.size = Vector2(344, 150)
	board_label.add_theme_font_size_override("font_size", 16)
	add_child(board_label)
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.offset_top = -80
	toast_label.add_theme_font_size_override("font_size", 18)
	add_child(toast_label)
	DayClock.time_changed.connect(_on_time)
	StressSys.stress_changed.connect(_on_stress)
	GameState.toast.connect(show_toast)
	GameState.meters_changed.connect(refresh_board)
	_on_time(DayClock.day, DayClock.minutes)
	_on_stress(StressSys.value)
	refresh_board()

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_label.text = ""

func _on_time(day: int, _minutes: float) -> void:
	day_label.text = "Day %d · %s" % [day, DayClock.weekday_name()]
	clock_label.text = DayClock.clock_string()
	refresh_board()

func _on_stress(v: float) -> void:
	stress_bar.value = v
	var c := Color(0.4, 0.8, 0.4)
	if v > 80.0:
		c = Color(0.55, 0.10, 0.12)
	elif v > 60.0:
		c = Color(0.85, 0.55, 0.2)
	elif v > 30.0:
		c = Color(0.85, 0.75, 0.3)
	stress_bar.modulate = c
	stress_label.text = "STRESS %d %s" % [int(v), StressSys.band_name().to_upper()]

func set_prompt(inter: Interactable) -> void:
	if inter == null:
		prompt_label.text = ""
	else:
		prompt_label.text = "[E] " + inter.full_prompt()
		prompt_label.add_theme_color_override("font_color", inter.prompt_color())

func show_toast(t: String) -> void:
	toast_label.text = t
	_toast_t = 4.0

func refresh_board() -> void:
	if board_label == null:
		return
	var shuttle := DayClock.seconds_to_hard("shuttle")
	var fam := DayClock.seconds_to_hard("family_train")
	var last := DayClock.seconds_to_hard("last_train")
	var txt := "NEXT DEPARTURES\n"
	txt += "Shuttle 18:10 %s\n" % _fmt_count(shuttle)
	txt += "Family 19:40 %s\n" % _fmt_count(fam)
	txt += "Last 23:18 %s\n" % _fmt_count(last)
	txt += "₩%s · Face %d · Hana %d" % [_money(GameState.money), int(GameState.face), int(GameState.hana)]
	board_label.text = txt

func _fmt_count(m: float) -> String:
	if m < -0.5:
		return "(gone)"
	if m < 0.5:
		return "(NOW)"
	return "(in %dmin)" % int(m)

func _money(v: int) -> String:
	var s := str(abs(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out
