extends Area3D
class_name Interactable
## Interactable base — GDD §5, §17.
## Every interactable declares a weight. Player learns weight from prompt color.
## Errand=white, Manual=gold, Heavy=oxblood.

signal activated(inter: Interactable)

enum Weight { ERRAND, MANUAL, HEAVY }

@export var weight: int = Weight.ERRAND
@export var prompt_text: String = "Interact"
@export var job_id: String = ""
@export var skill_id: String = ""   # trace, bow, digits, slides, pour, kakao, dash, none=instant
@export var one_shot: bool = false
@export var disabled: bool = false

var _used := false

func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = true
	# Ensure a collision shape exists for the ray/area query.
	if get_node_or_null("PromptShape") == null:
		var s := CollisionShape3D.new()
		s.name = "PromptShape"
		var sphere := SphereShape3D.new()
		sphere.radius = 2.2
		s.shape = sphere
		add_child(s)

func prompt_color() -> Color:
	match weight:
		Weight.ERRAND:
			return Color(0.96, 0.95, 0.92)  # white
		Weight.MANUAL:
			return Color(0.85, 0.66, 0.25)  # gold
		_:
			return Color(0.45, 0.08, 0.10)  # oxblood
	return Color.WHITE

func weight_name() -> String:
	match weight:
		Weight.ERRAND: return "ERRAND"
		Weight.MANUAL: return "MANUAL"
		_: return "HEAVY"

func full_prompt() -> String:
	return "[%s] %s" % [weight_name(), prompt_text]

func can_use() -> bool:
	if disabled:
		return false
	if one_shot and _used:
		return false
	return true

func activate() -> void:
	if not can_use():
		return
	_used = true
	activated.emit(self)
