extends Node
## Main — day loop in space (GDD §9), losses/endings (§13), UI glue (§15).
## Third person in world, first person only for lightbox + slides.
## World clock runs while walking/typing. Skills freeze + bill on exit.

var world_root: Node3D
var player: Salaryman
var hud: HUD
var phone: PhoneUI
var menu: MainMenu
var ending: EndingScreen
var fade: ColorRect
var skill_layer: CanvasLayer

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
var recital_missed := false

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
	# Headless smoke path: allow --auto-test to boot without menu.
	if "--auto-test" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		start_new_game()
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
	# Office bed: cool hum loop bed. Apartment bed: warm loop bed.
	for bed in ["bed_office", "bed_home"]:
		var b := AudioStreamPlayer.new()
		b.name = "Bed_" + bed
		# Reuse buzz/chime softly as bed placeholders until composed beds land.
		var bp := "res://assets/audio/buzz.wav" if bed == "bed_home" else "res://assets/audio/chime.wav"
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
	DayClock.start_day(1, 1, 8 * 60 + 50)
	hoesik_refused_once = false
	recital_missed = false
	menu.hide_menu()
	player.move_enabled = true
	player.set_carry("")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not OS.has_feature("web") else Input.MOUSE_MODE_VISIBLE
	load_room("office")
	hud.show_toast("08:50. Tube on the desk, folder unpinned, Harin's slip in your bag. Stamp the folder.")
	GameState.toast.emit("Briefing is a place. Stand in the zone or read it later on the phone, colder.")

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

# ---------------------------------------------------------------- interactions

func on_interact(inter: Interactable) -> void:
	if active_skill != null:
		return
	var job: String = inter.job_id
	match job:
		"badge_out":
			DayClock.add_minutes(4)
			load_room("street")
		"go_office":
			DayClock.add_minutes(4)
			load_room("office")
		"go_station":
			DayClock.add_minutes(6)
			load_room("station")
		"go_street":
			DayClock.add_minutes(3)
			load_room("street")
		"go_office_morning":
			advance_morning("away" if DayClock.minutes > 24 * 60 else "bed_polite")
		"pin_folder":
			GameState.pinned_folder = true
			GameState.add_face(-2.0)
			GameState.toast.emit("Stamped. Park sees it. Face dips. PIP is safe.")
			inter.disabled = true
		"briefing":
			GameState.toast.emit("Park: the map must move today. Sora: numbers at 18:00. Hana (text): shuttle moved up?")
			StressSys.add(4.0)
		"take_tube":
			player.set_carry("map_tube")
			GameState.has_map_tube = true
			GameState.toast.emit("Tube under your arm. Carry slows you and blocks the bow.")
			inter.disabled = true
		"copier_jam":
			open_skill("pour", inter)
		"yoon_refuse":
			GameState.toast.emit("Yoon: I will not print a page with the stamp. Three outs: crop, trace, or Mullae.")
			StressSys.add(5.0)
		"yoon_crop":
			open_skill("pour", inter)
		"mullae_copy":
			DayClock.add_minutes(12)
			open_skill("pour", inter)
		"lightbox_trace":
			open_skill("trace", inter)
		"bow_choi":
			open_skill("bow", inter)
		"g90_board":
			open_skill("digits_g90", inter)
		"g90_sign":
			open_skill("digits_sign", inter)
		"whiskey_buy":
			player.set_carry("whiskey")
			GameState.toast.emit("Whiskey secured. File the receipt as office supplies.")
		"beer_pour":
			open_skill("pour_beer", inter)
		"shuttle_curb":
			_resolve_shuttle()
		"turnstile":
			play_audio("turnstile")
			GameState.toast.emit("Turnstile. Crowd lanes shove. Platform edge ahead.")
			DayClock.add_minutes(2)
		"platform_dash":
			open_skill("dash", inter)
		"talk_hana":
			GameState.add_hana(4.0)
			StressSys.relieve(6.0)
			GameState.toast.emit("Hana names the slip, the shuttle, and the time. The filter hums.")
		"bedtime":
			if int(DayClock.minutes) % (24 * 60) > 21 * 60 + 30:
				GameState.toast.emit("Kids' door is shut. Hana in the kitchen doing accounting.")
			else:
				GameState.add_kids(8.0)
				GameState.add_hana(5.0)
				StressSys.relieve(10.0)
				GameState.toast.emit("Bedtime finished. Two interactions fit because you arrived early.")
				inter.disabled = true
		"fish_prime":
			open_skill("pour_prime", inter)
		"sleep_bed":
			var cab := GameState.cabinet_state()
			advance_morning("bed_good" if cab == "good" else "bed_polite")
		"sleep_couch":
			advance_morning("couch")
		"cabinet_shop":
			_resolve_shop()
		"sign_slip":
			GameState.promises["slip_signed"] = true
			GameState.add_hana(8.0)
			GameState.add_kids(6.0)
			GameState.toast.emit("Slip signed. A promise with a mesh, not a flag.")
			inter.disabled = true
		"slides_pc":
			_maybe_sora_snipe()
			open_skill("slides", inter)
		"hoesik_pour":
			open_skill("pour_beer", inter)
		_:
			GameState.toast.emit("Nothing happens. The clock keeps running.")

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
	_apply_job_result(inter, sk, grade)
	hud.refresh_board()

