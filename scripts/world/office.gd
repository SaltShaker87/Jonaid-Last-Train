extends Location
## Hansung Electronics, 14th floor. Phase 2 adds Park's task queue here.

const PARK_GRUMBLES := [
	"JONAID! ...Nothing. Just checking you're scared.",
	"Is that a SMILE? Wipe it off. We're behind.",
	"In my day we didn't have chairs. We had GRATITUDE.",
	"Why is the printer making that noise? Fix it. With your FACE.",
]

var _grumble_cd := 20.0

@onready var park: NPC = $NPCs/Park


func _ready() -> void:
	super._ready()
	Clock.minute_passed.connect(_on_minute)


func _process(delta: float) -> void:
	# Phase 1 stand-in for the task system: Park yells across the floor.
	if not Game.in_run:
		return
	_grumble_cd -= delta
	if _grumble_cd <= 0.0:
		_grumble_cd = randf_range(35.0, 60.0)
		Game.say(park, PARK_GRUMBLES[randi() % PARK_GRUMBLES.size()], 4.0)


func _on_minute(m: int) -> void:
	if m == Clock.WORK_END:
		Game.notify("18:00. Officially done for the day. Park is still at his desk...")
