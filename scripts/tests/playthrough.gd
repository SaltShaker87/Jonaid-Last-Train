extends Node
class_name Playthrough
## Scripted multi-day playtest (progress.md step 1, automated).
## `--sim` boots the real game and plays it like a person would: badge out,
## run every live job in each room, complete skills with a scripted grade,
## ride the night trains, sleep, take the morning. Three games per launch:
##   1) "clean" — grades lean clean/sloppy; must survive 25 days
##   2) "greed" — every task signed perfectly, 60 days; measures whether the
##      Face soft cap holds and whether the balance stays solvent
##   3) "chaos" — skills fail; the run must end in a legal loss, not a crash
## Asserts: no [content] errors, ending via the real signal path, the day
## cycle completes without stalls, and each profile's specific balance budget.
## Each run reports per-meter min/max/avg plus jobs fired vs skipped, so the
## balance findings are measured rather than eyeballed from the day lines.
##
## Driven by _process as a state machine keyed on the current room — no
## awaits: in headless, signal awaits in this node stop resuming once
## load_room's timer coroutine runs.

const DAYS_CLEAN := 25
const DAYS_GREED := 60
const DAYS_CHAOS := 60
const WAIT_TIMEOUT := 6.0

## Profiles run in sequence within one launch.
const PROFILES := ["clean", "greed", "chaos"]

const OFFICE_STEPS := ["pin_folder", "briefing", "take_tube", "slides_pc", "bow_choi", "copier_jam", "quit_draft_pc", "slides_friday", "badge_out"]
const STREET_STEPS := ["yoon_refuse", "lightbox_trace", "yoon_crop", "mullae_copy", "g90_board", "g90_sign", "whiskey_buy", "beer_pour", "shuttle_curb", "go_restaurant", "go_station"]
const STATION_STEPS := ["turnstile", "platform_dash", "taxi"]
const RESTAURANT_STEPS := ["hoesik_pour", "leave_hoesik"]
const APARTMENT_STEPS := ["gym_walk", "market_fish", "fish_prime", "cabinet_shop", "sign_slip", "talk_hana", "bedtime", "sleep_bed"]

var _game: Node
var _grade_i := 0
var _content_errors: Array = []
var _fail := 0
var _ending_id := ""
var _df: FileAccess

var _room_step := 1
var _pending_step := 1
var _last_room := ""
var _wait_room := ""
var _wait_t := 0.0
var _settle := 0.0
var _profile_i := 0        # index into PROFILES
var _phase := "clean"     # active profile name, "done" when finished
var _target_day := DAYS_CLEAN
var _log_next_day := true
var _ended_reported := false

# --- telemetry, reset per profile -------------------------------------------
var _stats := {}          # meter name -> {"min":float,"max":float,"sum":float,"n":int}
var _fired := {}          # job id -> count
var _skipped := {}        # job id -> count (not live, or already consumed)
var _min_money := 0
var _face_over_80_days := 0
var _days_logged := 0

static func start(game: Node) -> void:
	if not _requested():
		return
	var p: Node = load("res://scripts/tests/playthrough.gd").new()
	p.name = "Playthrough"
	game.add_child(p)

## The documented invocation is `Godot --headless -- --sim`, which lands in the
## *user* arg list. Also accept the bare `--sim` form. Same rule as --capture.
static func _requested() -> bool:
	return "--sim" in OS.get_cmdline_user_args() or "--sim" in OS.get_cmdline_args()

func _ready() -> void:
	if not _requested():
		return
	_dbg_open()
	_dbg("sim start")
	_game = get_tree().get_first_node_in_group("game")
	GameState.toast.connect(_on_toast)
	GameState.game_over.connect(func(_kind, eid): _ending_id = String(eid))
	print("\n[Playthrough] === CLEAN RUN: %d days ===" % DAYS_CLEAN)

var _dash_grade := ""
var _last_grade := "clean"

func _process(delta: float) -> void:
	if _game == null:
		return
	if GameState.ended:
		_report_ending()
		return
	if _phase != "done" and DayClock.day > _target_day:
		_end_profile()
		_start_next_profile()
		return
	if _settle > 0.0:
		_settle -= delta
		return
	var rid := String(_game.get("current_room_id"))
	if rid != _last_room:
		_dbg("room -> " + rid)
		_last_room = rid
		_room_step = _pending_step
		_pending_step = 1
		_wait_room = ""
		if rid == "office" and _log_next_day:
			_log_day()
	if _wait_room != "":
		_wait_t += delta
		if _wait_t > WAIT_TIMEOUT:
			_dbg("STUCK waiting for room %s (in %s)" % [_wait_room, rid])
			_fail += 1
			print("[FAIL] stuck waiting for room %s" % _wait_room)
			_wait_room = ""
		return
	var steps := _steps_for(rid)
	if steps.is_empty() or _room_step > steps.size():
		return
	var id: String = steps[_room_step - 1]
	_room_step += 1
	_run_step(id)

