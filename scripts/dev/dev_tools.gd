class_name DevTools
extends Node
## Debug-build helpers. F5 +60 game minutes, F6 +20 stress, F7 -20 stress,
## F8 +20 Hana anger, F9 Park assigns a task now. `-- --shots=DIR` runs a scripted tour and saves
## screenshots, then quits (used to eyeball the game from the command line).

var game: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_tour(a.substr(8))


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey) or not event.is_pressed():
		return
	match (event as InputEventKey).keycode:
		KEY_F5:
			Clock.advance(60.0)
			Game.notify("[dev] +60 min -> %s" % Clock.now_string())
		KEY_F6:
			Stress.add(20.0)
		KEY_F7:
			Stress.relieve(20.0)
		KEY_F8:
			Game.add_anger(20.0)
		KEY_F9:
			Tasks.spawn()


func _shot(dir: String, n: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, n])
	print("[shots] ", n)


func _tour(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var p: Player = game.player
	await get_tree().create_timer(2.5).timeout
	await _shot(dir, "00_title")
	game.start_run()
	await get_tree().create_timer(3.8).timeout
	await _shot(dir, "01_office_spawn")
	p.yaw = PI * 0.15
	p.pitch = -0.2
	Tasks.spawn()
	Tasks.spawn()
	await get_tree().create_timer(0.8).timeout
	await _shot(dir, "02_office_look")
	await _minigame_shots(dir)
	p.global_position = Vector3(4.3, 0.1, 6.6)
	p.yaw = 0.0
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "03_jonaid_desk")
	# A real station opening its minigame.
	Tasks.spawn("", "copier_jam")
	p.global_position = Vector3(-9.7, 0.1, 2.5)
	p.yaw = PI * 0.5
	await get_tree().create_timer(0.3).timeout
	game.location.get_node("Interactables/Copier").interact(p)
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "03b_station_copier")
	game.minigames.abort()
	p.global_position = Vector3(-6.5, 0.1, -2.2)
	p.yaw = PI * 0.25
	Game.say(p, "Is this text readable? It's a speech bubble now. Not floating 3D text.")
	await get_tree().create_timer(0.8).timeout
	await _shot(dir, "04_park_office")
	p.global_position = Vector3(4.6, 0.1, -11.2)
	p.yaw = PI
	game.location.get_node("Interactables/Ashtray").interact(p)
	Stress.add(50.0)
	await get_tree().create_timer(1.2).timeout
	await _shot(dir, "05_balcony_smoke")
	game.location._park_patrol()
	await get_tree().create_timer(10.6).timeout
	await _shot(dir, "05b_park_catches")
	p.cancel_action()
	Stress.reset(20.0)
	# Leave after 18:00 through the real elevator while Park is still in: nunchi.
	Clock.minutes = 18 * 60 + 5
	p.global_position = Vector3(-8.0, 0.1, 6.8)
	p.yaw = PI
	await get_tree().create_timer(0.3).timeout
	game.location.get_node("Interactables/Elevator").interact(p)
	await get_tree().create_timer(0.25).timeout
	await _shot(dir, "05c_nunchi")
	await get_tree().create_timer(1.6).timeout
	await _shot(dir, "06_street")
	p.global_position = Vector3(20.0, 0.1, 0.0)
	p.yaw = -PI * 0.6
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "07_street_mart")
	Game.travel("station", "from_street", 2.0)
	await get_tree().create_timer(1.6).timeout
	await _shot(dir, "08_station")
	Clock.minutes = 18 * 60 + 30
	p.global_position = Vector3(1.0, 0.1, 3.0)
	p.yaw = PI
	await get_tree().create_timer(4.5).timeout
	await _shot(dir, "09_train")
	Game.travel("home", "door", 26.0)
	await get_tree().create_timer(2.5).timeout
	await _shot(dir, "10_home_hana")
	p.global_position = Vector3(-2.0, 0.1, 0.0)
	p.yaw = PI * 0.5
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "11_home_living")
	Game.sleep()
	await get_tree().create_timer(1.4).timeout
	await _shot(dir, "11b_day2_card")
	await get_tree().create_timer(2.5).timeout
	await _shot(dir, "11c_day2_office")
	Stress.add(100.0)
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "12_meltdown")
	await get_tree().create_timer(3.0).timeout
	await _shot(dir, "13_game_over")
	get_tree().quit()


## Open each minigame once, poke it a little, screenshot, close.
func _minigame_shots(dir: String) -> void:
	var host: MinigameHost = game.minigames
	for g in ["word", "excel", "copier", "stamp", "coffee", "bow"]:
		var tpl: Dictionary = {}
		for t in Tasks._templates:
			if t["game"] == g:
				tpl = t
				break
		var task: Dictionary = tpl.duplicate(true)
		task["uid"] = -1
		task["due"] = Clock.minutes + 60.0
		host.open(task)
		await get_tree().create_timer(0.3).timeout
		if g == "word":
			for ch in "Dear Direktor":
				var e := InputEventKey.new()
				e.pressed = true
				e.unicode = ch.unicode_at(0)
				host.current._key(e)
		elif g == "excel":
			for ch in "12":
				var e := InputEventKey.new()
				e.pressed = true
				e.unicode = ch.unicode_at(0)
				host.current._key(e)
		await get_tree().create_timer(1.4 if g in ["stamp", "coffee"] else 0.5).timeout
		await _shot(dir, "mg_" + g)
		host.abort()
	# One real task, finished perfectly, to see the pay and the stamp.
	var t := Tasks.spawn()
	await get_tree().create_timer(0.4).timeout
	Tasks.complete(t, "perfect")
	await get_tree().create_timer(0.3).timeout
	await _shot(dir, "02b_task_done")
