class_name GameOverScreen
extends CanvasLayer
## End of a run: what happened and how long Jonaid lasted.

signal again_pressed
signal title_pressed

const HEADLINES := {
	"meltdown": ["JONAID HAS LEFT THE BUILDING", "(emotionally. And then physically, through the copier.)"],
	"hana": ["HANA HAS LEFT", "She took the kids. She took the rice cooker. The rice cooker hurts most."],
}

var _title: Label
var _sub: Label
var _stats: Label
var _again: Button


func _ready() -> void:
	layer = 32
	var root := UiStyle.root_control(self)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.06, 0.1, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	_title = UiStyle.loud_label("", 60, UiStyle.RED, 12)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_sub = UiStyle.loud_label("", 22, UiStyle.PAPER, 5)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_sub)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(panel)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 22)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_stats)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_again = Button.new()
	_again.text = "Clock in again"
	_again.pressed.connect(func() -> void: again_pressed.emit())
	row.add_child(_again)
	var t := Button.new()
	t.text = "Title"
	t.pressed.connect(func() -> void: title_pressed.emit())
	row.add_child(t)
	visible = false


func open(cause: String) -> void:
	var h: Array = HEADLINES.get(cause, ["GAME OVER", ""])
	_title.text = h[0]
	_sub.text = h[1]
	var s := Game.stats
	var days := int(s.get("days", 0))
	_stats.text = "Days survived: %d\nMoney earned: %s\nSmoke breaks: %d\nTrains missed: %d\n\nBest: %d day%s" % [
		days, Game.won(int(s.get("earned", 0))), int(s.get("smokes", 0)), int(s.get("trains_missed", 0)),
		Game.best_days, "" if Game.best_days == 1 else "s"]
	visible = true
	_again.grab_focus.call_deferred()
