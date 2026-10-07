extends Node3D
class_name RoomBase
## RoomBase — one interior behind a masked load (GDD §6, §17).
## Rooms as separate scenes behind elevator / turnstile / apartment-door fades.

@export var room_id: String = "office"
@export var display_name: String = "14th Floor"
@export var tungsten: bool = false  # home warm vs office fluorescent

var sockets: Dictionary = {}  # name -> Node3D for Godot-MCP-style placement

func _ready() -> void:
	add_to_group("rooms")

func register_socket(sock_name: String, node: Node3D) -> void:
	sockets[sock_name] = node

func socket_pos(sock_name: String) -> Vector3:
	if sockets.has(sock_name):
		return (sockets[sock_name] as Node3D).global_position
	return global_position

func set_player_spawn(player: Salaryman, socket_name: String = "spawn") -> void:
	if sockets.has(socket_name):
		player.global_position = (sockets[socket_name] as Node3D).global_position + Vector3(0, 0.1, 0)
		player.cam_yaw = 0.0
	else:
		player.global_position = Vector3(0, 0.2, 0)
