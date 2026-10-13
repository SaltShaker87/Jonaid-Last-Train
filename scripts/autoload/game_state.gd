extends Node
## GameState autoload — GDD §12, §13.
## Six visible meters + two hidden. Promises are objects, not bare flags.
## Losses: fired (PIP 100) / divorced (Hana 0 five mornings or nuclear night).

signal meters_changed
signal game_over(kind: String, ending_id: String)
signal toast(text: String)

var hana: float = 60.0
var kids: float = 60.0
var face: float = 50.0
var body: float = 80.0
var money: int = 520000
var pip: float = 10.0          # hidden
var jealousy: float = 0.0      # hidden
var divorced_mornings: int = 0
var fish_alive: bool = true
var filter_state: String = "ok"  # ok | buzzing | dead
var smell_beer: bool = false
var has_map_tube: bool = false
var map_resolved: bool = false   # handed back / copied / traced
var map_legal_flag: bool = false
var slides_filed: bool = false
var sora_sniped: bool = false
var pinned_folder: bool = false
var carry_item: String = ""      # "", "map_tube", "whiskey", "jun"
var promises: Dictionary = {}    # e.g. {"recital": false, "slip_signed": false}
var nanny_days: int = 0
var has_grace_key: bool = false
var has_alarm: bool = false
var has_quiet_filter: bool = false
var sleep_place: String = ""     # bed_good | bed_polite | couch | away
var day_count: int = 1
var ended: bool = false
var recital_missed: bool = false  # Thursday hoesik deletes the recital
var quit_draft: bool = false       # week 2+ PC: resignation, unsent
var couch_nights: int = 0          # three couch nights kill the filter
var day_script: Array = []         # today's script lines (phone texture)
var used_jobs_day: Dictionary = {} # once-per-day consume
var used_jobs_run: Dictionary = {} # once-per-run consume

const FOOD_TRANSIT := 18000
const TAXI := 42000
const BEER := 14000
const NANNY_WEEK := 280000
const FILTER_GOOD := 90000
const FILTER_COUCH := 35000
const GRACE_KEY := 55000
const ALARM := 30000
const NEW_FISH := 15000
const G90_DEPOSIT := 600000

func new_game() -> void:
	hana = 60.0; kids = 60.0; face = 50.0; body = 80.0
	money = 520000; pip = 10.0; jealousy = 0.0
	divorced_mornings = 0; fish_alive = true; filter_state = "ok"
	smell_beer = false; has_map_tube = false; map_resolved = false
	map_legal_flag = false; slides_filed = false; sora_sniped = false
	pinned_folder = false; carry_item = ""
	promises = {"recital": false, "slip_signed": false, "shuttle": false}
	nanny_days = 0; has_grace_key = false; has_alarm = false
	has_quiet_filter = false; sleep_place = ""; day_count = 1; ended = false
	recital_missed = false; quit_draft = false; couch_nights = 0
	day_script = []
	used_jobs_day.clear(); used_jobs_run.clear()
	StressSys.set_stress(20.0)
	meters_changed.emit()

func add_hana(v: float) -> void:
	hana = clampf(hana + v, 0.0, 100.0)
	meters_changed.emit()
	_check_divorce_morning()

func add_kids(v: float) -> void:
	kids = clampf(kids + v, 0.0, 100.0)
	meters_changed.emit()

func add_face(v: float) -> void:
	face = clampf(face + v, 0.0, 100.0)
	meters_changed.emit()

func add_body(v: float) -> void:
	body = clampf(body + v, 0.0, 100.0)
	meters_changed.emit()

func add_pip(v: float) -> void:
	pip = clampf(pip + v, 0.0, 100.0)
	meters_changed.emit()
	if pip >= 100.0 and not ended:
		ended = true
		game_over.emit("fired", "fired")

func add_jealousy(v: float) -> void:
	jealousy = clampf(jealousy + v, 0.0, 100.0)
	meters_changed.emit()

func spend(v: int) -> bool:
	if money < v:
		toast.emit("Not enough won. Overtime pays next Friday.")
		return false
	money -= v
	meters_changed.emit()
	return true

func earn(v: int) -> void:
	money += v
	meters_changed.emit()

func _check_divorce_morning() -> void:
	# Hana at zero on a morning increments the count. Five mornings = divorce.
	if hana <= 0.0:
		divorced_mornings += 1
		if divorced_mornings >= 5 and not ended:
			ended = true
			game_over.emit("divorced", "divorced")
	else:
		divorced_mornings = max(0, divorced_mornings - 1)

func on_morning(sleep: String) -> void:
	sleep_place = sleep
	# Body / stress invoice per GDD §11
	match sleep:
		"bed_good":
			StressSys.set_stress(10.0)
			add_body(20.0)
			if filter_state == "buzzing":
				filter_state = "ok"  # the good cabinet fixes the hum
		"bed_polite":
			StressSys.set_stress(25.0)
			add_body(12.0)
		"couch":
			StressSys.set_stress(maxf(StressSys.value - 10.0, 30.0))
			add_body(-15.0)
			couch_nights += 1
			if couch_nights >= 3:
				filter_state = "dead"
				toast.emit("Third couch night. The filter whines down and quits. Bubbles will notice.")
			else:
				filter_state = "buzzing"
		"away":
			StressSys.add(10.0)
			add_body(-20.0)
	_check_divorce_morning()
	meters_changed.emit()

