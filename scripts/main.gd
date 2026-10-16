extends Node
## Owns the current location and moves Jonaid between them. Runs the day
## loop: title -> office -> commute -> home -> sleep -> next day, and ends the
## run on a meltdown or when Hana has had enough. Builds the UI layers.

const LOCATIONS := {
	"office": "res://scenes/locations/office.tscn",
	"street": "res://scenes/locations/street.tscn",
	"station": "res://scenes/locations/station.tscn",
	"home": "res://scenes/locations/home.tscn",
}
const MELTDOWN_SECONDS := 3.0

var location: Location
var hud: HUD
var title: TitleScreen
var pause_menu: PauseMenu
var game_over: GameOverScreen
var _fade: ColorRect
var _busy := false
var _title_cam: Camera3D
var _title_t := 0.0
var _ending := false

@onready var world: Node3D = $World
@onready var player: Player = $Player


func _ready() -> void:
	# Main keeps listening while paused (Esc to resume); the world doesn't.
	process_mode = Node.PROCESS_MODE_ALWAYS
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud = HUD.new()
	add_child(hud)
	title = TitleScreen.new()
	add_child(title)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	game_over = GameOverScreen.new()
	add_child(game_over)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 50
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.06, 0.05, 0.08, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	_title_cam = Camera3D.new()
	_title_cam.fov = 55.0
	add_child(_title_cam)

	title.start_pressed.connect(start_run)
	pause_menu.resume_pressed.connect(func() -> void: _set_paused(false))
	pause_menu.title_pressed.connect(_to_title)
	game_over.again_pressed.connect(start_run)
	game_over.title_pressed.connect(_to_title)
	Game.travel_requested.connect(_on_travel)
	Game.sleep_requested.connect(_on_sleep)
	Game.run_ended.connect(_on_run_ended)
	Stress.maxed.connect(_on_meltdown)
	player.target_changed.connect(hud.set_prompt)

	await _load("office", "elevator")
	_show_title()
	var dev := DevTools.new()
	dev.game = self
	add_child(dev)


func _process(delta: float) -> void:
	if title.visible and location != null:
		_title_t += delta * 0.06
		# Stay under the 3.2 m ceiling and inside the walls.
		var c := Vector3(0.0, 1.0, 0.5)
		_title_cam.global_position = c + Vector3(cos(_title_t) * 8.5, 1.8, sin(_title_t) * 4.5)
		_title_cam.look_at(c, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and Game.in_run and not _busy and not game_over.visible:
		_set_paused(not get_tree().paused)
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and Game.in_run \
			and not get_tree().paused and not game_over.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- run flow

func start_run() -> void:
	if _busy:
		return
	_ending = false
	game_over.visible = false
	title.visible = false
	Game.new_run()
	hud.show_anger(false)
	hud.visible = true
	Clock.start_day(1)
	_title_cam.current = false
	player.camera.current = true
	await _go("office", "elevator", 0.0)
	_begin_day()


func _begin_day() -> void:
	player.controls_enabled = false
	await hud.card("DAY %d" % Clock.day, "%s · Hansung Electronics, 14F · %s" % [Clock.weekday_name(), Clock.now_string()])
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_sleep() -> void:
	if _busy:
		return
	Game.bump("days")
	Stress.reset(Stress.value * 0.5)
	Game.took_taxi = false
	Clock.start_day(Clock.day + 1)
	Clock.rate = 0.0
	await _go("office", "elevator", 0.0)
	_begin_day()


func _on_meltdown() -> void:
	if _ending or not Game.in_run:
		return
	_ending = true
	player.controls_enabled = false
	player.perform("Freakout")
	Clock.running = false
	Game.notify("JONAID IS LOSING IT")
	await get_tree().create_timer(MELTDOWN_SECONDS).timeout
	Game.end_run("meltdown")


func _on_run_ended(cause: String) -> void:
	_ending = true
	Clock.running = false
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_prompt(null)
	game_over.open(cause)


func _to_title() -> void:
	_set_paused(false)
	Game.in_run = false
	Clock.running = false
	game_over.visible = false
	await _go("office", "elevator", 0.0)
	_show_title()


func _show_title() -> void:
	hud.visible = false
	player.controls_enabled = false
	player.visible = true
	_title_cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title.open()
	_fade_to(0.0, 0.6)


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	if on:
		pause_menu.open()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		pause_menu.visible = false
		if Game.in_run:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- travel

func _on_travel(loc: String, spawn: String, minutes: float) -> void:
	if _busy or not Game.in_run:
		return
	await _go(loc, spawn, minutes)


func _go(loc: String, spawn: String, minutes: float) -> void:
	_busy = true
	var had_control := player.controls_enabled
	player.controls_enabled = false
	await _fade_to(1.0, 0.3)
	if minutes > 0.0:
		Clock.advance(minutes)
	await _load(loc, spawn)
	hud.banner(location.display_name)
	if loc == "home" and Game.in_run:
		hud.show_anger(true)
	location.on_enter(player)
	await _fade_to(0.0, 0.35)
	player.controls_enabled = had_control or Game.in_run
	_busy = false


func _load(loc: String, spawn: String) -> void:
	if location != null:
		location.queue_free()
		await get_tree().process_frame
	var scene := load(LOCATIONS[loc]) as PackedScene
	location = scene.instantiate() as Location
	world.add_child(location)
	Clock.rate = location.clock_rate
	var marker := location.spawn_point(spawn)
	if marker != null:
		player.place_at(marker)


func _fade_to(a: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, t)
	await tw.finished
