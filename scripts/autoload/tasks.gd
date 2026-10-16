extends Node
## Park's task queue (DESIGN.md "Tasks"). Templates live in data/tasks.json.
## Tasks arrive faster through the day and faster each day; a missed deadline
## or a failed minigame raises stress, a finished one pays. Also tracks
## whether Park is still in the office (for nunchi) and what Jonaid owes him.

signal task_added(task: Dictionary)
signal task_removed(task: Dictionary, outcome: String)  ## perfect, ok, fail, expired, abandoned
signal play_requested(task: Dictionary)
signal park_leaving

const DATA_PATH := "res://data/tasks.json"
const MAX_PENDING := 6
const STRESS_FAIL := 9.0
const STRESS_EXPIRE := 11.0
const STRESS_ABANDON := 4.0
const STRESS_FULL_LIST := 3.0
const RELIEF_PERFECT := 3.0

const YELL_FAIL := [
	"JONAID! What is THIS?! Do it AGAIN. In your HEAD.",
	"My grandmother does better work. She's been dead for ten years.",
	"Wrong! Everything is wrong! Even your FACE is wrong today!",
	"I'm not angry. I'm DISAPPOINTED. No, I'm angry.",
]
const YELL_EXPIRE := [
	"Where is my '%s'?! It was due at %s!",
	"'%s'. Due %s. Do you see it? Because I DON'T.",
	"Tick tock, Jonaid. '%s' was due at %s. Tick. TOCK.",
]
const YELL_FULL := [
	"Your list is FULL? Then work FASTER.",
	"Too many tasks? In my day we had ONE task. It was everything.",
]
const PRAISE := [
	"...Acceptable.",
	"Hm. Fine. Don't let it go to your head.",
	"Good. Now do it again tomorrow. Forever.",
]

var pending: Array[Dictionary] = []
var active := false  ## Jonaid is in the office during a run
var owed := 0  ## extra tasks Park hands out first thing tomorrow (left before him)
var park_present := true
var park_leave_at := 20 * 60
var playing: Dictionary = {}
var park: Node3D  ## set by the office scene so Park can speak
var stations := {}

var _templates: Array = []
var _next_spawn := 0.0
var _uid := 0
var _say_queue: Array[String] = []
var _say_ready_at := 0.0

const SAY_GAP := 3.4  ## real seconds between Park's lines so bubbles don't overwrite each other


func _ready() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var data: Dictionary = JSON.parse_string(f.get_as_text())
		_templates = data.get("tasks", [])
		stations = data.get("stations", {})
	Clock.minute_passed.connect(_on_minute)


# ---------------------------------------------------------------- day flow

func start_day() -> void:
	_say_queue.clear()
	for t in pending:
		task_removed.emit(t, "cleared")
	pending.clear()
	playing = {}
	park_present = true
	# Park goes home somewhere between 19:00 and 21:30. Rarely, a miracle.
	park_leave_at = 18 * 60 + 5 if randf() < 0.08 else randi_range(19 * 60, 21 * 60 + 30)
	_next_spawn = Clock.DAY_START + 3.0
	var morning := 1 + owed
	var owed_now := owed
	owed = 0
	for i in morning:
		spawn("You left before me yesterday. This one's personal." if i == 0 and owed_now > 0 else "")


func enter_office() -> void:
	active = true


## Jonaid walks out with tasks still on the list. Park will remember.
func leave_office() -> void:
	active = false
	if pending.is_empty() or not Game.in_run:
		return
	var n := pending.size()
	for t in pending.duplicate():
		pending.erase(t)
		Game.bump("tasks_failed")
		task_removed.emit(t, "abandoned")
	Stress.add(STRESS_ABANDON * n)
	Game.notify("You left %d unfinished task%s on your desk. Park will remember." % [n, "" if n == 1 else "s"])


func _on_minute(_m: int) -> void:
	if not active or not Game.in_run:
		return
	for t in pending.duplicate():
		if t != playing and Clock.minutes >= float(t["due"]):
			_expire(t)
	if park_present and Clock.minutes >= park_leave_at:
		park_present = false
		park_leaving.emit()
		return
	if park_present and Clock.minutes >= _next_spawn:
		spawn()
		_next_spawn = Clock.minutes + _interval()


