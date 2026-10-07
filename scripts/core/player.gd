extends CharacterBody3D
class_name Salaryman
## Jonaid — third-person body in a building (GDD §5).
## Suit slightly too big: oversized torso box. Not first-person by default.
## Move/camera: walk, stairs, crowds slow you. Sprint only if stress low + body high.
## Carry slows you and blocks the bow.

signal interact_target_changed(inter: Interactable)

const WALK_SPEED := 3.4
const SPRINT_SPEED := 5.4
const CARRY_MULT := 0.72
const CROWD_MULT := 0.6

var gravity: float = 18.0
var speed_mod: float = 1.0   # set by crowd volumes / stairs
var carrying: String = ""     # mirrors GameState.carry_item for speed/bow logic
var cam_yaw: float = 0.0
var cam_pitch: float = -0.18
var current_target: Interactable = null
var move_enabled: bool = true

var _cam_pivot: Node3D
var _spring: SpringArm3D
var _camera: Camera3D
var _mesh: MeshInstance3D
var _interact_radius := 3.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	_build_body()
	_build_camera()

func _build_body() -> void:
	# Legs (dark trousers) + shoes.
	var legs := MeshInstance3D.new()
	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.22
	leg_mesh.height = 0.9
	legs.mesh = leg_mesh
	legs.position.y = 0.45
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.12, 0.12, 0.14)
	legs.material_override = leg_mat
	add_child(legs)
	for sx in [-0.14, 0.14]:
		var shoe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.16, 0.1, 0.3)
		shoe.mesh = sm
		shoe.position = Vector3(sx, 0.05, 0.05)
		shoe.material_override = ArtDirection.mat(ArtDirection.ESPRESSO, 0.6)
		add_child(shoe)
	# Oversized suit torso — the character design: suit slightly too big.
	_mesh = MeshInstance3D.new()
	var torso := BoxMesh.new()
	torso.size = Vector3(0.78, 0.85, 0.5)  # deliberately wide
	_mesh.mesh = torso
	_mesh.position.y = 1.15
	_mesh.material_override = ArtDirection.suit_mat()
	add_child(_mesh)
	# White shirt front + oxblood tie + gold company pin.
	var shirt := MeshInstance3D.new()
	var shm := BoxMesh.new()
	shm.size = Vector3(0.22, 0.6, 0.02)
	shirt.mesh = shm
	shirt.position = Vector3(0, 1.18, 0.26)
	shirt.material_override = ArtDirection.ivory_mat()
	add_child(shirt)
	var tie := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.09, 0.5, 0.03)
	tie.mesh = tm
	tie.position = Vector3(0, 1.15, 0.28)
	tie.material_override = ArtDirection.oxblood_mat()
	add_child(tie)
	var pin := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.06, 0.06, 0.02)
	pin.mesh = pm
	pin.position = Vector3(-0.28, 1.35, 0.26)
	pin.material_override = ArtDirection.gold_mat()
	add_child(pin)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var sphere := SphereMesh.new()
	sphere.radius = 0.21
	sphere.height = 0.42
	head.mesh = sphere
	head.position.y = 1.82
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.93, 0.78, 0.66)
	head.material_override = skin
	add_child(head)
	# Hair cap (returnee neat cut).
	var hair := MeshInstance3D.new()
	hair.name = "Hair"
	var hm := SphereMesh.new()
	hm.radius = 0.215
	hm.height = 0.3
	hair.mesh = hm
	hair.position = Vector3(0, 1.90, -0.02)
	hair.material_override = ArtDirection.mat(Color(0.08, 0.07, 0.07), 0.9)
	add_child(hair)
	# Eyes + brows: five expressions driven by stress band (GDD Blender heads).
	var face := Node3D.new()
	face.name = "Face"
	face.position = Vector3(0, 1.83, 0.19)
	add_child(face)
	for sx in [-0.07, 0.07]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.022
		em.height = 0.044
		eye.mesh = em
		eye.position = Vector3(sx, 0.01, 0)
		eye.material_override = ArtDirection.mat(Color(0.05, 0.04, 0.04), 0.4)
		face.add_child(eye)
		var brow := MeshInstance3D.new()
		brow.name = "Brow_%s" % ("L" if sx < 0 else "R")
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09, 0.018, 0.015)
		brow.mesh = bm
		brow.position = Vector3(sx, 0.09, 0.01)
		brow.material_override = ArtDirection.mat(Color(0.08, 0.07, 0.07), 0.8)
		face.add_child(brow)
	# Carry indicator (map tube under arm) with readable stamp band.
	var tube := MeshInstance3D.new()
	tube.name = "CarryMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.09
	cyl.height = 1.0
	tube.mesh = cyl
	tube.rotation.z = PI / 2.0
	tube.position = Vector3(0.45, 1.2, 0.0)
	tube.material_override = ArtDirection.ivory_mat()
	tube.visible = false
	add_child(tube)
	var band := MeshInstance3D.new()
	band.name = "CarryBand"
	var bnd := CylinderMesh.new()
	bnd.top_radius = 0.095
	bnd.bottom_radius = 0.095
	bnd.height = 0.18
	band.mesh = bnd
	band.rotation.z = PI / 2.0
	band.position = Vector3(0.45, 1.2, 0.0)
	band.material_override = ArtDirection.oxblood_mat()
	band.visible = false
	add_child(band)
	if not StressSys.stress_changed.is_connected(_on_stress_face):
		StressSys.stress_changed.connect(_on_stress_face)
	_update_face(StressSys.value)

