extends Node
class_name JobBoard
## Content pipe (GDD §17). Jobs live in data/jobs/*.json and data/jobs/days/*.json.
## Catalog files carry {"jobs":[...]}; day files carry {"day":N,"weekday":M,...}.
## A job is data. Main only owns verbs that are genuinely procedural.

static var _jobs: Dictionary = {}   # id -> Dictionary
static var _days: Array = []        # day defs
static var _loaded := false

static func reload() -> void:
	_jobs.clear()
	_days.clear()
	_loaded = false
	_ensure_loaded()

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for path in _scan_paths():
		var parsed = _parse(path)
		if parsed is Dictionary:
			var d := parsed as Dictionary
			# "day" check first: day files also carry an informational jobs list.
			if d.has("day"):
				_days.append(d)
			elif d.has("jobs"):
				for j in d["jobs"]:
					_register(j)
		elif parsed is Array:
			for j in parsed:
				_register(j)

static func _scan_paths() -> Array:
	var out: Array = []
	for dir in ["res://data/jobs", "res://data/jobs/days"]:
		var da := DirAccess.open(dir)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".json"):
				out.append(dir + "/" + f)
	return out

static func _parse(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _register(j) -> void:
	if j is Dictionary and (j as Dictionary).has("id"):
		_jobs[String((j as Dictionary)["id"])] = j as Dictionary

## Job by id; {} when the id is not authored.
static func job(job_id: String) -> Dictionary:
	_ensure_loaded()
	return _jobs.get(String(job_id), {})

static func job_count() -> int:
	_ensure_loaded()
	return _jobs.size()

## True when the job may appear on this day/weekday/room.
static func available(job_id: String, day: int, weekday: int, scene: String) -> bool:
	var j := job(job_id)
	if j.is_empty():
		return false
	return _job_available(j, day, weekday, scene)

static func _job_available(j: Dictionary, day: int, weekday: int, scene: String) -> bool:
	# Date window: explicit list OR open range (day_min/day_max).
	var day_ok := true
	var has_day := j.has("days") or j.has("day_min") or j.has("day_max")
	if has_day:
		day_ok = false
		if j.has("days") and _num_in(day, j["days"]):
			day_ok = true
		var lo: int = int(j.get("day_min", 0))
		var hi: int = int(j.get("day_max", 9999))
		if day >= lo and day <= hi:
			day_ok = true
	if not day_ok:
		return false
	var wd_ok := true
	var has_wd := j.has("weekdays")
	if has_wd and not _num_in(weekday, j["weekdays"]):
		wd_ok = false
	if not wd_ok:
		return false
	# Scene: "any"/missing matches everywhere; else the room id must be listed.
	if j.has("scenes") and scene != "":
		if not (scene in (j["scenes"] as Array)) and not ("any" in (j["scenes"] as Array)):
			return false
	if not Effects.check_requires(j.get("requires", {}), day, weekday):
		return false
	return true

## Filtered job list for a day. Day-gating happens here, once.
static func jobs_for_day(day: int, weekday: int, scene: String = "") -> Array:
	_ensure_loaded()
	var out: Array = []
	for id in _jobs.keys():
		var j: Dictionary = _jobs[id]
		if _job_available(j, day, weekday, scene):
			out.append(j)
	return out

## Day def for the day number: exact day match first, else weekday match
## with a from_day bound. {} when nothing is authored (Main invents a line).
static func day_def(day: int, weekday: int) -> Dictionary:
	_ensure_loaded()
	for d in _days:
		if int(d.get("day", -1)) == day:
			return d
	for d in _days:
		if int(d.get("weekday", -1)) == weekday and day >= int(d.get("from_day", 0)):
			return d
	return {}

static func day_def_count() -> int:
	_ensure_loaded()
	return _days.size()

## Hide + disable every interactable in the room whose job is off today.
## Also refreshes prompts from the authored prompt text when present.
static func apply_gating(room: Node, day: int, weekday: int) -> void:
	if room == null:
		return
	var tree := room.get_tree()
	if tree == null:
		return
	var scene := String(room.get("room_id")) if room.get("room_id") != null else ""
	for n in tree.get_nodes_in_group("interactables"):
			var inter := n as Interactable
			if inter == null:
				continue
			if inter != room and not room.is_ancestor_of(inter):
				continue
			var j := job(inter.job_id)
			if j.is_empty():
				# Unauthored id: leave as-is but shout once for content hygiene.
				GameState.toast.emit("[content] no job authored for id: %s" % inter.job_id)
				continue
			if j.has("prompt"):
				inter.prompt_text = String(j["prompt"])
			var on := _is_live(j, day, weekday, scene, inter.job_id)
			inter.visible = on
			inter.disabled = not on

## JSON numbers arrive as floats; compare numerically, never int-in-float-array.
static func _num_in(value: int, arr) -> bool:
	if arr is Array:
		for v in arr as Array:
			if float(value) == float(v):
				return true
	return false

## Date/scene/requires availability AND once-consumed state.
static func _is_live(j: Dictionary, day: int, weekday: int, scene: String, job_id: String) -> bool:
	if not _job_available(j, day, weekday, scene):
		return false
	match String(j.get("once", "")):
		"day":
			return not GameState.used_jobs_day.has(job_id)
		"game":
			return not GameState.used_jobs_run.has(job_id)
	return true

## Public form of the live check for Main to re-verify before firing.
static func job_is_live(job_id: String, day: int, weekday: int, scene: String) -> bool:
	var j := job(job_id)
	if j.is_empty():
		return false
	return _is_live(j, day, weekday, scene, job_id)
