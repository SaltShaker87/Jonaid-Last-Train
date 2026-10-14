class_name Effects
## Content effect interpreter (GDD §17).
## JSON jobs declare effect lists; this is the ONE place a list becomes state.
## A new joke is a JSON file, not a match statement in Main.
##
## Verbs (closed set):
##   meter  {"do":"meter","name":"hana|kids|face|body|pip|jealousy|stress","delta":float}
##   money  {"do":"money","delta":int}            negative = guarded spend, aborts on poverty
##          {"do":"money","spend":int}            guarded, aborts the list on poverty
##          {"do":"money","earn":int}
##   flag   {"do":"flag","name":<alias>,"value":bool|int|string}   (aliases below)
##   promise{"do":"promise","name":"slip_signed","value":true}
##   carry  {"do":"carry","value":"map_tube"}
##   toast  {"do":"toast","text":"..."}
##   audio  {"do":"audio","name":"jam"}
##   minutes{"do":"minutes","value":4}
##   travel {"do":"travel","room":"street","socket":"spawn","minutes":4}
##   engine {"do":"engine","name":"resolve_dash","args":["$grade"]}  Main hooks
##   ending {"do":"ending","kind":"day60","id":"clerk_yoon_right"}

const METERS := ["hana", "kids", "face", "body", "pip", "jealousy"]

# JSON flag alias -> GameState property. An unknown name toasts loudly:
# a typo'd flag is a content bug you can hear.
const FLAG_ALIAS := {
	"map_resolved": "map_resolved",
	"legal_flag": "map_legal_flag",
	"slides_filed": "slides_filed",
	"sora_sniped": "sora_sniped",
	"pinned_folder": "pinned_folder",
	"fish_alive": "fish_alive",
	"filter_state": "filter_state",
	"smell_beer": "smell_beer",
	"has_map_tube": "has_map_tube",
	"has_quiet_filter": "has_quiet_filter",
	"has_grace_key": "has_grace_key",
	"has_alarm": "has_alarm",
	"quit_draft": "quit_draft",
	"recital_missed": "recital_missed",
}

## Apply a list. Returns false when an effect aborts (guarded spend).
##
## Two passes: the whole list is validated before any of it runs, so a typo
## in the last effect can never leave the first three already applied.
static func apply_list(list: Array, ctx: Dictionary) -> bool:
	if list == null:
		return true
	if not validate_list(list):
		return false
	for e in list:
		if e is Dictionary:
			if not apply_one(e as Dictionary, ctx):
				return false
	return true

## Dry-run every entry. Reports the first structural problem as a [content]
## toast and returns false so the caller can skip the list untouched.
static func validate_list(list: Array) -> bool:
	if list == null:
		return true
	for e in list:
		if not (e is Dictionary):
			GameState.toast.emit("[content] effect entry is not an object")
			return false
		var d := e as Dictionary
		match String(d.get("do", "")):
			"meter":
				var mn := String(d.get("name", ""))
				if mn != "stress" and not (mn in METERS):
					GameState.toast.emit("[content] unknown meter: %s" % mn)
					return false
			"flag":
				var fk := String(d.get("name", ""))
				if not FLAG_ALIAS.has(fk):
					GameState.toast.emit("[content] unknown flag: %s" % fk)
					return false
			"engine":
				pass  # verb names resolve against Main at call time
			_:
				pass
	return true

static func apply_one(e: Dictionary, ctx: Dictionary) -> bool:
	var game: Node = ctx.get("game", null)
	var grade := String(ctx.get("grade", ""))
	match String(e.get("do", "")):
		"meter":
			var name := String(e.get("name", ""))
			var delta := float(e.get("delta", 0.0))
			if name == "stress":
				if delta >= 0.0:
					StressSys.add(delta)
				else:
					StressSys.relieve(-delta)
			elif name in METERS:
				GameState.call("add_" + name, delta)
			else:
				GameState.toast.emit("[content] unknown meter: %s" % name)
		"money":
			# A negative delta is spending, so it goes through the guard: the
			# list aborts on poverty rather than driving money negative.
			var d := int(e.get("delta", 0))
			if d < 0:
				if not GameState.spend(-d):
					return false
			elif d > 0:
				GameState.earn(d)
			var sp := int(e.get("spend", 0))
			if sp != 0:
				if not GameState.spend(sp):
					return false
			var en := int(e.get("earn", 0))
			if en != 0:
				GameState.earn(en)
		"flag":
			var key := String(e.get("name", ""))
			if not FLAG_ALIAS.has(key):
				GameState.toast.emit("[content] unknown flag: %s" % key)
				return false
			var prop: String = FLAG_ALIAS[key]
			var want = e.get("value", true)
			var cur = GameState.get(prop)
			if typeof(cur) == TYPE_BOOL:
				want = bool(want)
			elif typeof(cur) == TYPE_INT:
				want = int(want)
			elif typeof(cur) == TYPE_STRING:
				want = String(want)
			GameState.set(prop, want)
		"promise":
			var pname := String(e.get("name", ""))
			if pname != "":
				GameState.promises[pname] = bool(e.get("value", true))
		"carry":
			var item := String(e.get("value", ""))
			if game != null:
				var p := game.get("player") as Salaryman
				if p != null:
					p.set_carry(item)
		"toast":
			GameState.toast.emit(String(e.get("text", "")))
		"audio":
			if game != null:
				game.call("play_audio", String(e.get("name", "")))
		"minutes":
			DayClock.add_minutes(float(e.get("value", 0)))
		"travel":
			var mins := float(e.get("minutes", 0.0))
			if mins != 0.0:
				DayClock.add_minutes(mins)
			if game != null:
				game.call("load_room", String(e.get("room", "")), String(e.get("socket", "spawn")))
		"engine":
			var verb := String(e.get("name", ""))
			if e.has("args"):
				var argv: Array = []
				for a in e["args"]:
					argv.append(grade if String(a) == "$grade" else a)
				game.callv(verb, argv)
			else:
				game.call(verb)
		"vfx":
			if game != null:
				game.call("vfx", String(e.get("name", "")))
		"ending":
			if game != null:
				game.call("show_ending", String(e.get("kind", "day60")), String(e.get("id", "")))
		_:
			GameState.toast.emit("[content] unknown verb: %s" % e.get("do"))
			return false
	return true

## JSON numbers arrive as floats; compare numerically.
static func _num_in(value: int, arr) -> bool:
	if arr is Array:
		for v in arr as Array:
			if float(value) == float(v):
				return true
	return false

## Gating requires for catalog jobs. Keys:
##   day:[..] | weekday:[..] | day_min:N | day_max:N | money_min:N
##   not_<flag>:true (falseness) | <GameState prop>: value (equality)
static func check_requires(req: Dictionary, day: int, weekday: int) -> bool:
	if req == null or req.is_empty():
		return true
	for k in req.keys():
		var key := String(k)
		var want = req[k]
		if key == "day":
			if not _num_in(day, want):
				return false
		elif key == "weekday":
			if not _num_in(weekday, want):
				return false
		elif key == "day_min":
			if day < int(want):
				return false
		elif key == "day_max":
			if day > int(want):
				return false
		elif key == "money_min":
			if GameState.money < int(want):
				return false
		elif key.begins_with("not_"):
			if bool(GameState.get(key.substr(4))):
				return false
		else:
			var cur = GameState.get(key)
			if typeof(cur) != typeof(want):
				return false
			if cur != want:
				return false
	return true
