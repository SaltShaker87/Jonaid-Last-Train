class_name ElevatorDoor
extends Door
## The office elevator. Before 18:00 Jonaid doesn't dare.

const TOO_EARLY := [
	"It's not even six. Park would notice. Park always notices.",
	"Leaving before 18:00? In THIS economy?",
	"The elevator can smell fear. And unfinished work.",
]


func _on_used(by: Node) -> void:
	if Clock.minutes < Clock.WORK_END:
		Game.say(by as Node3D, TOO_EARLY[randi() % TOO_EARLY.size()])
		return
	super._on_used(by)
