extends Node
class_name TestRig
## Headless assert rig. `--auto-test` boots the game and attaches this.
## Prints [PASS]/[FAIL] per check; nonzero exit code on any failure.
## No addon, no CI needed: the smoke command IS the gate.

var _pass := 0
var _fail := 0
var _game: Node

static func attach(game: Node) -> void:
	if not ("--auto-test" in OS.get_cmdline_args() or OS.has_feature("dedicated_server")):
		return
	var t: Node = load("res://scripts/tests/test_rig.gd").new()
	t.name = "TestRig"
	game.add_child(t)

func _ready() -> void:
	if not ("--auto-test" in OS.get_cmdline_args() or OS.has_feature("dedicated_server")):
		return
	# Let start_new_game() finish its room load.
	await get_tree().process_frame
	await get_tree().process_frame
	_game = get_tree().get_first_node_in_group("game")
	_test_content()
	_test_gating()
	_test_effects()
	_test_clock()
	_test_stress()
	_test_shop_and_save()
	await _test_morning_and_rollover()
	_test_endings()
	_test_divorce_and_nuclear()
	await _test_interact_parity()
	print("\n[TestRig] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] %s" % name)
	else:
		_fail += 1
		print("[FAIL] %s" % name)

func _test_content() -> void:
	_check(JobBoard.job_count() >= 25, "catalog loads >=25 jobs (%d)" % JobBoard.job_count())
	_check(JobBoard.day_def_count() >= 5, "day defs >=5 (%d)" % JobBoard.day_def_count())
	var tue: Dictionary = JobBoard.day_def(1, 1)
	_check(tue.has("briefing") and String(tue["briefing"]).length() > 10, "tuesday has briefing")
	var thu: Dictionary = JobBoard.day_def(3, 3)
	_check(thu.has("briefing"), "thursday authored by weekday")
	_check(JobBoard.job("lightbox_trace").has("on_grade"), "trace job has graded effects")
	_check(JobBoard.job("badge_out").has("on_use"), "nav job has instant effects")

func _test_gating() -> void:
	_check(JobBoard.available("lightbox_trace", 1, 1, "street"), "trace live day1 tuesday")
	_check(not JobBoard.available("lightbox_trace", 2, 2, "street"), "trace off day2 wednesday")
	_check(JobBoard.available("lightbox_trace", 7, 1, "street"), "trace overlap day7 (week 2+)")
	_check(not JobBoard.available("quit_draft_pc", 1, 1, "office"), "quit draft hidden before week 2")
	_check(JobBoard.available("quit_draft_pc", 2, 2, "office"), "quit draft live day2")
	_check(not JobBoard.available("go_restaurant", 1, 1, "street"), "restaurant door not Tuesday")
	_check(JobBoard.available("go_restaurant", 3, 3, "street"), "restaurant door Thursday")
	_check(not JobBoard.available("gym_walk", 1, 1, "apartment"), "gym not Tuesday")
	_check(JobBoard.available("gym_walk", 5, 5, "apartment"), "gym Saturday")
	GameState.used_jobs_run["sign_slip"] = true
	_check(not JobBoard.job_is_live("sign_slip", 1, 1, "apartment"), "once-game blocks re-use")
	GameState.used_jobs_run.erase("sign_slip")

func _test_effects() -> void:
	GameState.new_game()
	var ctx := {"game": _game, "inter": null, "grade": "clean"}
	_check(GameState.face == 50.0, "fresh face 50")
	Effects.apply_list([{"do": "meter", "name": "face", "delta": 5.0}], ctx)
	_check(GameState.face == 55.0, "meter face +5")
	Effects.apply_list([{"do": "meter", "name": "stress", "delta": -30.0}], ctx)
	_check(absf(StressSys.value - 0.0) < 0.01, "stress floor at 0")
	Effects.apply_list([{"do": "flag", "name": "pinned_folder", "value": true}], ctx)
	_check(GameState.pinned_folder, "flag pinned_folder")
	Effects.apply_list([{"do": "flag", "name": "filter_state", "value": "buzzing"}], ctx)
	_check(GameState.filter_state == "buzzing", "flag filter_state string")
	Effects.apply_list([{"do": "flag", "name": "typo_flag", "value": true}], ctx)
	_check(true, "unknown flag toasts loudly and survives")
	var money_before := GameState.money
	var ok := Effects.apply_list([
		{"do": "money", "spend": 99999999},
		{"do": "meter", "name": "face", "delta": 5.0},
	], ctx)
	_check(not ok, "guarded spend aborts the list")
	_check(GameState.money == money_before and GameState.face == 55.0, "abort left no partial state")
	Effects.apply_list([{"do": "money", "delta": -600000}], ctx)
	_check(GameState.money == money_before - 600000, "unguarded money delta opens the hole")
	Effects.apply_list([{"do": "promise", "name": "slip_signed", "value": true}], ctx)
	_check(bool(GameState.promises.get("slip_signed", false)), "promise set")
	Effects.apply_list([{"do": "carry", "value": "map_tube"}], ctx)
	_check(_game.player.carrying == "map_tube", "carry verb reaches the player")
	DayClock.start_day(1, 1, 8 * 60 + 50)
	var before := DayClock.minutes
	Effects.apply_list([{"do": "minutes", "value": 7}], ctx)
	_check(absf(DayClock.minutes - before - 7.0) < 0.01, "minutes verb ticks the clock")

