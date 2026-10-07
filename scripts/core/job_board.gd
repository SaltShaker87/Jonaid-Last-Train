extends Node
class_name JobBoard
## Content pipe — jobs in res://data/jobs/*.json (GDD §17).
## A new joke is a room prop plus a JSON file.

static func load_all() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://data/jobs")
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			var jobs := load_file("res://data/jobs/" + f)
			out.append_array(jobs)
	return out

static func load_file(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed is Array:
		return parsed
	if parsed is Dictionary and (parsed as Dictionary).has("jobs"):
		return (parsed as Dictionary)["jobs"]
	return out

static func jobs_for_day(jobs: Array, day: int, weekday: int) -> Array:
	var out: Array = []
	for j in jobs:
		if j is Dictionary:
			var d := j as Dictionary
			var day_match := true
			if d.has("days"):
				day_match = day in (d["days"] as Array)
			var wd_match := true
			if d.has("weekdays"):
				wd_match = weekday in (d["weekdays"] as Array)
			if day_match and wd_match:
				out.append(d)
	return out
