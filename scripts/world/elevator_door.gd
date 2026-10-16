class_name ElevatorDoor
extends Door
## The office elevator. Before 18:00 Jonaid doesn't dare. After 18:00 he can
## go, but leaving while Park is still at his desk (nunchi) costs stress and
## a personal task first thing tomorrow.

const TOO_EARLY := [
	"It's not even six. Park would notice. Park always notices.",
	"Leaving before 18:00? In THIS economy?",
	"The elevator can smell fear. And unfinished work.",
]
const NUNCHI_PARK := [
	"...Going home ALREADY?",
	"Oh, leaving? Must be nice. Must be REAL nice.",
	"Hm. See you tomorrow. EARLY tomorrow.",
]
const NUNCHI_STRESS := 12.0


func _on_used(by: Node) -> void:
	if Clock.minutes < Clock.WORK_END:
		Game.say(by as Node3D, TOO_EARLY[randi() % TOO_EARLY.size()])
		return
	if Tasks.park_present and Game.in_run:
		Stress.add(NUNCHI_STRESS)
		Tasks.owed += 1
		if is_instance_valid(Tasks.park):
			Game.say(Tasks.park, NUNCHI_PARK[randi() % NUNCHI_PARK.size()], 4.0)  # immediate: he's watching you go
		Game.notify("You left before Park. He saw. He will remember.")
	super._on_used(by)
