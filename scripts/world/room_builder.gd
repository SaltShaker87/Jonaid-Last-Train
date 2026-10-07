extends RefCounted
class_name RoomBuilder
## Graybox + Blender-socket builder.
## Blender MCP blocks rooms/props, exports glTF with named sockets.
## Godot places from manifest. This builder is the offline fallback so the
## game runs end-to-end without Blender, and accepts glTF swaps later.
## Palette: espresso, antique gold, ivory, oxblood, subway gray (GDD §16).

static func office_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.76, 0.78)
	m.roughness = 0.9
	return m

static func floor(parent: Node3D, size: Vector2, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.2, size.y)
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mi.material_override = mat
	parent.add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.2, size.y)
	col.shape = shape
	body.position = pos
	body.add_child(col)
	parent.add_child(body)
	return mi

static func wall(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.position = pos
	body.add_child(col)
	parent.add_child(body)
	return mi

static func desk(parent: Node3D, pos: Vector3, wood := true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.8, 0.08, 0.9)
	top.mesh = tm
	top.position.y = 0.74
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.25, 0.16) if wood else Color(0.6, 0.62, 0.65)
	top.material_override = mat
	root.add_child(top)
	for sx in [-0.8, 0.8]:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.08, 0.74, 0.8)
		leg.mesh = lm
		leg.position = Vector3(sx, 0.37, 0)
		leg.material_override = mat
		root.add_child(leg)
	return root

static func box_prop(parent: Node3D, pos: Vector3, size: Vector3, color: Color, label := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
	if label != "":
		var l := Label3D.new()
		l.text = label
		l.font_size = 64
		l.pixel_size = 0.01
		l.position = pos + Vector3(0, size.y * 0.5 + 0.35, 0)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		parent.add_child(l)
	return mi

static func light(parent: Node3D, pos: Vector3, warm: bool, energy := 1.2) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = ArtDirection.TUNGSTEN if warm else ArtDirection.FLUORESCENT
	o.light_energy = energy
	o.omni_range = 14.0
	parent.add_child(o)
	return o

static func ceiling(parent: Node3D, size: Vector2, y := 3.2, color := Color(0.16, 0.16, 0.17)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.15, size.y)
	mi.mesh = bm
	mi.position = Vector3(0, y, 0)
	mi.material_override = ArtDirection.mat(color, 0.95)
	parent.add_child(mi)
	return mi

static func fluorescent_bank(parent: Node3D, pos: Vector3, count := 3, spacing := 3.0) -> void:
	for i in count:
		var x := (float(i) - float(count - 1) * 0.5) * spacing
		var tube := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.8, 0.08, 0.25)
		tube.mesh = bm
		tube.material_override = ArtDirection.fluorescent_tube_mat()
		tube.position = pos + Vector3(x, 0, 0)
		parent.add_child(tube)
		# Housing bar in espresso.
		var housing := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(2.0, 0.06, 0.4)
		housing.mesh = hm
		housing.material_override = ArtDirection.mat(ArtDirection.ESPRESSO, 0.8)
		housing.position = pos + Vector3(x, 0.08, 0)
		parent.add_child(housing)

static func tungsten_lamp(parent: Node3D, pos: Vector3, energy := 1.0) -> void:
	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = 0.42
	cone.height = 0.35
	shade.mesh = cone
	shade.material_override = ArtDirection.mat(ArtDirection.ESPRESSO, 0.7)
	shade.position = pos + Vector3(0, 0.35, 0)
	parent.add_child(shade)
	var bulb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.11
	sph.height = 0.22
	bulb.mesh = sph
	bulb.material_override = ArtDirection.tungsten_bulb_mat()
	bulb.position = pos + Vector3(0, 0.15, 0)
	parent.add_child(bulb)
	light(parent, pos, true, energy)

static func pillar(parent: Node3D, pos: Vector3, h := 3.2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, h, 0.6)
	mi.mesh = bm
	mi.position = pos + Vector3(0, h * 0.5, 0)
	mi.material_override = ArtDirection.mat(Color(0.68, 0.67, 0.65), 0.9)
	parent.add_child(mi)
	# Gold collar at top — Hansung house detail.
	var collar := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.7, 0.12, 0.7)
	collar.mesh = cm
	collar.material_override = ArtDirection.gold_mat()
	collar.position = pos + Vector3(0, h - 0.4, 0)
	parent.add_child(collar)
	return mi

static func bilingual(parent: Node3D, pos: Vector3, en: String, kr: String, accent: Color = Color(0.85, 0.66, 0.25)) -> Label3D:
	return ArtDirection.bilingual_sign(parent, pos, en, kr, accent)

static func platform_edge(parent: Node3D, pos: Vector3, length := 8.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.06, 0.5)
	mi.mesh = bm
	mi.material_override = ArtDirection.platform_edge_mat()
	mi.position = pos
	parent.add_child(mi)
	return mi

static func rug(parent: Node3D, pos: Vector3, size: Vector2, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.04, size.y)
	mi.mesh = bm
	mi.material_override = ArtDirection.mat(color, 0.98)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func interactable(parent: Node3D, pos: Vector3, weight: int, prompt: String, job_id := "", skill_id := "") -> Interactable:
	var inter := Interactable.new()
	inter.position = pos
	inter.weight = weight
	inter.prompt_text = prompt
	inter.job_id = job_id
	inter.skill_id = skill_id
	parent.add_child(inter)
	return inter

static func door_frame(parent: Node3D, pos: Vector3, label: String, color: Color) -> MeshInstance3D:
	return box_prop(parent, pos, Vector3(1.4, 2.6, 0.3), color, label)

static func crowd_lane(parent: Node3D, pos: Vector3, size: Vector3) -> Area3D:
	# Crowd slow volume: sets player.speed_mod while inside.
	var area := Area3D.new()
	area.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	parent.add_child(area)
	var tint := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.05, size.z)
	tint.mesh = bm
	tint.position = pos + Vector3(0, -0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.55, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.material_override = mat
	parent.add_child(tint)
	area.body_entered.connect(func(_b): 
		var p := _find_player(parent)
		if p != null:
			(p as Salaryman).speed_mod = Salaryman.CROWD_MULT
	)
	area.body_exited.connect(func(_b):
		var p := _find_player(parent)
		if p != null:
			(p as Salaryman).speed_mod = 1.0
	)
	return area

static func _find_player(n: Node) -> Node:
	var tree := n.get_tree()
	if tree == null:
		return null
	var ps := tree.get_nodes_in_group("player")
	return ps[0] if ps.size() > 0 else null

static func try_swap_blender_model(room: Node3D, socket_name: String, gltf_path: String) -> bool:
	# Called when assets/models/*.glb exists (Blender pipe). Non-fatal if missing.
	if not FileAccess.file_exists(gltf_path) and not ResourceLoader.exists(gltf_path):
		return false
	var packed := load(gltf_path) as PackedScene
	if packed == null:
		return false
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return false
	var room_base := room as RoomBase
	if room_base != null and room_base.sockets.has(socket_name):
		inst.position = (room_base.sockets[socket_name] as Node3D).position
	room.add_child(inst)
	return true
