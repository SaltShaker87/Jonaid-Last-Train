extends Node
## Game time. `minutes` counts game-minutes since midnight of the current day
## (it can run past 24*60 on a very bad night). The current location sets
## `rate`; home sets it to 0. All clock tuning lives here (see DESIGN.md).

signal minute_passed(minute: int)
signal day_started(day: int)

const DAY_START := 9 * 60
const WORK_END := 18 * 60
const RATE_OFFICE := 0.75  ## game-min per real second: 09:00 -> 18:00 in 12 real minutes
const RATE_COMMUTE := 0.5
const WEEKDAYS := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

## Subway departures from the station. Sparse on purpose: missing one hurts.
const TRAINS := [18 * 60 + 30, 19 * 60 + 15, 20 * 60, 21 * 60, 22 * 60 + 15, 23 * 60 + 10]

var day := 1
var minutes := float(DAY_START)
var rate := 0.0
var running := false


func start_day(d: int) -> void:
	day = d
	minutes = float(DAY_START)
	running = true
	day_started.emit(day)
	minute_passed.emit(int(minutes))


func _process(delta: float) -> void:
	if not running or rate <= 0.0:
		return
	advance(rate * delta)


func advance(game_minutes: float) -> void:
	var before := int(minutes)
	minutes += game_minutes
	if int(minutes) != before:
		minute_passed.emit(int(minutes))


func weekday_name() -> String:
	return WEEKDAYS[(day - 1) % 7]


func now_string() -> String:
	return format(minutes)


static func format(m: float) -> String:
	var t := int(m) % (24 * 60)
	return "%02d:%02d" % [t / 60, t % 60]


## Next scheduled train at or after `after`, or -1 when the last one has gone.
static func next_train(after: float) -> int:
	for t in TRAINS:
		if t >= int(after):
			return t
	return -1


static func is_last_train(t: int) -> bool:
	return t == TRAINS[TRAINS.size() - 1]
