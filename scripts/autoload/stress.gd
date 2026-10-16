extends Node
## Jonaid's stress, 0..100. Hitting 100 is a meltdown (game over).

signal changed(value: float, delta: float)
signal maxed

const MAX := 100.0
const BANDS := ["Calm", "Tense", "Frazzled", "About to snap"]

var value := 0.0
var _maxed := false


func reset(v: float = 0.0) -> void:
	value = clampf(v, 0.0, MAX)
	_maxed = false
	changed.emit(value, 0.0)


func add(amount: float) -> void:
	_apply(value + amount)


func relieve(amount: float) -> void:
	_apply(value - amount)


func band() -> int:
	if value < 30.0:
		return 0
	if value < 60.0:
		return 1
	if value < 85.0:
		return 2
	return 3


func band_name() -> String:
	return BANDS[band()]


func _apply(v: float) -> void:
	var before := value
	value = clampf(v, 0.0, MAX)
	if is_equal_approx(before, value):
		return
	changed.emit(value, value - before)
	if value >= MAX and not _maxed:
		_maxed = true
		maxed.emit()