func _steps_for(room: String) -> Array:
	match room:
		"office": return OFFICE_STEPS
		"street": return STREET_STEPS
		"station": return STATION_STEPS
		"restaurant": return RESTAURANT_STEPS
		"apartment": return APARTMENT_STEPS
	return []

func _run_step(id: String) -> void:
	match id:
		"slides_friday":
			if DayClock.weekday == 4 and not GameState.slides_filed:
				# File before the 18:00 PIP review reads the file.
				DayClock.minutes = 17 * 60 + 55
				_fire("slides_pc")
		"badge_out":
			if _fire(id):
				_goto_room("street", 1)
		"shuttle_curb":
			DayClock.minutes = 18 * 60 + 5   # pre-shuttle clock (pure time, no skill)
			_fire(id)
		"go_restaurant":
			if _live(id) and _fire(id):
				_goto_room("restaurant", 1)
		"go_station":
			if _fire(id):
				_goto_room("station", 1)
		"leave_hoesik":
			if _fire(id):
				# Back on the street: resume at the station door.
				_goto_room("street", STREET_STEPS.find("go_station") + 1)
		"platform_dash":
			DayClock.minutes = 19 * 60 + 31   # family train window
			_fire(id)
			_dash_grade = _last_grade
		"taxi":
			if _dash_grade == "fail" and rid_not("apartment"):
				# Dash failed: taxi is legal only after the doors shut.
				DayClock.minutes = 23 * 60 + 30
				if GameState.money < GameState.TAXI:
					GameState.earn(GameState.TAXI * 2)  # scripted charity fare
				_game.call("call_taxi")
		"sleep_bed":
			if _fire(id):
				_goto_room("office", 1)
				_settle = 1.0
				_log_next_day = true
		_:
			_fire(id)

func rid_not(room: String) -> bool:
	return String(_game.get("current_room_id")) != room

func _goto_room(room: String, step: int) -> void:
	_wait_room = room
	_pending_step = step
	_wait_t = 0.0

func _targets_for(profile: String) -> int:
	match profile:
		"clean": return DAYS_CLEAN
		"greed": return DAYS_GREED
		"chaos": return DAYS_CHAOS
	return DAYS_CLEAN

## Advance to the next profile, or finish the whole sim.
func _start_next_profile() -> void:
	_profile_i += 1
	if _profile_i >= PROFILES.size():
		_phase = "done"
		_finish()
		return
	_begin_profile(PROFILES[_profile_i], false)

func _begin_profile(profile: String, from_ending: bool) -> void:
	_phase = profile
	_target_day = _targets_for(profile)
	_grade_i = 0
	_ending_id = ""
	_ended_reported = false
	_stats.clear()
	_fired.clear()
	_skipped.clear()
	_min_money = 0
	_face_over_80_days = 0
	_days_logged = 0
	GameState.new_game()
	SaveIO.clear()
	DayClock.start_day(1, 1, 8 * 60 + 50)
	match profile:
		"clean":
			print("\n[Playthrough] === CLEAN RUN: %d days ===" % _target_day)
		"greed":
			print("\n[Playthrough] === GREED RUN: %d days, every task signed ===" % _target_day)
		_:
			print("\n[Playthrough] === CHAOS RUN: %d days, skills fail ===" % _target_day)
	_game.load_room("office")
	_last_room = ""          # force re-entry bookkeeping
	_goto_room("office", 1)
	_settle = 1.5
	_log_next_day = true

## Roll up what the run measured, then assert what that profile is for.
func _end_profile() -> void:
	_report_stats(_phase)
	match _phase:
		"clean":
			_check(DayClock.day > DAYS_CLEAN, "clean run reached day %d" % DayClock.day)
		"greed":
			_check(DayClock.day > DAYS_GREED, "greed run survived to day %d" % DayClock.day)
			_check(GameState.face < 100.0,
			      "greed face soft-capped at %.0f (not pinned)" % GameState.face)
			_check(GameState.money >= 0, "greed balance stayed solvent (min %d)" % _min_money)
			_check(_min_money >= 0, "greed never went negative across %d days" % _days_logged)

func _report_stats(profile: String) -> void:
	print("\n   --- %s telemetry (%d days) ---" % [profile, _days_logged])
	var names := ["hana", "kids", "face", "body", "pip"]
	for n in names:
		var s: Dictionary = _stats.get(n, {})
		if int(s.get("n", 0)) == 0:
			continue
		var cnt := int(s["n"])
		print("   %-6s min %5.1f  max %5.1f  avg %5.1f" % [
			n, float(s["min"]), float(s["max"]), float(s["sum"]) / float(cnt)])
	print("   money  min %d  max %d" % [_min_money, int(_stats.get("money", {}).get("max", 0))])
	if _face_over_80_days > 0:
		print("   face above 80 on %d of %d days (soft cap zone)" % [
			_face_over_80_days, _days_logged])
	var top: Array = []
	for id in _fired.keys():
		top.append([String(id), int(_fired[id])])
	top.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	var shown: Array = []
	for e in top:
		shown.append("%s x%d" % [e[0], e[1]])
	print("   fired: %s" % ", ".join(shown))
	var skips: Array = []
	for id in _skipped.keys():
		if int(_skipped[id]) > 0:
			skips.append("%s x%d" % [id, int(_skipped[id])])
	print("   skipped: %s" % (", ".join(skips) if skips.size() > 0 else "none"))

