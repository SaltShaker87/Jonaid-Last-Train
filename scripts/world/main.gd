extends Node
## Main — day loop in space (GDD §9), losses/endings (§13), UI glue (§15).
## Third person in world, first person only for lightbox + slides.
## World clock runs while walking/typing. Skills freeze + bill on exit.
##
## Content is data: data/jobs/catalog.json + data/jobs/days/*.json.
## This file owns only (a) the engine loop, (b) verbs that are genuinely
## procedural (shuttle/dash/hoesik/shop/sleep/resolutions), (c) save.

var world_root: Node3D
var player: Salaryman
var hud: HUD
var phone: PhoneUI
var menu: MainMenu
var ending: EndingScreen
var fade: ColorRect
var skill_layer: CanvasLayer
var pause_layer: CanvasLayer

var trace_skill: TraceSkill
var bow_skill: HoldSkill
var crop_skill: HoldSkill
var prime_skill: HoldSkill
var pour_beer_skill: HoldSkill
var digits_g90: DigitsSkill
var digits_sign: DigitsSkill
var slides_skill: SlidesSkill
var kakao_skill: KakaoSkill
var dash_skill: DashSkill

var current_room: RoomBase = null
var current_room_id := ""
var active_skill: SkillBase = null
var active_inter: Interactable = null
var audio_players: Dictionary = {}
var hoesik_refused_once := false

var _paused := false

const ROOM_SCRIPTS := {
	"office": "res://scripts/world/room_office.gd",
	"street": "res://scripts/world/room_street.gd",
	"station": "res://scripts/world/room_station.gd",
	"apartment": "res://scripts/world/room_apartment.gd",
	"restaurant": "res://scripts/world/room_restaurant.gd",
}

func _ready() -> void:
	add_to_group("game")
	_build_chrome()
	DayClock.hard_event.connect(_on_hard)
	GameState.game_over.connect(_on_game_over)
	menu.new_game_pressed.connect(start_new_game)
	menu.continue_pressed.connect(continue_game)
	# Headless smoke path: allow --auto-test to boot without menu.
	if "--auto-test" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		start_new_game()
		TestRig.attach(self)
	# Scripted multi-day playtest: --sim
	if "--sim" in OS.get_cmdline_args():
		start_new_game()
		Playthrough.start(self)
	# 40s capture: -- --capture (needs rendering; headless prints dry-run).
	if "--capture" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_args():
		start_new_game()
		Director.maybe_attach(self)

func _build_chrome() -> void:
	world_root = Node3D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.9
	add_child(sun)
	var amb := WorldEnvironment.new()
	amb.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.06, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.44, 0.42)
	env.ambient_light_energy = 0.7
	amb.environment = env
	add_child(amb)
	player = Salaryman.new()
	player.name = "Jonaid"
	player.add_to_group("player")
	add_child(player)
	player.interact_target_changed.connect(_on_target_changed)
	player.move_enabled = false
	skill_layer = CanvasLayer.new()
	skill_layer.name = "SkillLayer"
	skill_layer.layer = 20
	add_child(skill_layer)
	trace_skill = TraceSkill.create()
	bow_skill = HoldSkill.create("BOW")
	crop_skill = HoldSkill.create("CROP MASK")
	prime_skill = HoldSkill.create("PRIME")
	pour_beer_skill = HoldSkill.create("POUR")
	digits_g90 = DigitsSkill.create("G90")
	digits_sign = DigitsSkill.create("SIGN")
	slides_skill = SlidesSkill.create()
	kakao_skill = KakaoSkill.create()
	dash_skill = DashSkill.create()
	for s in [trace_skill, bow_skill, crop_skill, prime_skill, pour_beer_skill, digits_g90, digits_sign, slides_skill, kakao_skill, dash_skill]:
		(s as Control).visible = false
		skill_layer.add_child(s)
	hud = HUD.create()
	add_child(hud)
	phone = PhoneUI.create(kakao_skill)
	add_child(phone)
	menu = MainMenu.create()
	add_child(menu)
	ending = EndingScreen.create()
	add_child(ending)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := CanvasLayer.new()
	cl.layer = 40
	cl.add_child(fade)
	add_child(cl)
	pause_layer = PauseMenu.create(self)
	add_child(pause_layer)
	_setup_audio()

