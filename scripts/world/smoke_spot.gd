class_name SmokeSpot
extends Interactable
## The balcony ashtray. Smoking drains stress while the clock (and every task
## deadline) keeps running. Move or press E to stub it out. The longer it
## lasts, the more likely Park comes out to look (see office.gd).

const RELIEF_PER_SECOND := 3.0
const LINES := [
	"Ahh. The only meeting I enjoy.",
	"Just one. Okay, this is the third one.",
	"If I stand very still, maybe Park forgets I exist.",
	"Fourteen floors up. The air is worse up here. Perfect.",
]

var smoker: Player
var smoking_time := 0.0


func _on_used(by: Node) -> void:
	if smoker != null or not (by is Player):
		return
	smoker = by as Player
	smoking_time = 0.0
	enabled = false
	Game.bump("smokes")
	smoker.begin_action("Smoke", _stop)
	Game.say(smoker, LINES[randi() % LINES.size()])


func _process(delta: float) -> void:
	if smoker != null:
		smoking_time += delta
		Stress.relieve(RELIEF_PER_SECOND * delta)


func _stop() -> void:
	smoker = null
	smoking_time = 0.0
	enabled = true
