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

const FOOD_TRANSIT := 18000
const TAXI := 42000
const BEER := 14000
const NANNY_WEEK := 280000
const FILTER_GOOD := 90000
const FILTER_COUCH := 35000
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
	# Called each morning; Hana at zero increments. Five mornings = divorce.
	pass

func on_morning(sleep: String) -> void:
	sleep_place = sleep
	if hana <= 0.0:
		divorced_mornings += 1
	else:
		divorced_mornings = max(0, divorced_mornings - 1)
	# Body / stress invoice per GDD §11
	match sleep:
		"bed_good":
			StressSys.set_stress(10.0)
			add_body(20.0)
		"bed_polite":
			StressSys.set_stress(25.0)
			add_body(12.0)
		"couch":
			StressSys.set_stress(maxf(StressSys.value - 10.0, 30.0))
			add_body(-15.0)
			filter_state = "buzzing"
		"away":
			StressSys.add(10.0)
			add_body(-20.0)
	if divorced_mornings >= 5 and not ended:
		ended = true
		game_over.emit("divorced", "divorced")
	meters_changed.emit()

func nuclear_night(recital_missed: bool, nanny_home: bool, first_train: bool) -> bool:
	if recital_missed and nanny_home and first_train and not ended:
		ended = true
		game_over.emit("divorced", "divorced_nuclear")
		return true
	return false

func check_day60_ending() -> String:
	# GDD §13 day-60 endings if both tracks lived.
	if pip >= 100.0:
		return "fired"
	if hana <= 0.0:
		return "divorced"
	if not fish_alive:
		return "chairman_bubbles"
	if face >= 70.0:
		return "corner_cubicle"
	if money >= 600000 and kids < 40.0:
		return "sold_filter"
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
