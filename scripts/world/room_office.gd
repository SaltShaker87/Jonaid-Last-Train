extends RoomBase
## 14th floor — Park's glass box, Sora's desk, Taeyang's empty chair,
## your PC, floor copier, real-work pile. (GDD §6)

func _ready() -> void:
	room_id = "office"
	display_name = "Hansung 14F"
	super._ready()
	RoomBuilder.floor(self, Vector2(22, 16), Color(0.62, 0.63, 0.65))
	RoomBuilder.wall(self, Vector3(22, 3.2, 0.4), Vector3(0, 1.6, -8), Color(0.78, 0.78, 0.80))
	RoomBuilder.wall(self, Vector3(22, 3.2, 0.4), Vector3(0, 1.6, 8), Color(0.78, 0.78, 0.80))
	RoomBuilder.wall(self, Vector3(0.4, 3.2, 16), Vector3(-11, 1.6, 0), Color(0.72, 0.72, 0.74))
	RoomBuilder.wall(self, Vector3(0.4, 3.2, 16), Vector3(11, 1.6, 0), Color(0.72, 0.72, 0.74))
	RoomBuilder.light(self, Vector3(0, 3.0, 0), false, 1.4)
	RoomBuilder.light(self, Vector3(-6, 3.0, -4), false, 1.0)
	# Spawn / elevator
	var spawn := Node3D.new()
	spawn.name = "spawn"
	spawn.position = Vector3(-9, 0, 6)
	add_child(spawn)
	register_socket("spawn", spawn)
	RoomBuilder.door_frame(self, Vector3(-9, 1.3, 7.6), "ELEVATOR", Color(0.35, 0.35, 0.38))
	var elev := RoomBuilder.interactable(self, Vector3(-9, 1.0, 6.4), Interactable.Weight.ERRAND, "Badge out — elevator to street", "badge_out", "")
	elev.activated.connect(_relay)
	# Your desk: PC (slides), real-work pile, board
	var desk := RoomBuilder.desk(self, Vector3(2, 0, 2))
	RoomBuilder.box_prop(self, Vector3(2, 1.1, 2), Vector3(0.5, 0.35, 0.4), Color(0.15, 0.15, 0.17), "YOUR PC")
	RoomBuilder.box_prop(self, Vector3(3.2, 0.95, 2.2), Vector3(0.45, 0.25, 0.35), Color(0.91, 0.87, 0.77), "REAL-WORK PILE")
	var pin := RoomBuilder.interactable(self, Vector3(3.2, 1.0, 2.2), Interactable.Weight.ERRAND, "Pin the folder (petty, visible, effective)", "pin_folder", "")
	pin.activated.connect(_relay)
	var pc := RoomBuilder.interactable(self, Vector3(2, 1.0, 2), Interactable.Weight.HEAVY, "Build the vendor slides (first person)", "slides_pc", "slides")
	pc.activated.connect(_relay)
	# Week 2+ PC: the resignation draft, unsent.
	var draft := RoomBuilder.interactable(self, Vector3(2.7, 1.0, 2.3), Interactable.Weight.ERRAND, "Open the resignation draft (unsent)", "quit_draft_pc", "")
	draft.activated.connect(_relay)
	# Tube on desk (DO NOT COPY)
	RoomBuilder.box_prop(self, Vector3(1.0, 0.95, 2.4), Vector3(0.9, 0.18, 0.18), Color(0.91, 0.87, 0.77), "DO NOT COPY tube")
	var tube := RoomBuilder.interactable(self, Vector3(1.0, 1.0, 2.4), Interactable.Weight.ERRAND, "Haul the map tube", "take_tube", "")
	tube.activated.connect(_relay)
	# Park glass box + bow zone
	RoomBuilder.box_prop(self, Vector3(-4, 1.1, -5), Vector3(3.0, 2.2, 0.2), Color(0.65, 0.75, 0.82, 0.6), "PARK'S GLASS BOX")
	var bow := RoomBuilder.interactable(self, Vector3(-4, 1.0, -3.4), Interactable.Weight.MANUAL, "Hold the bow as Choi enters", "bow_choi", "bow")
	bow.activated.connect(_relay)
	var brief := RoomBuilder.interactable(self, Vector3(-4, 1.0, -4.2), Interactable.Weight.ERRAND, "Stand for briefing (or read later, colder)", "briefing", "")
	brief.activated.connect(_relay)
	# Sora desk + Taeyang empty chair
	RoomBuilder.desk(self, Vector3(6, 0, -2), false)
	RoomBuilder.box_prop(self, Vector3(7.5, 0.5, -5), Vector3(0.6, 0.9, 0.6), Color(0.4, 0.4, 0.42), "TAE-YANG (empty)")
	_add_npc("Sora", Vector3(6, 0, -1), Color(0.75, 0.45, 0.35))
	_add_npc("Park", Vector3(-4, 0, -5), Color(0.25, 0.25, 0.30))
	# Floor copier (jam manual)
	RoomBuilder.box_prop(self, Vector3(-7, 0.6, -2), Vector3(1.1, 1.2, 0.9), Color(0.82, 0.82, 0.84), "FLOOR COPIER")
	var copier_socket := Node3D.new()
	copier_socket.name = "copier"
	copier_socket.position = Vector3(-7, 0, -2)
	add_child(copier_socket)
	register_socket("copier", copier_socket)
	var jam := RoomBuilder.interactable(self, Vector3(-7, 1.0, -0.8), Interactable.Weight.MANUAL, "Clear the copier jam", "copier_jam", "pour")
	jam.activated.connect(_relay)
	# Board by desk lists today's jobs with weights
	RoomBuilder.box_prop(self, Vector3(0.5, 1.6, 4.5), Vector3(2.4, 1.2, 0.15), Color(0.12, 0.12, 0.13), "BOARD: tube=HEAVY bow=MANUAL pin=ERRAND")
	# --- Art pass: fluorescent office, espresso trim, readable stamp ---
	RoomBuilder.ceiling(self, Vector2(22, 16))
	RoomBuilder.fluorescent_bank(self, Vector3(0, 3.05, -2), 3)
	RoomBuilder.fluorescent_bank(self, Vector3(0, 3.05, 3), 3)
	RoomBuilder.pillar(self, Vector3(-2, 0, -1))
	RoomBuilder.pillar(self, Vector3(5, 0, 4))
	RoomBuilder.bilingual(self, Vector3(-9, 2.6, 7.2), "ELEVATOR", "엘리베이터", ArtDirection.GOLD)
	RoomBuilder.bilingual(self, Vector3(0.5, 2.6, 4.4), "HANSUNG 14F", "한성 14층", ArtDirection.GOLD)
	ArtDirection.stamp_label(self, Vector3(1.0, 1.35, 2.4))
	# VFX pass: the stamp is a live prop — pulse + thump on pin. Dust in the fluorescent light.
	VFX.stamp(self, Vector3(1.0, 1.42, 2.42))
	VFX.motes(self, Vector3(0, 2.1, 0), Vector3(9, 1.4, 6), ArtDirection.FLUORESCENT, 2.0, Vector3(0, 0.4, 0), 0.08)
	# Attempt Blender swap (non-fatal).
	RoomBuilder.try_swap_blender_model(self, "copier", "res://assets/models/copier.glb")

func _add_npc(nm: String, pos: Vector3, c: Color) -> void:
	var npc := OfficeNPC.new()
	add_child(npc)
	npc.setup(nm, pos, c)

func _relay(inter: Interactable) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("on_interact"):
		game.call("on_interact", inter)
