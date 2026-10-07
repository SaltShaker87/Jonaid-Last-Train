extends Node
## DayClock autoload — GDD §7, §17.
## The day is accelerated real time during navigation, billed time during skills.
## Scale while in world: 1 real second = 20 game seconds.
## Frozen during a skill scene. Billed minutes applied on skill exit.
## Only the system menu pauses. The phone is not a pause.

signal time_changed(day: int, minutes: float)
signal hard_event(event_id: String)

const REAL_TO_GAME := 20.0 / 60.0  # game-minutes per real second (20 game-sec = 0.333 game-min)
const DAY_START_MIN := 8 * 60 + 50  # 08:50 Tuesday briefing
const CLEAN_BILL := 20
const SLOPPY_BILL := 45
const FAIL_BILL := 30

var day: int = 1               # 1..60, Mon..Fri building, Sat short
var weekday: int = 1           # 0=Mon .. 6=Sun ; start Tuesday=1
var minutes: float = DAY_START_MIN
var frozen: bool = false
var running: bool = false
var _fired_events: Dictionary = {}

const WEEKDAYS := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

# Hard clocks in game-minutes (GDD §7)
func hard_clocks_for_day() -> Dictionary:
	var d := {}
	# weekday: 3 = Thu hoesik, else normal
	d["shuttle"] = 18 * 60 + 10
	d["family_train"] = 19 * 60 + 40
	d["last_train"] = 23 * 60 + 18
	d["first_train_next"] = 5 * 60 + 12
	if weekday == 3:
		d["hoesik"] = 19 * 60
	if weekday == 4:  # Friday PIP reads file at 18:00
		d["pip_review"] = 18 * 60
	return d

func start_day(p_day: int, p_weekday: int, start_min: float = DAY_START_MIN) -> void:
	day = p_day
	weekday = p_weekday
	minutes = start_min
	_fired_events.clear()
	running = true
	frozen = false
	time_changed.emit(day, minutes)

func _process(delta: float) -> void:
	if not running or frozen:
		return
	if get_tree().paused:
		return
	minutes += delta * REAL_TO_GAME
	_check_hard_events()
	time_changed.emit(day, minutes)
	# Past 24:00 rolls to next morning context (station board flips to 05:12).
	if minutes >= 24 * 60 + 40:  # taxi home at 00:40 cap
		running = false  # Main.gd resolves night outcome

func _check_hard_events() -> void:
	var clocks := hard_clocks_for_day()
	for k in clocks.keys():
		var t: float = clocks[k]
		if minutes >= t and not _fired_events.get(k, false):
			_fired_events[k] = true
			hard_event.emit(k)

func add_minutes(m: float) -> void:
	minutes += m
	_check_hard_events()
	time_changed.emit(day, minutes)

func bill_skill(grade: String) -> int:
	var billed := FAIL_BILL
	if grade == "clean":
		billed = CLEAN_BILL
	elif grade == "sloppy":
		billed = SLOPPY_BILL
	add_minutes(billed)
	return billed

func clock_string() -> String:
	var m := int(minutes) % (24 * 60)
	var h := int(m / 60)
	var mm := m % 60
	return "%02d:%02d" % [h, mm]

func weekday_name() -> String:
	return WEEKDAYS[weekday % 7]

func is_night() -> bool:
	var m := int(minutes) % (24 * 60)
	return m >= 21 * 60 + 30 or m < 5 * 60

func seconds_to_hard(event_id: String) -> float:
	var clocks := hard_clocks_for_day()
	if not clocks.has(event_id):
		return -1.0
	return float(clocks[event_id]) - minutes