## Game minutes until the next task. Shrinks with each day and toward evening.
func _interval() -> float:
	var base := maxf(13.0, 38.0 - 9.0 * float(Clock.day - 1))
	var through := clampf((Clock.minutes - Clock.DAY_START) / float(Clock.WORK_END - Clock.DAY_START), 0.0, 1.0)
	return base * (1.0 - 0.3 * through) * randf_range(0.75, 1.25)


func _deadline_scale() -> float:
	return maxf(0.6, 1.0 - 0.12 * float(Clock.day - 1))


# ---------------------------------------------------------------- tasks

func spawn(line_override: String = "", template_id: String = "") -> Dictionary:
	if pending.size() >= MAX_PENDING:
		Stress.add(STRESS_FULL_LIST)
		_say(YELL_FULL[randi() % YELL_FULL.size()])
		return {}
	var tpl := _pick(template_id)
	if tpl.is_empty():
		return {}
	_uid += 1
	var t: Dictionary = tpl.duplicate(true)
	t["uid"] = _uid
	t["due"] = Clock.minutes + float(tpl.get("deadline", 60)) * _deadline_scale()
	t["where"] = stations.get(t.get("station", ""), "Somewhere")
	pending.append(t)
	task_added.emit(t)
	Sfx.play("ping")
	_say(line_override if line_override != "" else String(t.get("line", "")))
	return t


func _pick(template_id: String = "") -> Dictionary:
	if template_id != "":
		for tpl in _templates:
			if tpl["id"] == template_id:
				return tpl
	var taken := {}
	for t in pending:
		taken[t["id"]] = true
	var pool: Array = []
	var total := 0.0
	for tpl in _templates:
		if int(tpl.get("min_day", 1)) <= Clock.day and not taken.has(tpl["id"]):
			pool.append(tpl)
			total += float(tpl.get("weight", 1))
	if pool.is_empty():
		return {}
	var r := randf() * total
	for tpl in pool:
		r -= float(tpl.get("weight", 1))
		if r <= 0.0:
			return tpl
	return pool.back()


## The most urgent pending task at a station, or {}.
func for_station(station: String) -> Dictionary:
	var best: Dictionary = {}
	for t in pending:
		if t.get("station", "") == station and (best.is_empty() or float(t["due"]) < float(best["due"])):
			best = t
	return best


func has_game(game: String) -> bool:
	for t in pending:
		if t.get("game", "") == game:
			return true
	return false


func play(t: Dictionary) -> void:
	if t.is_empty() or not pending.has(t):
		return
	playing = t
	play_requested.emit(t)


func complete(t: Dictionary, grade: String) -> void:
	playing = {}
	if not pending.has(t):
		return
	pending.erase(t)
	var pay := int(t.get("pay", 0))
	match grade:
		"perfect":
			Game.earn(int(pay * 1.5))
			Stress.relieve(RELIEF_PERFECT)
			Game.bump("tasks_done")
			Sfx.play("chime")
			if randf() < 0.5:
				_say(PRAISE[randi() % PRAISE.size()])
		"ok":
			Game.earn(pay)
			Game.bump("tasks_done")
			Sfx.play("chime")
		_:
			Stress.add(STRESS_FAIL)
			Game.bump("tasks_failed")
			Sfx.play("buzz")
			_say(YELL_FAIL[randi() % YELL_FAIL.size()])
	task_removed.emit(t, grade)


func _expire(t: Dictionary) -> void:
	pending.erase(t)
	Stress.add(STRESS_EXPIRE)
	Game.bump("tasks_failed")
	Sfx.play("buzz")
	var line: String = YELL_EXPIRE[randi() % YELL_EXPIRE.size()]
	_say(line % [t.get("title", "that"), Clock.format(float(t["due"]))])
	task_removed.emit(t, "expired")


## Park speaks through a queue: several lines in a row play one after another.
func _say(line: String) -> void:
	if line != "" and _say_queue.size() < 4:
		_say_queue.append(line)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _say_queue.is_empty() or now < _say_ready_at:
		return
	var line: String = _say_queue.pop_front()
	_say_ready_at = now + SAY_GAP
	if is_instance_valid(park) and park.is_inside_tree() and park.visible:
		Game.say(park, line, 4.5)
	elif Game.in_run:
		Game.notify("Park: " + line)


## For other scripts that want Park to speak in turn.
func park_says(line: String) -> void:
	_say(line)


## Difficulty for minigames, 0..1: later days and higher stress are harder.
func difficulty() -> float:
	return clampf(0.22 * float(Clock.day - 1) + Stress.value / 250.0, 0.0, 1.0)
