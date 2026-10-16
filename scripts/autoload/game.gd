extends Node
## Run state (money, Hana's anger, score) and the message bus the world uses
## to talk to Main and the HUD without knowing about them.

signal money_changed(value: int, delta: int)
signal anger_changed(value: float, delta: float)
signal travel_requested(location: String, spawn: String, minutes: float)
signal say_requested(speaker: Node3D, text: String, seconds: float)
signal notify_requested(text: String)
signal run_ended(cause: String)
signal sleep_requested

const ANGER_MAX := 100.0
const SAVE_PATH := "user://highscore.cfg"

## Anger tiers when Jonaid gets home (DESIGN.md "Home").
const TIER_HAPPY := 0
const TIER_ANNOYED := 1
const TIER_ANGRY := 2
const TIER_FURIOUS := 3
const TIER_ANGER := [-10.0, 15.0, 30.0, 45.0]

var money := 0
var anger := 0.0
var promised := 19 * 60 + 30  ## when Hana expects him home today
var took_taxi := false
var in_run := false
var stats := {}
var best_days := 0
var best_money := 0


func _ready() -> void:
	_load_best()


func new_run() -> void:
	money = 0
	anger = 0.0
	took_taxi = false
	in_run = true
	stats = {"days": 0, "earned": 0, "tasks_done": 0, "tasks_failed": 0, "smokes": 0, "trains_missed": 0}
	Stress.reset(5.0)
	money_changed.emit(money, 0)
	anger_changed.emit(anger, 0.0)


func earn(amount: int) -> void:
	money += amount
	stats["earned"] = int(stats.get("earned", 0)) + amount
	money_changed.emit(money, amount)


## Spends if possible. Returns false (and spends nothing) when broke.
func spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money, -amount)
	return true


func add_anger(amount: float) -> void:
	var before := anger
	anger = clampf(anger + amount, 0.0, ANGER_MAX)
	anger_changed.emit(anger, anger - before)


func lateness_tier(arrival: float) -> int:
	var late := arrival - float(promised)
	if took_taxi or late > 90.0:
		return TIER_FURIOUS
	if late > 30.0:
		return TIER_ANGRY
	if late > 0.0:
		return TIER_ANNOYED
	return TIER_HAPPY


func bump(stat: String, by: int = 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + by


# ---------------------------------------------------------------- bus helpers

func travel(location: String, spawn: String, minutes: float = 0.0) -> void:
	travel_requested.emit(location, spawn, minutes)


func say(speaker: Node3D, text: String, seconds: float = 3.5) -> void:
	say_requested.emit(speaker, text, seconds)


func notify(text: String) -> void:
	notify_requested.emit(text)


func sleep() -> void:
	sleep_requested.emit()


func end_run(cause: String) -> void:
	if not in_run:
		return
	in_run = false
	var days := int(stats.get("days", 0))
	if days > best_days or (days == best_days and int(stats.get("earned", 0)) > best_money):
		best_days = days
		best_money = int(stats.get("earned", 0))
		_save_best()
	run_ended.emit(cause)


# ---------------------------------------------------------------- high score

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_days = int(cfg.get_value("best", "days", 0))
		best_money = int(cfg.get_value("best", "money", 0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("best", "days", best_days)
	cfg.set_value("best", "money", best_money)
	cfg.save(SAVE_PATH)


static func won(amount: int) -> String:
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if amount < 0 else "") + "₩" + s + out
