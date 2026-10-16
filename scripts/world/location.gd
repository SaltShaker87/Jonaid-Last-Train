class_name Location
extends Node3D
## Root of every location scene (scenes/locations/*.tscn).
## Spawn points are Marker3D children of a "Spawns" node; a marker's -Z is the
## direction Jonaid faces when he arrives.

@export var location_id := ""
@export var display_name := ""
@export var clock_rate := 0.0


func _ready() -> void:
	ToonKit.apply(self)


func spawn_point(spawn_name: String) -> Node3D:
	var spawns := get_node_or_null("Spawns")
	if spawns == null:
		return null
	var m := spawns.get_node_or_null(spawn_name) as Node3D
	if m == null and spawns.get_child_count() > 0:
		m = spawns.get_child(0) as Node3D
	return m


## Called by Main after the player is placed.
func on_enter(_player: Node3D) -> void:
	pass
