class_name SmokeSpot
extends Interactable
## The balcony ashtray. Smoking drains stress while the clock (and every task
## deadline) keeps running. Move or press E to stub it out.

const RELIEF_PER_SECOND := 3.0
const LINES := [
	"Ahh. The only meeting I enjoy.",
	"Just one. Okay, this is the third one.",
	"If I stand very still, maybe Park forgets I exist.",
	"Fourteen floors up. The air is worse up here. Perfect.",
]

var _smoker: Player


func _on_used(by: Node) -> void:
	if _smoker != null or not (by is Player):
		return
	_smoker = by as Player
	enabled = false
	Game.bump("smokes")
	_smoker.begin_action("Smoke", _stop)
	Game.say(_smoker, LINES[randi() % LINES.size()])


func _process(delta: float) -> void:
	if _smoker != null:
		Stress.relieve(RELIEF_PER_SECOND * delta)


func _stop() -> void:
	_smoker = null
	enabled = true
