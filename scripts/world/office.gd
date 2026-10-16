extends Location
## Hansung Electronics, 14th floor. Park sits in his glass box handing out
## tasks (Tasks autoload), walks out to the balcony to catch Jonaid smoking,
## and goes home some time after 19:00. Director Choi shows up in the
## meeting room whenever there's someone who needs to bow to him.

## Walkways around the desks (Godot space). See blender/build_world.py.
const CHAIR := Vector3(-8.5, 0.08, -7.55)
const OUT_OF_BOX := [Vector3(-10.3, 0, -7.55), Vector3(-10.3, 0, -4.6), Vector3(-6.75, 0, -3.7), Vector3(-6.75, 0, -1.95)]
const TO_BALCONY := [Vector3(2.9, 0, -1.95), Vector3(2.9, 0, -8.6), Vector3(3.6, 0, -10.2)]
const TO_ELEVATOR := [Vector3(-9.5, 0, -1.95), Vector3(-9.5, 0, 6.6), Vector3(-8.0, 0, 7.9)]

const CATCH_LINES := [
	"Smoking AGAIN? Lungs are company property. Here, have a task.",
	"Fresh air, Jonaid? I'll give you something FRESH. A deadline.",
	"Ah, a break! Breaks are for KitKats. Get back in there.",
]
const MISSED_LINES := [
	"Hm. I smelled freedom out here. Must have been the wind.",
	"Nobody? I could have sworn someone was relaxing.",
]
const LEAVE_LINES := [
	"I'm going home. Don't stay too late. (Stay late.)",
	"Good night, team. Remember: nobody leaves before they're DONE.",
]

var _park_busy := false
var _caught_cd := 0.0

@onready var park: NPC = $NPCs/Park
@onready var choi: NPC = $NPCs/Choi
@onready var ashtray: SmokeSpot = $Interactables/Ashtray


func _ready() -> void:
	super._ready()
	Clock.minute_passed.connect(_on_minute)
	Tasks.park_leaving.connect(_on_park_leaving)
	Tasks.park = park
	park.visible = Tasks.park_present or not Game.in_run
	choi.visible = false
	choi.play("Idle")


func on_enter(_player: Node3D) -> void:
	Tasks.enter_office()


func _exit_tree() -> void:
	if Tasks.park == park:
		Tasks.park = null


func _process(delta: float) -> void:
	if not Game.in_run:
		return
	choi.visible = Tasks.has_game("bow")
	_caught_cd = maxf(0.0, _caught_cd - delta)
	# Park notices a long smoke break and comes to see.
	if ashtray.smoker != null and ashtray.smoking_time > 6.0 and not _park_busy and Tasks.park_present and _caught_cd <= 0.0:
		var chance := 0.07 * (1.0 + 0.35 * float(Clock.day - 1))
		if randf() < chance * delta:
			_park_patrol()


func _on_minute(m: int) -> void:
	if m == Clock.WORK_END and Game.in_run:
		Game.notify("18:00. Officially done for the day. Park is still at his desk...")


func _park_patrol() -> void:
	_park_busy = true
	_caught_cd = 40.0
	Tasks.park_says("...Is that SMOKE I smell?")
	park.position.y = 0.0
	await park.walk_path(OUT_OF_BOX + TO_BALCONY, 3.0)
	if not is_inside_tree():
		return
	var smoker := ashtray.smoker
	if smoker != null:
		park.play("Angry")
		smoker.cancel_action()
		Stress.add(5.0)
		Tasks.spawn(CATCH_LINES[randi() % CATCH_LINES.size()])
	else:
		park.play("Talk")
		Tasks.park_says(MISSED_LINES[randi() % MISSED_LINES.size()])
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return
	var back: Array = TO_BALCONY.duplicate()
	back.reverse()
	var out: Array = OUT_OF_BOX.duplicate()
	out.reverse()
	await park.walk_path(back.slice(1) + out, 2.6)
	if not is_inside_tree():
		return
	_sit_park()
	_park_busy = false
	if not Tasks.park_present:
		_on_park_leaving()


func _sit_park() -> void:
	park.global_position = CHAIR
	park.rotation.y = 0.0
	park.play("SitType")


func _on_park_leaving() -> void:
	if _park_busy:
		return  # he'll leave once he's back from the balcony
	_park_busy = true
	Tasks.park_says(LEAVE_LINES[randi() % LEAVE_LINES.size()])
	Game.notify("Park has gone home. You're free. (Are you?)")
	park.position.y = 0.0
	await park.walk_path(OUT_OF_BOX + TO_ELEVATOR, 2.4)
	if is_inside_tree():
		park.visible = false
