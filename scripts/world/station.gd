extends Location
## The platform. Trains follow Clock.TRAINS: one slides in when the clock
## reaches its departure time, waits DWELL real seconds, and leaves with or
## without Jonaid. After the last train only the taxi is left.

const DWELL := 14.0
const STOP_X := 2.5  ## train doors line up with the platform screen doors
const RIDE_MINUTES := 26.0
const TAXI_FARE := 45000

enum State { AWAY, ARRIVING, DOCKED, LEAVING }

var state := State.AWAY
var _dwell := 0.0
var _departing := -1  ## timetable slot the docked train belongs to
var _served := {}  ## timetable slots already handled today

@onready var train: Node3D = $Train
@onready var board_texts: Array[Label3D] = [$BoardText, $BoardText2]
@onready var board_door: Interactable = $Interactables/BoardTrain
@onready var taxi: Interactable = $Interactables/Taxi
@onready var bench: Interactable = $Interactables/Bench


func _ready() -> void:
	super._ready()
	train.visible = false
	board_door.enabled = false
	board_door.used.connect(_on_board)
	taxi.used.connect(_on_taxi)
	bench.used.connect(_on_bench)
	# Trains that left before Jonaid got here are not his problem.
	for t in Clock.TRAINS:
		if t < int(Clock.minutes):
			_served[t] = true


func _process(delta: float) -> void:
	match state:
		State.AWAY:
			var t := _next_unserved()
			if t >= 0 and Clock.minutes >= t:
				_arrive(t)
		State.DOCKED:
			_dwell -= delta
			if _dwell <= 4.0 and _dwell + delta > 4.0:
				Game.notify("Doors closing! 문이 닫힙니다!")
			if _dwell <= 0.0:
				_leave(true)
	_update_board()
	taxi.enabled = _next_unserved() < 0 and state == State.AWAY


func _next_unserved() -> int:
	for t in Clock.TRAINS:
		if not _served.has(t):
			return t
	return -1


func _arrive(t: int) -> void:
	state = State.ARRIVING
	_departing = t
	_served[t] = true
	train.visible = true
	train.position.x = -75.0
	var tw := create_tween()
	tw.tween_property(train, "position:x", STOP_X, 3.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		state = State.DOCKED
		_dwell = DWELL
		board_door.enabled = true)


func _leave(missed: bool) -> void:
	state = State.LEAVING
	board_door.enabled = false
	if missed:
		Game.bump("trains_missed")
		var nxt := _next_unserved()
		if nxt >= 0:
			Game.notify("Missed it. Next train %s." % Clock.format(nxt))
		else:
			Game.notify("That was the last train. Taxi time. (Your wallet weeps.)")
	var tw := create_tween()
	tw.tween_property(train, "position:x", 90.0, 3.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		train.visible = false
		state = State.AWAY)


func _update_board() -> void:
	var lines := PackedStringArray()
	match state:
		State.DOCKED:
			lines.append("%s  NOW BOARDING" % Clock.format(_departing))
			lines.append("Doors close in %d" % ceili(maxf(_dwell, 0.0)))
		State.ARRIVING:
			lines.append("%s  ARRIVING" % Clock.format(_departing))
		_:
			var t := _next_unserved()
			if t < 0:
				lines.append("NO MORE TRAINS")
				lines.append("막차 끊김 · Take a taxi")
			else:
				var mins := maxi(0, t - int(Clock.minutes))
				lines.append("NEXT  %s%s" % [Clock.format(t), "  (LAST)" if Clock.is_last_train(t) else ""])
				lines.append("in %d min" % mins)
	for b in board_texts:
		b.text = "\n".join(lines)


func _on_board(by: Node) -> void:
	if state != State.DOCKED:
		return
	board_door.enabled = false
	Game.travel("home", "door", RIDE_MINUTES)
	if by is Player:
		(by as Player).controls_enabled = false


func _on_bench(by: Node) -> void:
	var t := _next_unserved()
	if t < 0 or state != State.AWAY:
		Game.say(by as Node3D, "Nothing to wait for. Except death. Or a taxi.")
		return
	if t - Clock.minutes > 1.0:
		Clock.advance(t - Clock.minutes - 1.0)
		Game.say(by as Node3D, "Zoned out on the bench. Saw my whole career flash before my eyes. It was short.")


func _on_taxi(_by: Node) -> void:
	var paid := mini(TAXI_FARE, Game.money)
	Game.spend(paid)
	Game.took_taxi = true
	if paid < TAXI_FARE:
		Game.notify("Taxi: %s. You had %s. The driver took your umbrella for the rest." % [Game.won(TAXI_FARE), Game.won(paid)])
	else:
		Game.notify("Taxi: %s. The driver plays trot music the whole way." % Game.won(TAXI_FARE))
	Game.travel("home", "door", 35.0)