func _setup_audio() -> void:
	# GDD §16 mix: announcement is the most expensive sound, then chime.
	# Office/apartment beds crossfade on badge-out (tween below in load_room).
	var levels := {"announce": 0.0, "chime": -4.0, "turnstile": -8.0, "jam": -8.0, "ping": -10.0, "buzz": -14.0}
	for n in ["chime", "ping", "buzz", "announce", "turnstile", "jam"]:
		var p := AudioStreamPlayer.new()
		p.name = "Audio_" + n
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			p.stream = load(path) as AudioStream
		p.volume_db = float(levels.get(n, -6.0))
		add_child(p)
		audio_players[n] = p
	# Beds: dedicated looping wavs so the one-shot SFX stay one-shot.
	for bed in ["bed_office", "bed_home"]:
		var b := AudioStreamPlayer.new()
		b.name = "Bed_" + bed
		var bp := "res://assets/audio/%s.wav" % bed
		if ResourceLoader.exists(bp):
			b.stream = load(bp) as AudioStream
		b.volume_db = -28.0
		add_child(b)
		audio_players[bed] = b
	(audio_players["bed_office"] as AudioStreamPlayer).play()

func play_audio(n: String) -> void:
	if audio_players.has(n):
		var p := audio_players[n] as AudioStreamPlayer
		if p != null and p.stream != null:
			p.play()

## Content-facing VFX hook (GDD §16 pass): catalog effects call
## {"do":"vfx","name":"stamp_thump"} and the visible prop answers.
func vfx(name: String) -> void:
	match name:
		"stamp_thump":
			for n in get_tree().get_nodes_in_group("vfx_stamp"):
				if n is StampFX:
					(n as StampFX).thump()
		"doors_shut":
			for n in get_tree().get_nodes_in_group("vfx_door"):
				if n is DoorFX:
					(n as DoorFX).close()

func _crossfade_beds(to_home: bool) -> void:
	var office := audio_players.get("bed_office") as AudioStreamPlayer
	var home := audio_players.get("bed_home") as AudioStreamPlayer
	if office == null or home == null:
		return
	if not office.playing:
		office.play()
	if not home.playing:
		home.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(office, "volume_db", -28.0 if to_home else -14.0, 1.2)
	tw.tween_property(home, "volume_db", -14.0 if to_home else -28.0, 1.2)

func start_new_game() -> void:
	GameState.new_game()
	SaveIO.clear()
	DayClock.start_day(1, 1, 8 * 60 + 50)
	hoesik_refused_once = false
	menu.hide_menu()
	_paused = false
	get_tree().paused = false
	pause_layer.visible = false
	player.move_enabled = true
	player.set_carry("")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not OS.has_feature("web") else Input.MOUSE_MODE_VISIBLE
	load_room("office")
	hud.show_toast("08:50 Tuesday. Tube on the desk. Folder unpinned. Harin's slip in your bag.")
	_day_briefing()

func continue_game() -> void:
	var d := SaveIO.load()
	if d.is_empty():
		start_new_game()
		return
	GameState.import_state(d.get("state", {}) as Dictionary)
	menu.hide_menu()
	_paused = false
	get_tree().paused = false
	pause_layer.visible = false
	player.move_enabled = true
	player.set_carry(GameState.carry_item)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not OS.has_feature("web") else Input.MOUSE_MODE_VISIBLE
	DayClock.start_day(int(d.get("day", 1)), int(d.get("weekday", 1)), float(d.get("minutes", 8 * 60 + 50)))
	load_room("office")
	_day_briefing()
	hud.show_toast("Continued — Day %d %s." % [DayClock.day, DayClock.weekday_name()])

func _day_briefing() -> void:
	var dd := JobBoard.day_def(DayClock.day, DayClock.weekday)
	var line := String(dd.get("briefing", ""))
	if line != "":
		hud.show_toast(line)
		GameState.day_script = dd.get("script", [])

func toggle_pause() -> void:
	if menu.menu_open or ending.visible:
		return
	_paused = not _paused
	get_tree().paused = _paused
	pause_layer.visible = _paused
	player.move_enabled = not _paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _paused else Input.MOUSE_MODE_CAPTURED

func quit_to_title() -> void:
	get_tree().paused = false
	_paused = false
	get_tree().reload_current_scene()

func load_room(room_id: String, socket_name: String = "spawn") -> void:
	if not ROOM_SCRIPTS.has(room_id):
		return
	_fade_to(1.0)
	await get_tree().create_timer(0.25).timeout
	if current_room != null:
		current_room.queue_free()
		current_room = null
	var scr := load(ROOM_SCRIPTS[room_id]) as GDScript
	current_room = scr.new() as RoomBase
	current_room_id = room_id
	world_root.add_child(current_room)
	# Room _ready builds content; wait a frame for sockets.
	await get_tree().process_frame
	current_room.set_player_spawn(player, socket_name)
	# Day-gating: interactables whose job is off today are hidden + disabled.
	JobBoard.apply_gating(current_room, DayClock.day, DayClock.weekday)
	_apply_room_art(room_id)
	_fade_to(0.0)
	hud.refresh_board()