func _apply_job_result(inter: Interactable, sk: SkillBase, grade: String) -> void:
	var job := "" if inter == null else String(inter.job_id)
	var key := ""
	if sk == trace_skill:
		key = "trace"
	elif sk == bow_skill:
		key = "bow"
	elif sk == crop_skill:
		key = "crop"
	elif sk == prime_skill:
		key = "prime"
	elif sk == pour_beer_skill:
		key = "pour_beer"
	elif sk == digits_g90:
		key = "g90"
	elif sk == digits_sign:
		key = "sign"
	elif sk == slides_skill:
		key = "slides"
	elif sk == kakao_skill:
		key = "kakao"
	elif sk == dash_skill:
		key = "dash"
	match key:
		"trace":
			if grade == "clean":
				GameState.map_resolved = true
				GameState.add_face(4.0)
				StressSys.add(8.0)
				player.set_carry("")
				GameState.toast.emit("Clean trace. Yoon nods. Park will remember you solved it.")
			elif grade == "sloppy":
				GameState.map_resolved = true
				GameState.add_face(-2.0)
				StressSys.add(14.0)
				GameState.toast.emit("Sloppy line — cropped edge. Yoon may reject it. You redo or you hand it back uncopied.")
			else:
				StressSys.add(18.0)
				GameState.toast.emit("Failed attempt. 30 minutes billed and the prop is still unsolved.")
		"crop":
			play_audio("jam")
			if job == "copier_jam":
				if grade != "fail":
					GameState.add_face(3.0)
					StressSys.relieve(4.0)
				else:
					StressSys.add(8.0)
			elif job == "yoon_crop":
				if grade == "clean":
					GameState.map_resolved = true
					GameState.toast.emit("Mask aligned. Prohibition falls outside the glass.")
				elif grade == "sloppy":
					GameState.map_resolved = true
					StressSys.add(10.0)
				else:
					StressSys.add(14.0)
			elif job == "mullae_copy":
				if grade == "clean":
					GameState.map_resolved = true
					GameState.map_legal_flag = true
					GameState.toast.emit("Mullae copy too clean — legal flag raised. Yoon was right.")
				elif grade == "sloppy":
					GameState.map_resolved = true
		"bow":
			if grade == "clean":
				GameState.add_face(6.0)
				StressSys.add(4.0)
			elif grade == "sloppy":
				GameState.add_face(1.0)
				StressSys.add(8.0)
			else:
				GameState.add_face(-6.0)
				StressSys.add(12.0)
		"g90":
			if grade == "clean":
				GameState.add_face(10.0)
				GameState.toast.emit("Convoy story lands. Three black sedans, stapler budget intact.")
			elif grade == "sloppy":
				GameState.add_face(2.0)
				GameState.toast.emit("Washed dark sedan. Survive his walkaround.")
			else:
				GameState.add_face(-8.0)
				GameState.toast.emit("Numbers cannot close. The deposit form glows. Sign it and the hole gets deeper.")
		"sign":
			if grade == "clean":
				GameState.money -= 600000
				GameState.add_face(4.0)
				GameState.toast.emit("Signed. A ₩600,000 hole opens on your card.")
			else:
				GameState.money -= 600000
				StressSys.add(10.0)
		"prime":
			if grade == "clean":
				GameState.filter_state = "ok" if GameState.has_quiet_filter else "ok"
				GameState.fish_alive = true
				StressSys.relieve(8.0)
				GameState.add_hana(4.0)
			elif grade == "sloppy":
				GameState.fish_alive = DayClock.minutes < 24 * 60
				StressSys.add(6.0)
			else:
				if DayClock.minutes >= 24 * 60:
					GameState.fish_alive = false
					GameState.toast.emit("Missed the prime after midnight. Saturday is an empty tank.")
				StressSys.add(12.0)
		"pour_beer":
			if job == "hoesik_pour":
				_resolve_hoesik(grade)
			else:
				if not GameState.spend(GameState.BEER):
					return
				StressSys.relieve(25.0)
				GameState.smell_beer = true
				GameState.add_hana(-4.0)
				GameState.add_body(-4.0)
				GameState.add_jealousy(4.0)
				GameState.toast.emit("Beer down. Stress falls. Smell sticks to the suit and Hana has a nose.")
		"slides":
			if grade == "clean":
				GameState.slides_filed = true
				GameState.add_pip(-15.0)
				GameState.add_face(6.0)
			elif grade == "sloppy":
				GameState.slides_filed = true
				GameState.add_pip(15.0)
				GameState.toast.emit("Sora's number survived. PIP reads the file at 18:00, not your face.")
			else:
				GameState.add_pip(35.0)
		"kakao":
			StressSys.add(3.0)
			GameState.toast.emit("Replies sent. The building clock ran while the phone was open.")
		"dash":
			_resolve_dash(grade)