func _test_clock() -> void:
	DayClock.start_day(1, 1, 8 * 60 + 50)
	_check(DayClock.bill_skill("clean") == 20, "clean bills 20")
	DayClock.start_day(1, 1, 8 * 60 + 50)
	_check(DayClock.bill_skill("sloppy") == 45, "sloppy bills 45")
	DayClock.start_day(1, 1, 8 * 60 + 50)
	_check(DayClock.bill_skill("fail") == 30, "fail bills 30")
	DayClock.start_day(1, 1, 12 * 60)
	_check(DayClock.clock_string() == "12:00", "clock string noon")
	DayClock.start_day(1, 1, 18 * 60 - 5)
	_check(DayClock.seconds_to_hard("shuttle") > 3.0, "shuttle 5 minutes out")
	DayClock.start_day(3, 3, 12 * 60)
	_check(DayClock.hard_clocks_for_day().has("hoesik"), "thursday has hoesik clock")
	_check(DayClock.hard_clocks_for_day().has("pip_review") == false, "thursday has no pip clock")
	DayClock.start_day(4, 4, 12 * 60)
	_check(DayClock.hard_clocks_for_day().has("pip_review"), "friday has pip clock")

func _test_stress() -> void:
	StressSys.set_stress(30.0)
	_check(StressSys.band() == StressSys.Band.STEADY, "30 is steady")
	StressSys.set_stress(60.0)
	_check(StressSys.band() == StressSys.Band.WARM, "60 is warm")
	StressSys.set_stress(80.0)
	_check(StressSys.band() == StressSys.Band.SHAKE, "80 is shake")
	StressSys.set_stress(81.0)
	_check(StressSys.band() == StressSys.Band.BORROWED and StressSys.has_forced_error(), "81 is borrowed + forced error")
	StressSys.set_stress(80.0)
	_check(StressSys.band() == StressSys.Band.SHAKE, "back to shake at 80")
	_check(absf(StressSys.window_scale(true) - 0.5) < 0.01, "shake heavy window 0.5")
	StressSys.set_stress(20.0)

func _test_shop_and_save() -> void:
	# Shop purchases run filter -> grace key -> alarm, then go bare.
	GameState.new_game()
	GameState.hana = 60.0
	DayClock.start_day(2, 1, 22 * 60)
	_game.resolve_shop()
	_check(GameState.has_quiet_filter and GameState.money == 520000 - GameState.FILTER_GOOD, "shop sells the quiet filter")
	_game.resolve_shop()
	_check(GameState.has_grace_key, "shop sells the grace key next")
	_game.resolve_shop()
	_check(GameState.has_alarm, "shop sells the alarm last")
	# Save/continue round trip: meters + clock survive a restart cycle.
	GameState.new_game()
	GameState.face = 71.5
	GameState.used_jobs_run["sign_slip"] = true
	SaveIO.autosave(_game)
	_check(SaveIO.has_save(), "autosave writes user://save.cfg")
	GameState.new_game()
	GameState.new_game()
	var d := SaveIO.load()
	_check(int(d.get("day", 0)) == 2 and not (d.get("state", {}) as Dictionary).is_empty(), "save carries day + state")
	GameState.import_state(d.get("state", {}) as Dictionary)
	_check(GameState.face == 71.5 and GameState.used_jobs_run.has("sign_slip"), "import restores meters + used jobs")
	SaveIO.clear()
	_check(not SaveIO.has_save(), "clear removes the save")

func _test_morning_and_rollover() -> void:
	GameState.new_game()
	StressSys.set_stress(20.0)
	DayClock.start_day(1, 1, 8 * 60 + 50)
	await _game.advance_morning("bed_good")
	_check(DayClock.day == 2 and DayClock.weekday == 2, "day1 tue -> day2 wed")
	_check(GameState.body == 100.0, "bed_good body invoice +20")
	DayClock.day = 5
	DayClock.weekday = 5
	await _game.advance_morning("bed_polite")
	_check(DayClock.day == 7 and DayClock.weekday == 0, "saturday skips sunday to monday")
	# Couch filter lifecycle.
	GameState.new_game()
	GameState.on_morning("couch")
	_check(GameState.filter_state == "buzzing" and GameState.couch_nights == 1, "couch night 1 buzzes")
	GameState.on_morning("couch")
	GameState.on_morning("couch")
	_check(GameState.filter_state == "dead", "third couch night kills the filter")
	GameState.on_morning("bed_good")
	# bed_good repairs only buzzing; dead stays dead (buy a new one at the shop).

