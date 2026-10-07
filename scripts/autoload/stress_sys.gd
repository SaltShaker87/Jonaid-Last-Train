extends Node
## StressSys autoload — GDD §8.
## Stress 0..100 with a hand. Errands ignore it until 90.
## Manuals use it as window modifier. Heavies use it as opponent.
## Bands exported to every skill scene as window scale, lag, noise, forced-error.

signal stress_changed(value: float)

var value: float = 20.0  # Tuesday starts warm from briefing

enum Band { STEADY, WARM, SHAKE, BORROWED }

func set_stress(v: float) -> void:
	value = clampf(v, 0.0, 100.0)
	stress_changed.emit(value)

func add(v: float) -> void:
	set_stress(value + v)

func relieve(v: float) -> void:
	set_stress(value - v)

func band() -> int:
	if value <= 30.0:
		return Band.STEADY
	if value <= 60.0:
		return Band.WARM
	if value <= 80.0:
		return Band.SHAKE
	return Band.BORROWED

func band_name() -> String:
	match band():
		Band.STEADY: return "steady"
		Band.WARM: return "warm"
		Band.SHAKE: return "shake"
		_: return "borrowed"

## Window scale for manual/heavy sweet spots (1.0 = nominal).
func window_scale(is_heavy: bool) -> float:
	match band():
		Band.STEADY: return 1.0
		Band.WARM: return 0.85
		Band.SHAKE:
			return 0.5 if is_heavy else 0.75
		_:
			return 0.45 if is_heavy else 0.65

## Hand noise amplitude in pixels (trace) / degrees (bow).
func noise_amplitude() -> float:
	match band():
		Band.STEADY: return 0.0
		Band.WARM: return 2.0
		Band.SHAKE: return 6.0
		_: return 12.0

## Simulated input lag in frames.
func lag_frames() -> int:
	match band():
		Band.STEADY: return 0
		Band.WARM: return 1
		Band.SHAKE: return 3
		_: return 5

func has_forced_error() -> bool:
	return value >= 81.0

func can_sprint(body: float) -> bool:
	# No sprint until stress is low and Body is high (GDD §5).
	return value < 40.0 and body >= 60.0

func spill_carry_on_stairs() -> bool:
	return value >= 90.0
