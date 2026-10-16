class_name NPC
extends CharacterBody3D
## A cast member standing (or sitting) in a location. Plays `anim` on loop.
## Speech bubbles anchor above the head via speech_anchor().

const LOOPING := ["Idle", "Walk", "Run", "Smoke", "Type", "Sit", "SitType", "Freakout", "Talk", "Angry"]

@export var display_name := ""
@export var anim := "Idle"
@export var head_height := 2.3
@export var show_props := true

var _anim: AnimationPlayer


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	ToonKit.apply(self)
	var players := find_children("*", "AnimationPlayer", true, false)
	_anim = players.front() as AnimationPlayer if players.size() > 0 else null
	if _anim:
		for n in LOOPING:
			if _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		# Desync idles so a room full of people doesn't breathe in unison.
		play(anim)
		_anim.seek(randf() * 1.5, true)
	if not show_props:
		for n in find_children("Prop_*", "", true, false):
			(n as Node3D).visible = false


func play(anim_name: String, blend: float = 0.25) -> void:
	if _anim and _anim.has_animation(anim_name):
		_anim.play(anim_name, blend)


func speech_anchor() -> Vector3:
	return global_position + Vector3.UP * head_height