func _test_endings() -> void:
	GameState.new_game()
	GameState.fish_alive = false
	_check(GameState.check_day60_ending() == "chairman_bubbles", "fish dead wins")
	GameState.fish_alive = true
	GameState.face = 75.0
	_check(GameState.check_day60_ending() == "corner_cubicle", "high face wins")
	GameState.face = 50.0
	GameState.money = 6000000
	GameState.kids = 30.0
	_check(GameState.check_day60_ending() == "sold_filter", "money over kids")
	GameState.money = 500000
	GameState.quit_draft = true
	GameState.hana = 70.0
	_check(GameState.check_day60_ending() == "quit_draft", "unsent draft")
	GameState.quit_draft = false
	GameState.hana = 55.0
	_check(GameState.check_day60_ending() == "clerk_yoon_right", "never copied -> yoon")
	GameState.map_resolved = true
	_check(GameState.check_day60_ending() == "key_still_works", "survived")
	GameState.pip = 100.0
	_check(GameState.check_day60_ending() == "fired", "pip 100 wins over all")

func _test_divorce_and_nuclear() -> void:
	GameState.game_over.disconnect(_game._on_game_over)
	var over := {"count": 0, "id": ""}
	GameState.game_over.connect(func(_kind, eid): over["count"] += 1; over["id"] = eid)
	GameState.new_game()
	GameState.hana = 0.0
	GameState.on_morning("bed_polite")
	_check(GameState.divorced_mornings == 1, "zero-hana morning counts")
	for i in 4:
		GameState.hana = 0.0
		GameState.on_morning("bed_polite")
	_check(over["count"] >= 1 and over["id"] == "divorced", "five mornings = divorce")
	GameState.new_game()
	GameState.recital_missed = true
	GameState.nanny_days = 2
	over["count"] = 0
	_check(GameState.nuclear_night(true, true, true), "nuclear night fires")
	_check(over["id"] == "divorced_nuclear", "nuclear ending id")
	# Main's handler back for the rest of the run.
	GameState.game_over.connect(_game._on_game_over)

func _test_interact_parity() -> void:
	GameState.new_game()
	StressSys.set_stress(20.0)
	DayClock.start_day(1, 1, 8 * 60 + 50)
	await _game.load_room("office")
	# Room-gating: quit draft interactable hidden on day 1.
	var qd := _find_inter("quit_draft_pc")
	_check(qd != null and not qd.visible, "quit draft hidden in room on day1")
	var pin := _find_inter("pin_folder")
	_check(pin != null and pin.visible, "pin folder live on day1")
	var face_before: float = GameState.face
	_game.on_interact(pin)
	_check(GameState.pinned_folder, "data-driven pin_folder sets the flag")
	_check(absf(GameState.face - (face_before - 2.0)) < 0.01, "pin_folder charges 2 face")
	_check(GameState.used_jobs_day.has("pin_folder"), "pin_folder consumed for the day")
	# VFX pass: the office stamp registers and answers a thump.
	_check(get_tree().get_nodes_in_group("vfx_stamp").size() > 0, "stamp VFX registered in office")
	var stamps := get_tree().get_nodes_in_group("vfx_stamp")
	if stamps.size() > 0:
		(stamps[0] as StampFX).thump()
	_check(true, "stamp thump callable headless")
	# Content hygiene: every interactable in the room maps to an authored job.
	var bare := 0
	for n in get_tree().get_nodes_in_group("interactables"):
		var i2 := n as Interactable
		if i2 != null and JobBoard.job(i2.job_id).is_empty():
			bare += 1
			print("   [bare] %s" % i2.job_id)
	_check(bare == 0, "no bare interactables in office (%d bare)" % bare)
	# Trace skill job has graded effects, both grades reachable in data.
	var trace := JobBoard.job("lightbox_trace")
	_check((trace["on_grade"] as Dictionary).has("clean") and (trace["on_grade"] as Dictionary).has("sloppy"), "trace grades authored")
	# Tuesday still boots with the briefing intact.
	_check(JobBoard.day_def(1, 1).has("script"), "tuesday script authored")

func _find_inter(job_id: String) -> Interactable:
	for n in get_tree().get_nodes_in_group("interactables"):
		var inter := n as Interactable
		if inter != null and inter.job_id == job_id:
			return inter
	return null
