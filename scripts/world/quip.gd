class_name Quip
extends Interactable
## A small flavour interaction: someone says a random line, and optionally it
## costs time and nudges stress. The desk, coffee machine, rice cooker…
## Set `speaker` to an NPC to have them say it; empty means Jonaid.

@export_multiline var lines: PackedStringArray = []
@export var speaker: NodePath
@export var stress_delta := 0.0
@export var minutes := 0.0
@export var cooldown := 4.0

var _last := -100.0
var _i := -1


func _on_used(by: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last < cooldown or lines.is_empty():
		return
	_last = now
	var i := randi() % lines.size()
	if lines.size() > 1 and i == _i:
		i = (i + 1) % lines.size()
	_i = i
	var who := get_node_or_null(speaker) as Node3D
	if who == null:
		who = by as Node3D
	Game.say(who, lines[_i])
	if stress_delta > 0.0:
		Stress.add(stress_delta)
	elif stress_delta < 0.0:
		Stress.relieve(-stress_delta)
	if minutes > 0.0:
		Clock.advance(minutes)
