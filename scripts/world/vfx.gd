class_name VFX
## VFX pass — stamp glow, door close, ambient motes (GDD §16).
## Procedural, palette-locked, GL-compatible (CPUParticles3D). A new
## sparkle is a call from the room builder, not an asset.

static func quad(color: Color, opacity: Color = Color(1, 1, 1, 1)) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_color.a = opacity.a
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_receive_shadows = true
	q.material = m
	return q

## Ambient drifting motes: dust in fluorescent light, warmth at home.
static func motes(parent: Node3D, pos: Vector3, extent: Vector3, color: Color, rate: float, dir: Vector3 = Vector3.ZERO, speed := 0.12) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Motes"
	p.position = pos
	p.amount = maxi(8, int(rate * 8.0))
	p.lifetime = 6.0
	p.emitting = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extent
	p.direction = dir if dir != Vector3.ZERO else Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -0.01, 0)
	p.scale_amount_min = 0.012
	p.scale_amount_max = 0.03
	p.mesh = quad(color, Color(1, 1, 1, 0.45))
	parent.add_child(p)
	return p

## One-shot puff: stamp thump, doors shutting.
static func burst(parent: Node3D, pos: Vector3, color: Color, count: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Burst"
	p.position = pos
	p.amount = count
	p.lifetime = 0.8
	p.emitting = false
	p.one_shot = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, -0.4, 0)
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
	p.mesh = quad(color, Color(1, 1, 1, 0.7))
	parent.add_child(p)
	return p

## The stamp: plate + light + motes + thump. Returns the driver node.
static func stamp(parent: Node3D, pos: Vector3) -> StampFX:
	var s := StampFX.new()
	s.name = "StampFX"
	s.position = pos
	parent.add_child(s)
	return s

## Station doors. width = full closed width in meters.
static func door(parent: Node3D, pos: Vector3, width: float) -> DoorFX:
	var d := DoorFX.new()
	d.name = "DoorFX"
	d.position = pos
	parent.add_child(d)
	d.set_width(width)
	return d