func nuclear_night(recital_missed: bool, nanny_home: bool, first_train: bool) -> bool:
	if recital_missed and nanny_home and first_train and not ended:
		ended = true
		game_over.emit("divorced", "divorced_nuclear")
		return true
	return false

func check_day60_ending() -> String:
	# GDD §13 day-60 endings, most specific first. The honest non-copy path
	# is rarer and better than merely surviving.
	if pip >= 100.0:
		return "fired"
	if hana <= 0.0:
		return "divorced"
	if not fish_alive:
		return "chairman_bubbles"
	if face >= 70.0:
		return "corner_cubicle"
	if money >= 5000000 and kids < 40.0:
		return "sold_filter"
	if quit_draft and hana >= 60.0:
		return "quit_draft"
	if not map_resolved and not map_legal_flag:
		return "clerk_yoon_right"
	if hana >= 50.0 and pip <= 30.0 and fish_alive:
		return "key_still_works"
	return "key_still_works"

func cabinet_state() -> String:
	# Good cabinet opens if affection >= 40 and arrived before kids' door shut.
	if hana >= 40.0:
		return "good"
	return "polite"

func can_sprint() -> bool:
	return StressSys.can_sprint(body)

## Save surface: explicit keys, typed back on import. Day-agnostic content
## means a save stores meters/flags, not the authored world.
func export_state() -> Dictionary:
	return {
		"hana": hana, "kids": kids, "face": face, "body": body,
		"money": money, "pip": pip, "jealousy": jealousy,
		"divorced_mornings": divorced_mornings, "fish_alive": fish_alive,
		"filter_state": filter_state, "smell_beer": smell_beer,
		"has_map_tube": has_map_tube, "map_resolved": map_resolved,
		"map_legal_flag": map_legal_flag, "slides_filed": slides_filed,
		"sora_sniped": sora_sniped, "pinned_folder": pinned_folder,
		"carry_item": carry_item, "promises": promises.duplicate(),
		"nanny_days": nanny_days, "has_grace_key": has_grace_key,
		"has_alarm": has_alarm, "has_quiet_filter": has_quiet_filter,
		"sleep_place": sleep_place, "day_count": day_count, "ended": ended,
		"recital_missed": recital_missed, "quit_draft": quit_draft,
		"couch_nights": couch_nights,
		"used_jobs_day": used_jobs_day.duplicate(),
		"used_jobs_run": used_jobs_run.duplicate(),
	}

func import_state(d: Dictionary) -> void:
	hana = float(d.get("hana", hana))
	kids = float(d.get("kids", kids))
	face = float(d.get("face", face))
	body = float(d.get("body", body))
	money = int(d.get("money", money))
	pip = float(d.get("pip", pip))
	jealousy = float(d.get("jealousy", jealousy))
	divorced_mornings = int(d.get("divorced_mornings", divorced_mornings))
	fish_alive = bool(d.get("fish_alive", fish_alive))
	filter_state = String(d.get("filter_state", filter_state))
	smell_beer = bool(d.get("smell_beer", smell_beer))
	has_map_tube = bool(d.get("has_map_tube", has_map_tube))
	map_resolved = bool(d.get("map_resolved", map_resolved))
	map_legal_flag = bool(d.get("map_legal_flag", map_legal_flag))
	slides_filed = bool(d.get("slides_filed", slides_filed))
	sora_sniped = bool(d.get("sora_sniped", sora_sniped))
	pinned_folder = bool(d.get("pinned_folder", pinned_folder))
	carry_item = String(d.get("carry_item", carry_item))
	if d.has("promises"):
		promises = (d["promises"] as Dictionary).duplicate()
	nanny_days = int(d.get("nanny_days", nanny_days))
	has_grace_key = bool(d.get("has_grace_key", has_grace_key))
	has_alarm = bool(d.get("has_alarm", has_alarm))
	has_quiet_filter = bool(d.get("has_quiet_filter", has_quiet_filter))
	sleep_place = String(d.get("sleep_place", sleep_place))
	day_count = int(d.get("day_count", day_count))
	ended = bool(d.get("ended", ended))
	recital_missed = bool(d.get("recital_missed", recital_missed))
	quit_draft = bool(d.get("quit_draft", quit_draft))
	couch_nights = int(d.get("couch_nights", couch_nights))
	if d.has("used_jobs_day"):
		used_jobs_day = (d["used_jobs_day"] as Dictionary).duplicate()
	if d.has("used_jobs_run"):
		used_jobs_run = (d["used_jobs_run"] as Dictionary).duplicate()
	StressSys.set_stress(maxf(StressSys.value, 10.0))
	meters_changed.emit()
