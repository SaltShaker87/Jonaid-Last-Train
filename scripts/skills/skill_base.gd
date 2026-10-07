extends Control
class_name SkillBase
## Skill scene contract — GDD §17.
## start(stress, seed) and finish(grade). Grade clean / sloppy / fail.
## World never ticks inside these scenes (Main sets DayClock.frozen).

signal finished(grade: String)

var stress: float = 20.0
var seed_value: int = 0
var is_heavy: bool = true
var _done := false

func start(p_stress: float, p_seed: int) -> void:
	stress = p_stress
	seed_value = p_seed
	_done = false
	visible = true

func complete(grade: String) -> void:
	if _done:
		return
	_done = true
	visible = false
	finished.emit(grade)

func stress_scale() -> float:
	return StressSys.window_scale(is_heavy)

func noise_px() -> float:
	return StressSys.noise_amplitude()
