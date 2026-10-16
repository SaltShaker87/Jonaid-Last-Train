class_name Player
extends CharacterBody3D
## Jonaid. Third person, mouse-orbit over-the-shoulder camera, WASD relative
## to the camera, Shift to run, E to use whatever the sensor is pointing at.
## The body never rotates; only $Visual turns to face where he walks, so the
## camera pivot keeps its own yaw.

signal target_changed(target: Interactable)

const WALK_SPEED := 2.7
const RUN_SPEED := 5.6
const WALK_ANIM_SPEED := 1.5  ## m/s the Walk cycle was keyed for
const RUN_ANIM_SPEED := 3.6
const ACCEL := 10.0
const TURN_SPEED := 12.0
const GRAVITY := 22.0
const LOOPING := ["Idle", "Walk", "Run", "Smoke", "Type", "Sit", "SitType", "Freakout", "Talk", "Angry"]

@export var mouse_sensitivity := 0.0028

var controls_enabled := false
var target: Interactable
var yaw := 0.0
var pitch := -0.28

var _anim: AnimationPlayer
var _action := ""
var _action_cancel: Callable
var _current_anim := ""

@onready var visual: Node3D = $Visual
@onready var pivot: Node3D = $CamPivot
@onready var arm: SpringArm3D = $CamPivot/SpringArm3D
@onready var camera: Camera3D = $CamPivot/SpringArm3D/Camera3D
@onready var sensor: Area3D = $Visual/Sensor


func _ready() -> void:
	ToonKit.apply(visual)
	_anim = visual.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	if _anim:
		for n in LOOPING:
			if _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	arm.add_excluded_object(get_rid())
	set_prop("Prop_Cigarette", false)
	_play("Idle")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * mouse_sensitivity
		pitch = clampf(pitch - mm.relative.y * mouse_sensitivity, -1.1, 0.35)
	if not controls_enabled:
		return
	if event.is_action_pressed("interact"):
		if _action != "":
			cancel_action()
		elif target != null:
			target.interact(self)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	pivot.rotation = Vector3(pitch, yaw, 0.0)
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _action != "" and input.length() > 0.2:
		cancel_action()
	if _action != "":
		input = Vector2.ZERO
	var dir := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var running := controls_enabled and Input.is_action_pressed("sprint")
	var want := dir * (RUN_SPEED if running else WALK_SPEED)
	var k := 1.0 - exp(-ACCEL * delta)
	velocity.x = lerpf(velocity.x, want.x, k)
	velocity.z = lerpf(velocity.z, want.z, k)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if dir.length() > 0.05:
		var face := atan2(dir.x, dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, face, 1.0 - exp(-TURN_SPEED * delta))
	_update_anim(Vector2(velocity.x, velocity.z).length())
	_update_target()


func _update_anim(speed: float) -> void:
	if _anim == null:
		return
	if _action != "":
		_play(_action)
		_anim.speed_scale = 1.0
		return
	if speed < 0.25:
		_play("Idle")
		_anim.speed_scale = 1.0
	elif speed < (WALK_SPEED + RUN_SPEED) * 0.5:
		_play("Walk")
		_anim.speed_scale = clampf(speed / WALK_ANIM_SPEED, 0.6, 2.2)
	else:
		_play("Run")
		_anim.speed_scale = clampf(speed / RUN_ANIM_SPEED, 0.8, 2.0)


func _play(anim_name: String, blend: float = 0.18) -> void:
	if _current_anim == anim_name or _anim == null or not _anim.has_animation(anim_name):
		return
	_current_anim = anim_name
	_anim.play(anim_name, blend)


func _update_target() -> void:
	var best: Interactable = null
	var best_d := INF
	if controls_enabled and _action == "":
		for a in sensor.get_overlapping_areas():
			var it := a as Interactable
			if it == null or not it.can_use():
				continue
			var d := global_position.distance_squared_to(it.global_position)
			if d < best_d:
				best_d = d
				best = it
	if best != target:
		target = best
		target_changed.emit(target)


# ---------------------------------------------------------------- actions

## Lock movement and loop an animation until the player moves or presses E.
func begin_action(anim_name: String, on_cancel: Callable = Callable()) -> void:
	_action = anim_name
	_action_cancel = on_cancel
	if anim_name == "Smoke":
		set_prop("Prop_Cigarette", true)


func cancel_action() -> void:
	if _action == "":
		return
	if _action == "Smoke":
		set_prop("Prop_Cigarette", false)
	_action = ""
	var cb := _action_cancel
	_action_cancel = Callable()
	if cb.is_valid():
		cb.call()


## Play a one-off animation (e.g. "Freakout") without player control.
func perform(anim_name: String) -> void:
	_action = anim_name
	_action_cancel = Callable()
	_current_anim = ""


func set_prop(prop_name: String, on: bool) -> void:
	var n := visual.find_child(prop_name, true, false) as Node3D
	if n:
		n.visible = on


## Put Jonaid at a marker, facing the marker's -Z, camera behind him.
func place_at(marker: Node3D) -> void:
	var t := marker.global_transform
	global_position = t.origin
	velocity = Vector3.ZERO
	var fwd := -t.basis.z
	yaw = atan2(-fwd.x, -fwd.z)
	pitch = -0.28
	visual.rotation.y = yaw + PI
	pivot.rotation = Vector3(pitch, yaw, 0.0)
	cancel_action()


func speech_anchor() -> Vector3:
	return global_position + Vector3.UP * 2.25