func _apply_room_art(room_id: String) -> void:
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	# _build_chrome adds WorldEnvironment without a name; find it.
	if env_node == null:
		for c in get_children():
			if c is WorldEnvironment:
				env_node = c
				break
	if env_node != null and env_node.environment != null:
		ArtDirection.apply_room_lighting(current_room, room_id, env_node.environment)
	_crossfade_beds(room_id == "apartment" or room_id == "restaurant")

func _fade_to(a: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, 0.25)

func _on_target_changed(inter: Interactable) -> void:
	hud.set_prompt(inter)

func show_ending(kind: String, ending_id: String) -> void:
	player.move_enabled = false
	ending.show_ending(kind, ending_id)

# ---------------------------------------------------------------- interactions
## Everything below is data-driven: the job's JSON decides which list of
## effects fires. Engine verbs (resolve_*) stay here because they are the
## part that is genuinely procedural.

func on_interact(inter: Interactable) -> void:
	if active_skill != null or GameState.ended:
		return
	if not JobBoard.job_is_live(inter.job_id, DayClock.day, DayClock.weekday, current_room_id):
		return
	var job: Dictionary = JobBoard.job(inter.job_id)
	var ctx := {"game": self, "inter": inter, "grade": ""}
	# on_use fires immediately (minutes for the long walk, toasts, flags).
	Effects.apply_list(job.get("on_use", []), ctx)
	var skill_key := String(job.get("skill", ""))
	if skill_key != "" and skill_key != "none":
		open_skill(skill_key, inter)
	else:
		_mark_used(inter, job)

func _mark_used(inter: Interactable, job: Dictionary) -> void:
	if inter == null:
		return
	match String(job.get("once", "")):
		"day":
			GameState.used_jobs_day[inter.job_id] = true
			inter.disabled = true
			inter.visible = false
		"game":
			GameState.used_jobs_run[inter.job_id] = true
			inter.disabled = true
			inter.visible = false

func open_skill(skill_key: String, inter: Interactable) -> void:
	var sk := _skill_for_key(skill_key)
	if sk == null:
		return
	active_skill = sk
	active_inter = inter
	DayClock.frozen = true
	player.move_enabled = false
	if skill_key == "bow":
		(bow_skill as HoldSkill).carry_penalty = (player.carrying != "")
	sk.start(StressSys.value, DayClock.day * 100 + int(DayClock.minutes))
	if not sk.finished.is_connected(_on_skill_finished):
		sk.finished.connect(_on_skill_finished)
	# show on top
	(sk as Control).visible = true
	(sk as Control).move_to_front()

func open_skill_no_freeze(skill_key: String, _inter: Interactable) -> void:
	# Phone KakaoTalk: clock keeps running.
	var sk := _skill_for_key(skill_key)
	if sk == null:
		return
	active_skill = sk
	active_inter = null
	player.move_enabled = false
	sk.start(StressSys.value, DayClock.day * 100)
	if not sk.finished.is_connected(_on_skill_finished):
		sk.finished.connect(_on_skill_finished)
	(sk as Control).visible = true

func _skill_for_key(k: String) -> SkillBase:
	match k:
		"trace": return trace_skill
		"bow": return bow_skill
		"pour": return crop_skill
		"pour_prime": return prime_skill
		"pour_beer": return pour_beer_skill
		"digits_g90": return digits_g90
		"digits_sign": return digits_sign
		"slides": return slides_skill
		"kakao": return kakao_skill
		"dash": return dash_skill
	return null

func _on_skill_finished(grade: String) -> void:
	var sk := active_skill
	var inter := active_inter
	active_skill = null
	active_inter = null
	player.move_enabled = true
	var froze := not (sk == kakao_skill)
	if froze:
		DayClock.frozen = false
		var billed := DayClock.bill_skill(grade)
		GameState.toast.emit("Skill %s. Billed %d game-minutes (now %s)." % [grade, billed, DayClock.clock_string()])
	var job: Dictionary = {}
	if inter != null:
		job = JobBoard.job(inter.job_id)
	elif sk == kakao_skill:
		job = JobBoard.job("kakao")  # phone path: clock runs, graded from data
	var ctx := {"game": self, "inter": inter, "grade": grade}
	if job.is_empty():
		# No authored job (unknown inter): still costs a little calm.
		StressSys.add(3.0)
		GameState.toast.emit("Replies sent. The building clock ran while the phone was open.")
	else:
		if job.has("on_grade"):
			var og: Dictionary = job["on_grade"]
			Effects.apply_list(og[grade] if og.has(grade) else og.get("else", []), ctx)
		if job.has("on_finish"):
			Effects.apply_list(job["on_finish"], ctx)
		_mark_used(inter, job)
	hud.refresh_board()

