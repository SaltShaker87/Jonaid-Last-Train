extends RoomBase
## Hoesik restaurant — Thursday 19:00. You sit. Pour you can refuse once.
## Attendance deletes the family train by geography. (GDD §10)

func _ready() -> void:
	room_id = "restaurant"
	display_name = "Hoesik — wrong direction"
	super._ready()
	RoomBuilder.floor(self, Vector2(16, 12), Color(0.55, 0.42, 0.32))
	RoomBuilder.light(self, Vector3(0, 2.8, 0), true, 1.2)
	var spawn := Node3D.new()
	spawn.position = Vector3(-6, 0, 4)
	add_child(spawn)
	register_socket("spawn", spawn)
	RoomBuilder.box_prop(self, Vector3(0, 0.8, 0), Vector3(4.0, 0.8, 2.0), Color(0.40, 0.28, 0.18), "HOESIK TABLE")
	var pour := RoomBuilder.interactable(self, Vector3(0, 1.0, 1.4), Interactable.Weight.MANUAL, "Pour (refuse once, attendance costs the family train)", "hoesik_pour", "pour_beer")
	pour.activated.connect(_relay)
	var back := RoomBuilder.interactable(self, Vector3(-6, 1.0, 5.0), Interactable.Weight.ERRAND, "Leave the table (too late for the family train)", "leave_hoesik", "")
	back.activated.connect(_relay)

func _relay(inter: Interactable) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("on_interact"):
		game.call("on_interact", inter)
