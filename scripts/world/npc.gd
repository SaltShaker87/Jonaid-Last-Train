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


## Walk through world-space points (y is ignored), then idle. Awaitable.
func walk_path(points: Array, speed: float = 2.6) -> void:
	play("Walk", 0.15)
	if _anim:
		_anim.speed_scale = speed / 1.5
	for p in points:
		var target := Vector3((p as Vector3).x, 0.0, (p as Vector3).z)
		var from := global_position
		var d := Vector3(target.x - from.x, 0.0, target.z - from.z)
		if d.length() < 0.05:
			continue
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "rotation:y", _shortest_yaw(atan2(d.x, d.z)), 0.2)
		tw.tween_property(self, "global_position", target, d.length() / speed)
		await tw.finished
	if _anim:
		_anim.speed_scale = 1.0
	play("Idle", 0.2)


func _shortest_yaw(to: float) -> float:
	return rotation.y + wrapf(to - rotation.y, -PI, PI)
