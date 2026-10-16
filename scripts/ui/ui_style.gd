class_name UiStyle
extends RefCounted
## One place for the cartoon UI look: chunky rounded panels with dark
## outlines, a bold rounded system font (Hangul falls back to the system).

const INK := Color("1d1a24")
const PAPER := Color("fff8e7")
const YELLOW := Color("ffd34d")
const RED := Color("e2475f")
const TEAL := Color("4fae9f")
const DIM := Color("6b6475")

static var _theme: Theme
static var _fonts := {}


static func font(weight: int = 800) -> Font:
	if not _fonts.has(weight):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Segoe UI", "Malgun Gothic", "Noto Sans CJK KR", "Helvetica"])
		f.font_weight = weight
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_fonts[weight] = f
	return _fonts[weight]


static func panel(bg: Color = PAPER, radius: int = 14, border: int = 3, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = INK
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 4)
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 20
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", panel())
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := PAPER
		if state == "hover" or state == "focus":
			bg = YELLOW
		elif state == "pressed":
			bg = Color("ffb23d")
		var sb := panel(bg, 16, 3, 14)
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		t.set_stylebox(state, "Button", sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_font_size("font_size", "Button", 24)
	_theme = t
	return t


## A label with a thick dark outline, readable over any 3D background.
static func loud_label(text: String, size: int, color: Color = PAPER, outline: int = 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", outline)
	return l


static func root_control(layer: CanvasLayer) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.theme = theme()
	layer.add_child(c)
	return c
