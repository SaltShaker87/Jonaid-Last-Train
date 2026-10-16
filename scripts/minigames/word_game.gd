class_name WordGame
extends Minigame
## Retype Park's stupid sentence exactly. Typos stay red until fixed with
## Backspace. High stress makes Jonaid's fingers slip onto neighbouring keys.

const NEIGHBOURS := {
	"a": "sq", "b": "vn", "c": "xv", "d": "sf", "e": "wr", "f": "dg", "g": "fh", "h": "gj", "i": "uo",
	"j": "hk", "k": "jl", "l": "k;", "m": "n,", "n": "bm", "o": "ip", "p": "o[", "q": "wa", "r": "et",
	"s": "ad", "t": "ry", "u": "yi", "v": "cb", "w": "qe", "x": "zc", "y": "tu", "z": "x",
}

var target := ""
var typed := ""
var mistakes := 0
var _view: RichTextLabel


func app_title() -> String:
	return "Wurd 2026  —  Park_email_FINAL_final2.docx"


func _build() -> void:
	target = String(params.get("text", "Please do the thing."))
	time_limit = 7.0 + target.length() * lerpf(0.42, 0.3, difficulty)
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", UiStyle.panel(Color.WHITE, 6, 2, 22))
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(page)
	_view = RichTextLabel.new()
	_view.bbcode_enabled = true
	_view.fit_content = true
	_view.scroll_active = false
	_view.add_theme_font_size_override("normal_font_size", 28)
	_view.add_theme_font_size_override("bold_font_size", 28)
	_view.add_theme_font_override("normal_font", UiStyle.font(600))
	_view.add_theme_font_override("bold_font", UiStyle.font(800))
	page.add_child(_view)
	hint.text = "Type it exactly · Backspace fixes typos"
	_render()


func _key(e: InputEventKey) -> void:
	if e.keycode == KEY_BACKSPACE:
		if typed.length() > 0:
			typed = typed.left(typed.length() - 1)
	elif e.unicode >= 32 and typed.length() < target.length():
		var ch := char(e.unicode)
		# Shaky hands: above 40 stress some keys land next door.
		var slip := maxf(0.0, Stress.value - 40.0) / 220.0
		if randf() < slip and NEIGHBOURS.has(ch.to_lower()):
			var n: String = NEIGHBOURS[ch.to_lower()]
			ch = n[randi() % n.length()]
			hint.text = "Your hands are shaking."
		if ch.to_lower() != target[typed.length()].to_lower():
			mistakes += 1
		typed += ch
	_render()
	if typed.length() == target.length() and _all_correct():
		finish(grade_for(mistakes))


func _all_correct() -> bool:
	return typed.to_lower() == target.to_lower()


func _render() -> void:
	var out := ""
	for i in target.length():
		var t := target[i]
		if i < typed.length():
			if typed[i].to_lower() == t.to_lower():
				out += "[color=#1d1a24]%s[/color]" % _esc(t)
			else:
				var shown := typed[i] if typed[i] != " " else "_"
				out += "[bgcolor=#ffd0d6][color=#e2475f][b]%s[/b][/color][/bgcolor]" % _esc(shown)
		elif i == typed.length():
			out += "[bgcolor=#ffd34d][color=#1d1a24]%s[/color][/bgcolor]" % _esc(t if t != " " else " ")
		else:
			out += "[color=#b8b0c4]%s[/color]" % _esc(t)
	_view.text = out


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")