func _on_stress_face(_v: float) -> void:
	_update_face(_v)

func _update_face(v: float) -> void:
	# Steady→warm→shake→borrowed reads at couch distance via brows + head tint.
	var face := get_node_or_null("Face") as Node3D
	var head := get_node_or_null("Head") as MeshInstance3D
	if face == null or head == null:
		return
	var tilt := 0.0
	var drop := 0.0
	var tint := Color(0.93, 0.78, 0.66)
	if v > 80.0:
		tilt = 0.5; drop = -0.02; tint = Color(0.88, 0.68, 0.58)
	elif v > 60.0:
		tilt = 0.3; drop = -0.01; tint = Color(0.91, 0.74, 0.62)
	elif v > 30.0:
		tilt = 0.12
	(head.material_override as StandardMaterial3D).albedo_color = tint
	for b in face.get_children():
		var mi := b as MeshInstance3D
		if mi != null and String(mi.name).begins_with("Brow"):
			mi.rotation.z = tilt * (-1.0 if String(mi.name).ends_with("L") else 1.0)
			mi.position.y = 0.09 + drop

func _build_camera() -> void:
	_cam_pivot = Node3D.new()
	_cam_pivot.name = "CamPivot"
	_cam_pivot.position = Vector3(0.55, 1.6, 0.0)  # over-the-shoulder offset
	add_child(_cam_pivot)
	_spring = SpringArm3D.new()
	_spring.spring_length = 3.4
	_spring.margin = 0.3
	_cam_pivot.add_child(_spring)
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.current = true
	_spring.add_child(_camera)

func _unhandled_input(event: InputEvent) -> void:
	if not move_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.0028
		cam_pitch = clampf(cam_pitch - mm.relative.y * 0.0022, -0.6, 0.35)
	if event.is_action_pressed("interact"):
		if current_target != null:
			current_target.activate()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	var input_dir := Vector2.ZERO
	if move_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Camera-relative movement; player faces move dir, camera orbits via yaw.
	rotation.y = cam_yaw
	_cam_pivot.rotation.x = cam_pitch
	var speed := WALK_SPEED
	var want_sprint := Input.is_action_pressed("sprint") and GameState.can_sprint()
	if want_sprint and input_dir.length() > 0.1:
		speed = SPRINT_SPEED
	if carrying != "":
		speed *= CARRY_MULT
	speed *= speed_mod
	var dir := Vector3.ZERO
	if input_dir.length() > 0.01:
		var fwd := -global_transform.basis.z
		var right := global_transform.basis.x
		fwd.y = 0.0; right.y = 0.0
		fwd = fwd.normalized(); right = right.normalized()
		dir = (right * input_dir.x - fwd * input_dir.y)
		dir = dir.normalized()
		# Face movement (suit turns, camera stays over shoulder).
		var target_yaw := atan2(-dir.x, -dir.z)
		_mesh.rotation.y = lerp_angle(_mesh.rotation.y, target_yaw - rotation.y, 10.0 * delta)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
	_update_target()
	# Stairs spill at 90+ stress while carrying (GDD §5).
	if carrying != "" and StressSys.spill_carry_on_stairs() and speed_mod < 0.9:
		if randf() < delta * 0.05:
			GameState.carry_item = ""
			carrying = ""
			_refresh_carry_mesh()
			GameState.toast.emit("Hands shaking — you dropped the carry on the stairs.")

func _update_target() -> void:
	var best: Interactable = null
	var best_d := _interact_radius
	for n in get_tree().get_nodes_in_group("interactables"):
		var inter := n as Interactable
		if inter == null or not inter.can_use() or not inter.is_inside_tree():
			continue
		# Only consider interactables in the same room (visible + close).
		if not (inter as Node3D).visible:
			continue
		var d := (inter as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = inter
	if best != current_target:
		current_target = best
		interact_target_changed.emit(current_target)

func set_carry(item: String) -> void:
	carrying = item
	GameState.carry_item = item
	_refresh_carry_mesh()

func _refresh_carry_mesh() -> void:
	var tube := get_node_or_null("CarryMesh") as MeshInstance3D
	if tube != null:
		tube.visible = carrying != ""
	var band := get_node_or_null("CarryBand") as MeshInstance3D
	if band != null:
		band.visible = carrying != ""