# ---------------------------------------------------------------- engine verbs
## Called from JSON via {"do":"engine","name":"<verb>"}.

func sora_snipe() -> void:
	# Day 2+ or week 2+: Sora snipes the real pile if left unpinned.
	if DayClock.day >= 2 and not GameState.pinned_folder and not GameState.sora_sniped:
		GameState.sora_sniped = true
		GameState.add_pip(10.0)
		GameState.toast.emit("Sora sniped the real pile while it sat unpinned. Her bad number is in your pack.")

func resolve_shuttle() -> void:
	var t := DayClock.seconds_to_hard("shuttle")
	if t < -0.5:
		GameState.toast.emit("Missed the curb — the driver left. No skill. Pure time.")
		GameState.add_kids(-6.0)
		GameState.add_hana(-4.0)
		return
	if player.carrying == "map_tube":
		GameState.toast.emit("Badge out with the tube under your arm, drop it on Sora's desk — Jun collected.")
		player.set_carry("")
	else:
		GameState.toast.emit("Jun collected. Park's read receipt goes cold in your pocket.")
	GameState.add_kids(10.0)
	GameState.add_hana(6.0)
	GameState.promises["shuttle"] = true

func resolve_restaurant() -> void:
	if DayClock.weekday != 3:
		GameState.toast.emit("The hoesik table only seats on Thursday.")
		return
	if DayClock.minutes < 18 * 60:
		GameState.toast.emit("Not yet. The table seats at 19:00. The evening is long.")
		return
	DayClock.add_minutes(6)
	load_room("restaurant")
	GameState.toast.emit("Wrong direction from the station. The family train leaves at 19:40.")

func resolve_hoesik(grade: String) -> void:
	if not hoesik_refused_once and grade != "clean":
		hoesik_refused_once = true
		GameState.toast.emit("You refused the pour once. They noticed. The family train survives tonight.")
		return
	GameState.toast.emit("You poured. The restaurant is the wrong direction from the station. The train is gone by geography.")
	GameState.recital_missed = true
	StressSys.add(8.0)
	GameState.add_face(4.0)
	GameState.add_hana(-8.0)

func resolve_dash(grade: String) -> void:
	if grade == "clean":
		play_audio("chime")
		GameState.toast.emit("Clean line. Doors chimed and you were inside.")
		StressSys.add(6.0)
		# Family vs last train context decides destination.
		if DayClock.minutes < 20 * 60:
			load_room("apartment")
			DayClock.add_minutes(30)
		else:
			load_room("apartment")
	elif grade == "sloppy":
		play_audio("chime")
		StressSys.add(12.0)
		GameState.toast.emit("Stumble — you made it, barely. The suit remembers.")
		load_room("apartment")
	else:
		play_audio("announce")
		StressSys.add(16.0)
		GameState.toast.emit("Missed it. Doors shut in front of you. Taxi only after the doors shut (Q → 2).")

func resolve_prime(grade: String) -> void:
	if grade == "sloppy":
		GameState.fish_alive = DayClock.minutes < 24 * 60
		StressSys.add(6.0)
	else:
		if DayClock.minutes >= 24 * 60:
			GameState.fish_alive = false
			GameState.toast.emit("Missed the prime after midnight. Saturday is an empty tank.")
		StressSys.add(12.0)

func resolve_shop() -> void:
	# Good cabinet holds grace items. Couch sleep locks it (cabinet_state).
	if GameState.cabinet_state() != "good":
		GameState.toast.emit("Polite cabinet. Functional gear. No grace items. Couch sleep locks the good one.")
		return
	var bought := false
	if not GameState.has_quiet_filter:
		if GameState.spend(GameState.FILTER_GOOD):
			GameState.has_quiet_filter = true
			GameState.filter_state = "ok"
			GameState.toast.emit("Quiet filter ₩90,000. The hum leaves the bedroom.")
			bought = true
	elif not GameState.has_grace_key:
		if GameState.spend(GameState.GRACE_KEY):
			GameState.has_grace_key = true
			GameState.toast.emit("Grace key — one late arrival Park will not log.")
			bought = true
	elif not GameState.has_alarm:
		if GameState.spend(GameState.ALARM):
			GameState.has_alarm = true
			GameState.toast.emit("Alarm. Tomorrow you start on time.")
			bought = true
	if not bought:
		GameState.toast.emit("Good cabinet is bare. Everything that helps is already yours.")