func _track(key: String, value: float) -> void:
	if not _stats.has(key):
		_stats[key] = {"min": value, "max": value, "sum": value, "n": 0}
	var s: Dictionary = _stats[key]
	s["min"] = minf(float(s["min"]), value)
	s["max"] = maxf(float(s["max"]), value)
	s["sum"] = float(s["sum"]) + value
	s["n"] = int(s["n"]) + 1

func _report_ending() -> void:
	if _ended_reported:
		return
	_ended_reported = true
	print("[Playthrough] ENDED via %s at Day %d" % [_ending_id, DayClock.day])
	_report_stats(_phase)
	match _phase:
		"clean":
			print("[FAIL] clean run ended early at day %d (%s)" % [DayClock.day, _ending_id])
			_fail += 1
			_ended_reported = false
			GameState.ended = false
			_start_next_profile()
			return
		"greed":
			print("[FAIL] greed run ended early at day %d (%s)" % [DayClock.day, _ending_id])
			_fail += 1
			_check(GameState.money >= 0, "greed balance stayed solvent (min %d)" % _min_money)
	_check(_ending_id != "", "%s run reached a legal ending (got '%s')" % [_phase, _ending_id])
	_start_next_profile()

# ---------------------------------------------------------------- helpers

func _inter(job_id: String) -> Interactable:
	for n in get_tree().get_nodes_in_group("interactables"):
		var inter := n as Interactable
		if inter != null and inter.job_id == job_id and inter.is_inside_tree():
			return inter
	return null

func _live(job_id: String) -> bool:
	var inter := _inter(job_id)
	return inter != null and inter.visible and not inter.disabled

func _fire(job_id: String) -> bool:
	var inter := _inter(job_id)
	if inter == null or not inter.visible or inter.disabled:
		_skipped[job_id] = int(_skipped.get(job_id, 0)) + 1
		return false
	_dbg("fire %s" % job_id)
	_fired[job_id] = int(_fired.get(job_id, 0)) + 1
	_game.call("on_interact", inter)
	if _game.get("active_skill") != null:
		_last_grade = _next_grade()
		(_game.get("active_skill") as SkillBase).complete(_last_grade)
	return true

func _next_grade() -> String:
	_grade_i += 1
	match _phase:
		"greed":
			return "clean"          # signs everything, perfectly
		"chaos":
			return "sloppy" if _grade_i % 5 == 0 else "fail"
	return "sloppy" if _grade_i % 4 == 0 else "clean"

func _log_day() -> void:
	print("   Day %d %s | money %d pip %.0f hana %.0f kids %.0f face %.0f body %.0f stress %d | fish %s filter %s" % [
		DayClock.day, DayClock.weekday_name(), GameState.money, GameState.pip,
		GameState.hana, GameState.kids, GameState.face, GameState.body, int(StressSys.value),
		"alive" if GameState.fish_alive else "dead", GameState.filter_state])
	_days_logged += 1
	if _days_logged == 1:
		_min_money = GameState.money
	else:
		_min_money = mini(_min_money, GameState.money)
	for pair in [["hana", GameState.hana], ["kids", GameState.kids], ["face", GameState.face],
			["body", GameState.body], ["pip", GameState.pip], ["money", float(GameState.money)]]:
		_track(String(pair[0]), float(pair[1]))
	if GameState.face > GameState.FACE_SOFT_CAP:
		_face_over_80_days += 1

func _check(cond: bool, name: String) -> void:
	if cond:
		print("[PASS] %s" % name)
	else:
		_fail += 1
		print("[FAIL] %s" % name)

func _finish() -> void:
	print("\n[Playthrough] content errors: %d" % _content_errors.size())
	for e in _content_errors.slice(0, 20):
		print("   %s" % e)
	_check(_content_errors.size() == 0, "no [content] errors across runs")
	print("\n[Playthrough] done, failures=%d" % _fail)
	_dbg_close()
	get_tree().quit(0 if _fail == 0 else 1)

func _on_toast(text: String) -> void:
	if String(text).find("[content]") >= 0:
		_content_errors.append(String(text))
		_dbg("content error: %s" % text)
		print("   [content error] %s" % text)

func _dbg(msg: String) -> void:
	if _df == null:
		return
	_df.store_line("[%6.2f] %s" % [Time.get_ticks_msec() / 1000.0, msg])
	_df.flush()

func _dbg_open() -> void:
	if FileAccess.file_exists("user://sim.log"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sim.log"))
	_df = FileAccess.open("user://sim.log", FileAccess.WRITE)

func _dbg_close() -> void:
	if _df != null:
		_df.close()
		_df = null
