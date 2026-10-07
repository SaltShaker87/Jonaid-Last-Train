extends CanvasLayer
class_name PhoneUI
## KakaoTalk, taxi, nanny, clock (GDD §5, §10).
## Opening it does not pause the day.

var open := false
var _panel: PanelContainer
var _log: Label
var _kakao: KakaoSkill

static func create(kakao: KakaoSkill) -> PhoneUI:
	var p := PhoneUI.new()
	p.name = "Phone"
	p._kakao = kakao
	p.layer = 30
	return p

func _ready() -> void:
	visible = false
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.position = Vector2(-420, -260)
	_panel.size = Vector2(380, 520)
	_panel.add_theme_stylebox_override("panel", _style())
	add_child(_panel)
	var vb := VBoxContainer.new()
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "PHONE — clock keeps running"
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)
	_log = Label.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.text = _home_text()
	vb.add_child(_log)
	var hint := Label.new()
	hint.text = "[1] KakaoTalk  [2] Taxi ₩42,000  [3] Nanny ₩280,000/wk  [Q] close"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)

func _style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.09, 0.10, 0.97)
	s.border_color = Color(0.85, 0.66, 0.25)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func toggle() -> void:
	open = not open
	visible = open
	if open:
		_log.text = _home_text()

func _home_text() -> String:
	var txt := "Clock %s  Stress %d\n" % [DayClock.clock_string(), int(StressSys.value)]
	txt += "Next: shuttle %s · family %s · last %s\n\n" % [_c("shuttle"), _c("family_train"), _c("last_train")]
	txt += "Kakao: Park sent a sticker. Hana: shuttle moved up?\n"
	txt += "Taxi from wrong side of turnstile: ₩42,000, home 00:40, office smell.\n"
	txt += "Nanny: hire by phone, then you SEE her. Jealousy is Hana not turning.\n"
	txt += "Wallet ₩%d · Nanny days %d\n" % [GameState.money, GameState.nanny_days]
	return txt

func _c(ev: String) -> String:
	var m := DayClock.seconds_to_hard(ev)
	if m < -0.5:
		return "gone"
	return "in %dmin" % int(maxf(m, 0.0))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("phone"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not open:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_1:
			_open_kakao()
		elif k.keycode == KEY_2:
			_call_taxi()
		elif k.keycode == KEY_3:
			_hire_nanny()

func _open_kakao() -> void:
	# Kakao overlay runs WITHOUT freezing the clock (GDD §7 phone clock runs).
	visible = false
	open = false
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("open_skill_no_freeze"):
		game.call("open_skill_no_freeze", "kakao", null)

func _call_taxi() -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("call_taxi"):
		game.call("call_taxi")
	_log.text = _home_text()

func _hire_nanny() -> void:
	if GameState.money < GameState.NANNY_WEEK:
		_log.text = "Nanny ₩280,000/week — not enough. Overtime pays next Friday.\n\n" + _home_text()
		return
	if GameState.nanny_days > 0:
		_log.text = "Nanny already hired this week. She paths the evening routine.\n\n" + _home_text()
		return
	GameState.spend(GameState.NANNY_WEEK)
	GameState.nanny_days = 5
	GameState.add_kids(12.0)
	GameState.add_jealousy(18.0)
	GameState.add_hana(-6.0)
	GameState.toast.emit("Nanny hired. Kids stabilize. Hana: you hired someone so you could stay at the office.")
	_log.text = _home_text()
