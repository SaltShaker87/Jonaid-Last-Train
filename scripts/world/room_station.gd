extends RoomBase
## Station — turnstile, crowd lanes, platform, doors with a chime. (GDD §6, §10)
## This is the loss condition you can see. Missing the train is not a dialog.

var doors_open := true
var _door_mesh: MeshInstance3D
var _door_fx: DoorFX
var _chime_t := 0.0

func _ready() -> void:
	room_id = "station"
	display_name = "Station — Last Train"
	super._ready()
	RoomBuilder.floor(self, Vector2(30, 12), Color(0.48, 0.48, 0.50))
	RoomBuilder.wall(self, Vector3(30, 3.0, 0.4), Vector3(0, 1.5, -6), Color(0.55, 0.55, 0.57))
	RoomBuilder.light(self, Vector3(0, 3.4, 0), false, 1.2)
	var spawn := Node3D.new()
	spawn.position = Vector3(-13, 0, 0)
	add_child(spawn)
	register_socket("spawn", spawn)
	# Turnstile
	RoomBuilder.box_prop(self, Vector3(-8, 0.8, 0), Vector3(1.2, 1.6, 3.0), Color(0.60, 0.60, 0.62), "TURNSTILE")
	var turn := RoomBuilder.interactable(self, Vector3(-8, 1.0, 1.8), Interactable.Weight.ERRAND, "Tap through the turnstile", "turnstile", "")
	turn.activated.connect(_relay)
	# Crowd lanes that shove (slow volumes)
	RoomBuilder.crowd_lane(self, Vector3(0, 1.0, 0), Vector3(10, 2.0, 6))
	RoomBuilder.box_prop(self, Vector3(0, 0.1, -2.5), Vector3(10, 0.2, 0.3), Color(0.85, 0.66, 0.25), "CROWD LANE →")
	RoomBuilder.box_prop(self, Vector3(0, 0.1, 2.5), Vector3(10, 0.2, 0.3), Color(0.85, 0.66, 0.25), "← CROWD LANE")
	# Platform edge + doors
	RoomBuilder.box_prop(self, Vector3(10, 0.15, 0), Vector3(8, 0.3, 4.0), Color(0.30, 0.30, 0.33), "PLATFORM")
	_door_mesh = RoomBuilder.box_prop(self, Vector3(12, 1.4, 0), Vector3(0.4, 2.4, 4.0), Color(0.15, 0.35, 0.55), "DOORS")
	# VFX pass: doors with weight — slabs slide, seam flashes oxblood, dust puff.
	_door_fx = VFX.door(self, Vector3(12, 0, 0), 4.0)
	var dash := RoomBuilder.interactable(self, Vector3(8, 1.0, 0), Interactable.Weight.HEAVY, "Dash the platform before the doors shut", "platform_dash", "dash")
	dash.activated.connect(_relay)
	var back := RoomBuilder.interactable(self, Vector3(-13, 1.0, 2.0), Interactable.Weight.ERRAND, "Back to street (missed? taxi only after doors shut)", "go_street", "")
	back.activated.connect(_relay)
	# --- Art pass: subway gray + gold lane bars, glowing platform edge, departure board ---
	RoomBuilder.ceiling(self, Vector2(30, 12))
	RoomBuilder.fluorescent_bank(self, Vector3(0, 3.05, 0), 4, 4.0)
	RoomBuilder.platform_edge(self, Vector3(7.2, 0.35, -1.8))
	RoomBuilder.platform_edge(self, Vector3(7.2, 0.35, 1.8))
	# VFX pass: platform-air motes in the subway light.
	VFX.motes(self, Vector3(4, 2.4, 0), Vector3(10, 1.6, 4), ArtDirection.SUBWAY, 1.5, Vector3(0, 0.6, 0), 0.05)
	RoomBuilder.bilingual(self, Vector3(4, 2.6, -5.4), "LAST TRAIN 23:18", "막차 23:18", ArtDirection.GOLD)
	RoomBuilder.bilingual(self, Vector3(-8, 2.4, 1.8), "TURNSTILE", "개찰구", ArtDirection.SUBWAY)
	DayClock.hard_event.connect(_on_hard)

func _on_hard(event_id: String) -> void:
	if event_id == "last_train" or event_id == "family_train":
		doors_open = false
		if _door_mesh != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.55, 0.10, 0.12)
			_door_mesh.material_override = mat
		if _door_fx != null:
			# Slabs slide, seam flashes, platform dust puff.
			_door_fx.close()
		GameState.toast.emit("Doors closed in front of you. The board flips to 05:12.")

func _process(_delta: float) -> void:
	# Family train 19:40 and last train 23:18 close doors via hard events.
	pass

func _relay(inter: Interactable) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("on_interact"):
		game.call("on_interact", inter)