func bedtime() -> void:
	if int(DayClock.minutes) % (24 * 60) > 21 * 60 + 30:
		GameState.toast.emit("Kids' door is shut. Hana in the kitchen doing accounting.")
	else:
		GameState.add_kids(8.0)
		GameState.add_hana(5.0)
		StressSys.relieve(10.0)
		GameState.toast.emit("Bedtime finished. Two interactions fit because you arrived early.")

func sleep_bed() -> void:
	var cab := GameState.cabinet_state()
	advance_morning("bed_good" if cab == "good" else "bed_polite")

func sleep_couch() -> void:
	advance_morning("couch")

func go_office_morning() -> void:
	advance_morning("away" if DayClock.minutes > 24 * 60 else "bed_polite")

func call_taxi() -> void:
	# Taxi prompt appears only after the doors have shut.
	var last := DayClock.seconds_to_hard("last_train")
	var fam := DayClock.seconds_to_hard("family_train")
	if last > 0.5 and fam > 0.5 and current_room_id == "station":
		GameState.toast.emit("Too early — the doors haven't shut. The skill is the path.")
		return
	if not GameState.spend(GameState.TAXI):
		return
	StressSys.relieve(8.0)
	GameState.add_body(-8.0)
	GameState.toast.emit("Taxi ₩42,000. Home at 00:40, office smell included.")
	DayClock.minutes = 24 * 60 + 40
	load_room("apartment")

func advance_morning(sleep: String) -> void:
	GameState.on_morning(sleep)
	if sleep == "couch":
		play_audio("buzz")
	if GameState.ended:
		return
	# Nuclear night: the recital was missed while the nanny covered and you
	# still got home. Every net present, one night, no appeal.
	if GameState.recital_missed and GameState.nanny_days > 0:
		GameState.nuclear_night(true, true, true)
		if GameState.ended:
			return
	GameState.day_count += 1
	DayClock.day += 1
	# Weekday advance: Tue(1)..Fri(4), Sat(5) short, Sun(6) skip to Mon(0).
	DayClock.weekday = (DayClock.weekday + 1) % 7
	if DayClock.weekday == 6:
		# Sunday: family day, small recovery, skip to Monday.
		GameState.add_hana(6.0)
		GameState.add_kids(8.0)
		DayClock.weekday = 0
		DayClock.day += 1
		GameState.day_count += 1
	GameState.recital_missed = false
	GameState.used_jobs_day.clear()
	if DayClock.day > 60:
		show_ending("day60", GameState.check_day60_ending())
		return
	# Friday salary. Overtime pays next Friday.
	if DayClock.weekday == 4:
		GameState.earn(2800000)
		GameState.toast.emit("Friday salary. Rent is a crisis, not an instant loss.")
	var start_min := 8 * 60 + 50
	if GameState.body < 25.0:
		start_min = 9 * 60 + 10  # wrecked body arrives late, Park started without you
	DayClock.start_day(DayClock.day, DayClock.weekday, start_min)
	GameState.pinned_folder = false
	GameState.sora_sniped = false
	GameState.slides_filed = false
	GameState.smell_beer = false
	player.set_carry("")
	hoesik_refused_once = false
	SaveIO.autosave(self)
	load_room("office")
	_day_briefing()

func _on_hard(event_id: String) -> void:
	match event_id:
		"shuttle":
			play_audio("ping")
			if current_room_id != "street":
				GameState.toast.emit("18:10 shuttle — you are not at the curb. The driver leaves.")
		"family_train":
			play_audio("chime")
			if current_room_id != "station" and current_room_id != "apartment":
				if current_room_id == "restaurant":
					GameState.toast.emit("19:40 family train — you are at the wrong table. Hana notices.")
				else:
					GameState.toast.emit("19:40 family train — you are in the wrong building. Hana notices.")
				GameState.add_hana(-6.0)
		"last_train":
			play_audio("announce")
			GameState.toast.emit("23:18 last train. Board flips to 05:12.")
		"hoesik":
			play_audio("ping")
			GameState.toast.emit("19:00 hoesik — the table runs the wrong direction from the station.")
		"pip_review":
			if not GameState.slides_filed:
				GameState.add_pip(40.0)
				GameState.toast.emit("PIP reads the file at 18:00. It was empty.")
			else:
				GameState.toast.emit("PIP read the file. Not your face.")
	hud.refresh_board()

func _on_game_over(kind: String, ending_id: String) -> void:
	show_ending(kind, ending_id)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("carry_drop") and player.carrying != "":
		player.set_carry("")
		GameState.toast.emit("Set down the carry.")
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not menu.menu_open and not _paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

