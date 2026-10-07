extends RoomBase
## Apartment — entry shoes, kitchen clock, kids' room, tank, bed, couch,
## good cabinet, sad shelf. Four rooms and a rule. (GDD §11)

func _ready() -> void:
	room_id = "apartment"
	display_name = "Apartment — Home"
	tungsten = true
	super._ready()
	RoomBuilder.floor(self, Vector2(18, 14), Color(0.58, 0.50, 0.40))
	RoomBuilder.wall(self, Vector3(18, 3.0, 0.4), Vector3(0, 1.5, -7), Color(0.72, 0.64, 0.55))
	RoomBuilder.wall(self, Vector3(18, 3.0, 0.4), Vector3(0, 1.5, 7), Color(0.72, 0.64, 0.55))
	RoomBuilder.light(self, Vector3(0, 2.8, 0), true, 1.1)
	RoomBuilder.light(self, Vector3(-5, 2.6, 3), true, 0.7)
	var spawn := Node3D.new()
	spawn.position = Vector3(-7, 0, 5)
	add_child(spawn)
	register_socket("spawn", spawn)
	# Entry shoes + polaroid (Hana/kids show here)
	RoomBuilder.box_prop(self, Vector3(-7, 0.3, 5), Vector3(1.2, 0.4, 0.8), Color(0.30, 0.22, 0.16), "ENTRY — shoes off")
	# Kitchen clock + Hana
	RoomBuilder.box_prop(self, Vector3(-3, 1.5, -5.5), Vector3(1.4, 1.0, 0.3), Color(0.90, 0.88, 0.82), "KITCHEN CLOCK")
	_add_npc("Hana", Vector3(-3, 0, -3.5), Color(0.70, 0.50, 0.45))
	var hana := RoomBuilder.interactable(self, Vector3(-3, 1.0, -3.0), Interactable.Weight.ERRAND, "Talk to Hana (she names the slip, the shuttle, the time)", "talk_hana", "")
	hana.activated.connect(_relay)
	# Kids room door (open/shut by clock)
	RoomBuilder.box_prop(self, Vector3(4, 1.3, -6), Vector3(2.0, 2.6, 0.3), Color(0.55, 0.60, 0.70), "KIDS' ROOM")
	var kids := RoomBuilder.interactable(self, Vector3(4, 1.0, -5.0), Interactable.Weight.ERRAND, "Bedtime (two interactions if early)", "bedtime", "")
	kids.activated.connect(_relay)
	# Tank + filter (Chairman Bubbles cannot send KakaoTalk. He can only need power.)
	RoomBuilder.box_prop(self, Vector3(7, 0.8, -2), Vector3(1.6, 1.2, 0.8), Color(0.35, 0.55, 0.65), "TANK — Chairman Bubbles")
	var filt := RoomBuilder.interactable(self, Vector3(7, 1.0, -0.8), Interactable.Weight.MANUAL, "Seat the filter + hold the prime bulb", "fish_prime", "pour_prime")
	filt.activated.connect(_relay)
	# Bed / couch / shop shelf
	RoomBuilder.box_prop(self, Vector3(-5, 0.6, -1), Vector3(2.2, 0.8, 3.0), Color(0.80, 0.75, 0.68), "BED")
	var bed := RoomBuilder.interactable(self, Vector3(-5, 1.0, 0.8), Interactable.Weight.ERRAND, "Sleep in bed (good/polite cabinet by Hana)", "sleep_bed", "")
	bed.activated.connect(_relay)
	RoomBuilder.box_prop(self, Vector3(0, 0.5, 2.5), Vector3(2.4, 0.7, 1.2), Color(0.50, 0.35, 0.28), "COUCH — anime + buzzing filter")
	var couch := RoomBuilder.interactable(self, Vector3(0, 1.0, 1.4), Interactable.Weight.ERRAND, "Sleep on couch (sad shelf, Jun hears filter 02:00)", "sleep_couch", "")
	couch.activated.connect(_relay)
	RoomBuilder.box_prop(self, Vector3(7, 1.0, 4.5), Vector3(2.0, 2.0, 0.6), Color(0.85, 0.66, 0.25), "GOOD CABINET / SAD SHELF")
	var shop := RoomBuilder.interactable(self, Vector3(7, 1.0, 3.6), Interactable.Weight.ERRAND, "Shop the shelf (couch sleep locks the good cabinet)", "cabinet_shop", "")
	shop.activated.connect(_relay)
	# Slip on table (promise object with a mesh)
	RoomBuilder.box_prop(self, Vector3(-1, 0.85, -1), Vector3(0.6, 0.05, 0.4), Color(0.95, 0.95, 0.92), "SLIP — unsigned promise")
	var slip := RoomBuilder.interactable(self, Vector3(-1, 1.0, -1), Interactable.Weight.ERRAND, "Sign Harin's slip", "sign_slip", "")
	slip.activated.connect(_relay)
	var out := RoomBuilder.interactable(self, Vector3(-7, 1.0, 6.2), Interactable.Weight.ERRAND, "Badge in — back to the office (next morning)", "go_office_morning", "")
	out.activated.connect(_relay)
	# --- Art pass: tungsten home, rug/shoes/polaroid, tank glow, suitcase telegraph ---
	RoomBuilder.ceiling(self, Vector2(18, 14))
	RoomBuilder.tungsten_lamp(self, Vector3(-3, 2.4, -3.5), 1.1)
	RoomBuilder.tungsten_lamp(self, Vector3(0, 2.4, 2.0), 0.8)
	RoomBuilder.rug(self, Vector3(-2, 0.03, 1.0), Vector2(5, 4), Color(0.45, 0.12, 0.12))
	RoomBuilder.rug(self, Vector3(-7, 0.03, 4.2), Vector2(2.2, 1.4), Color(0.30, 0.22, 0.16))
	RoomBuilder.bilingual(self, Vector3(-7, 1.6, 5.2), "HOME", "집", ArtDirection.GOLD)
	# Suitcase in the entry telegraphs divorce track (appears via Main when Hana low).
	RoomBuilder.try_swap_blender_model(self, "tank", "res://assets/models/tank.glb")
	RoomBuilder.try_swap_blender_model(self, "couch", "res://assets/models/couch.glb")

func _add_npc(nm: String, pos: Vector3, c: Color) -> void:
	var npc := OfficeNPC.new()
	add_child(npc)
	npc.setup(nm, pos, c)

func _relay(inter: Interactable) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("on_interact"):
		game.call("on_interact", inter)
