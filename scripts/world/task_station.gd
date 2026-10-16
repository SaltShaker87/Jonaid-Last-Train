class_name TaskStation
extends Quip
## A place where Park's tasks get done (desk PC, copier, stamp table, pantry,
## meeting room). With a pending task here, E opens its minigame; otherwise
## it behaves like a Quip with `idle_prompt`.

@export var station := "pc"
@export var idle_prompt := "Look around"


func _process(_delta: float) -> void:
	var t := Tasks.for_station(station)
	prompt = ("Do it: " + String(t.get("title", ""))) if not t.is_empty() else idle_prompt


func _on_used(by: Node) -> void:
	var t := Tasks.for_station(station)
	if not t.is_empty() and Game.in_run:
		Tasks.play(t)
	else:
		super._on_used(by)