func _maybe_sora_snipe() -> void:
	# Week 2+ or day>=2: Sora snipes the real pile if left unpinned.
	if DayClock.day >= 2 and not GameState.pinned_folder and not GameState.sora_sniped:
		GameState.sora_sniped = true
		GameState.add_pip(10.0)
		GameState.toast.emit("Sora sniped the real pile while it sat unpinned. Her bad number is in your pack.")

func _resolve_shuttle() -> void:
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

func _resolve_shop() -> void:
	var cab := GameState.cabinet_state()
	if cab == "good":
		GameState.toast.emit("Good cabinet open (Hana ≥ 40). Quiet filter ₩90,000, grace key, alarm.")
		if GameState.money >= GameState.FILTER_GOOD:
			# Auto-offer quiet filter once.
			pass
	else:
		GameState.toast.emit("Polite cabinet. Functional gear. No grace items. Couch sleep locks the good one.")
	if GameState.sleep_place == "couch":
		GameState.toast.emit("Sad shelf: buzzing filter, noodles, anime.")

func _resolve_hoesik(grade: String) -> void:
	if not hoesik_refused_once and grade != "clean":
		hoesik_refused_once = true
		GameState.toast.emit("You refused the pour once. They noticed. Attendance still deletes the family train.")
		return
	GameState.toast.emit("Hoesik: the restaurant is the wrong direction from the station. Family train gone by geography.")
	recital_missed = true
	StressSys.add(8.0)
	GameState.add_face(4.0)
	GameState.add_hana(-8.0)

func _resolve_dash(grade: String) -> void:
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
	DayClock.minutes = 24 * 60 + 10
	load_room("apartment")

func advance_morning(sleep: String) -> void:
	GameState.on_morning(sleep)
	if sleep == "couch":
		play_audio("buzz")
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
	if DayClock.day > 60:
		var end_id := GameState.check_day60_ending()
		ending.show_ending("day60", end_id)
		player.move_enabled = false
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
	load_room("office")
	# Nuclear check helper state reset
	recital_missed = false

func _on_hard(event_id: String) -> void:
	match event_id:
		"shuttle":
			play_audio("ping")
			if current_room_id != "street":
				GameState.toast.emit("18:10 shuttle — you are not at the curb. The driver leaves.")
		"family_train":
			play_audio("chime")
			if current_room_id != "station" and current_room_id != "apartment":
				GameState.toast.emit("19:40 family train — you are in the wrong building. Hana notices.")
				GameState.add_hana(-6.0)
		"last_train":
			play_audio("announce")
			GameState.toast.emit("23:18 last train. Board flips to 05:12.")
		"pip_review":
			if not GameState.slides_filed:
				GameState.add_pip(40.0)
				GameState.toast.emit("PIP reads the file at 18:00. It was empty.")
			else:
				GameState.toast.emit("PIP read the file. Not your face.")
	hud.refresh_board()

func _on_game_over(kind: String, ending_id: String) -> void:
	player.move_enabled = false
	ending.show_ending(kind, ending_id)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("carry_drop") and player.carrying != "":
		player.set_carry("")
		GameState.toast.emit("Set down the carry.")
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not menu.menu_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
