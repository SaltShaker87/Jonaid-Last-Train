class_name Door
extends Interactable
## Takes Jonaid to another location. `minutes` is how much game time the
## trip costs (elevator rides, stairs).

@export var target := ""
@export var spawn := ""
@export var minutes := 0.0


func _on_used(_by: Node) -> void:
	if target != "":
		Game.travel(target, spawn, minutes)
