extends RefCounted
class_name ArtDirection
## Art direction — GDD §16. Stylized semi-real, readable at couch distance.
## Palette: espresso, antique gold, ivory, oxblood, subway gray.
## Fluorescent office, tungsten home. Godot lights the rooms.

const ESPRESSO := Color(0.14, 0.11, 0.09)
const ESPRESSO_SUIT := Color(0.23, 0.22, 0.25)
const GOLD := Color(0.85, 0.66, 0.25)
const GOLD_DIM := Color(0.62, 0.47, 0.20)
const IVORY := Color(0.91, 0.87, 0.77)
const OXBLOOD := Color(0.45, 0.08, 0.10)
const SUBWAY := Color(0.55, 0.56, 0.58)
const SUBWAY_DARK := Color(0.32, 0.33, 0.35)
const FLUORESCENT := Color(0.90, 0.95, 1.0)
const TUNGSTEN := Color(1.0, 0.82, 0.60)
const PLATFORM_YELLOW := Color(0.95, 0.78, 0.20)

static func mat(color: Color, roughness := 0.85, metallic := 0.0, emission: Color = Color(0, 0, 0, 1), emission_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m

static func suit_mat() -> StandardMaterial3D:
	return mat(ESPRESSO_SUIT, 0.9)

static func gold_mat() -> StandardMaterial3D:
	return mat(GOLD, 0.35, 0.65)

static func ivory_mat() -> StandardMaterial3D:
	return mat(IVORY, 0.9)

static func oxblood_mat() -> StandardMaterial3D:
	return mat(OXBLOOD, 0.7)

static func fluorescent_tube_mat() -> StandardMaterial3D:
	return mat(Color(0.95, 0.97, 1.0), 0.4, 0.0, Color(0.9, 0.95, 1.0), 2.5)

static func tungsten_bulb_mat() -> StandardMaterial3D:
	return mat(Color(1.0, 0.9, 0.7), 0.4, 0.0, Color(1.0, 0.8, 0.55), 2.0)

static func platform_edge_mat() -> StandardMaterial3D:
	return mat(PLATFORM_YELLOW, 0.6, 0.0, PLATFORM_YELLOW, 0.6)

static func apply_room_lighting(room: Node3D, kind: String, env: Environment) -> void:
	# Called by rooms after build. kind: office/street/station/apartment/restaurant.
	match kind:
		"office":
			env.background_color = Color(0.07, 0.08, 0.09)
			env.ambient_light_color = Color(0.62, 0.68, 0.75)
			env.ambient_light_energy = 0.75
		"street":
			env.background_color = Color(0.05, 0.05, 0.07)
			env.ambient_light_color = Color(0.50, 0.50, 0.55)
			env.ambient_light_energy = 0.6
		"station":
			env.background_color = Color(0.06, 0.06, 0.07)
			env.ambient_light_color = Color(0.58, 0.60, 0.64)
			env.ambient_light_energy = 0.7
		"apartment", "restaurant":
			env.background_color = Color(0.09, 0.07, 0.05)
			env.ambient_light_color = Color(0.72, 0.60, 0.45)
			env.ambient_light_energy = 0.65
	# Fog stays off in GL Compatibility for headless safety; depth via lights.

static func stamp_label(parent: Node3D, pos: Vector3, text := "DO NOT COPY") -> Label3D:
	# The one always-readable in-world text (GDD §16).
	var l := Label3D.new()
	l.text = text
	l.font_size = 128
	l.pixel_size = 0.006
	l.modulate = OXBLOOD.lightened(0.15)
	l.outline_size = 24
	l.outline_modulate = IVORY
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = false
	l.position = pos
	l.rotation_degrees.y = 180.0
	parent.add_child(l)
	# Backing ivory plate for contrast at couch distance.
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.7, 0.45, 0.04)
	plate.mesh = bm
	plate.material_override = ivory_mat()
	plate.position = pos + Vector3(0, -0.05, -0.03)
	parent.add_child(plate)
	return l

static func bilingual_sign(parent: Node3D, pos: Vector3, en: String, kr: String, accent: Color) -> Label3D:
	var l := Label3D.new()
	l.text = "%s\n%s" % [en, kr]
	l.font_size = 72
	l.pixel_size = 0.008
	l.modulate = IVORY
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	# Gold underskirt bar.
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.08, 0.08)
	bar.mesh = bm
	bar.material_override = mat(accent, 0.4, 0.5)
	bar.position = pos + Vector3(0, -0.55, 0)
	parent.add_child(bar)
	return l
