extends SkillBase
class_name KakaoSkill
## Kit: KakaoTalk manual (GDD §10). Three-reply window, or type the short one.
## Stress adds a typo you must clear before send. Building clock RUNS (no freeze).

var thread: Array = []  # outgoing drafts
var needed: int = 3
var typed: String = ""
var has_typo: bool = false
var _had_typo := false
var _info: Label
var _view: Label
var _edit: LineEdit

static func create() -> KakaoSkill:
	var s := KakaoSkill.new()
	s.name = "KakaoSkill"
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.is_heavy = false
	return s

func _ready() -> void:
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.07, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_info = Label.new()
	_info.position = Vector2(24, 12)
	_info.size = Vector2(1200, 40)
	_info.text = "KakaoTalk — clock keeps running while you type."
	add_child(_info)
	_view = Label.new()
	_view.position = Vector2(24, 56)
	_view.size = Vector2(1200, 380)
	add_child(_view)
	_edit = LineEdit.new()
	_edit.position = Vector2(24, 450)
	_edit.size = Vector2(900, 40)
	_edit.placeholder_text = "Type reply, Enter to send (3 needed). Fix typos first."
	add_child(_edit)
	_edit.text_submitted.connect(_on_submit)

func start(p_stress: float, p_seed: int) -> void:
	super.start(p_stress, p_seed)
	thread.clear()
	typed = ""
	has_typo = false
	if _edit != null:
		_edit.text = ""
		_edit.grab_focus()
	_refresh()

func _refresh() -> void:
	if _view == null:
		return
	var txt := "Park: sticker unread. Hana: shuttle moved up? Sora: numbers?\n\nSent %d/%d:\n" % [thread.size(), needed]
	for t in thread:
		txt += "  you: %s\n" % t
	if has_typo:
		txt += "\n[TYPO — clear it: retype and send]"
	_view.text = txt

func _on_submit(text: String) -> void:
	if _done:
		return
	if text.strip_edges() == "":
		return
	# Stress typo injection.
	if StressSys.band() >= StressSys.Band.WARM and randf() < 0.3 and not has_typo:
		has_typo = true
		_refresh()
		_info.text = "Typo inserted by shaking hands — send again to clear it."
		if _edit != null:
			_edit.text = ""
		return
	if has_typo:
		has_typo = false
		_had_typo = true
		thread.append(text + " (fixed)")
	else:
		thread.append(text)
	if _edit != null:
		_edit.text = ""
	_refresh()
	if thread.size() >= needed:
		complete("sloppy" if _had_typo else "clean")
