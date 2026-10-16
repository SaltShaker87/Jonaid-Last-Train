class_name ToonKit
extends RefCounted
## Turns imported glTF materials into the game's cartoon look: banded toon
## lighting, a little rim light, and an inverted-hull outline pass.
## Architecture (nodes named "Arch_*") skips the outline; ceilings and the
## distant skyline don't cast shadows so the sun can light interiors.

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

static var _cache := {}


static func apply(root: Node, outline_width: float = 0.018) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		_apply_mesh(mi as MeshInstance3D, outline_width)


static func _apply_mesh(mi: MeshInstance3D, width: float) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	var arch := _in_arch(mi)
	var nm := String(mi.name)
	if nm.begins_with("Arch_Ceiling") or nm.begins_with("Arch_Sky") or nm.begins_with("Arch_Ground"):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var skinned := mi.skin != null
	var am := mesh as ArrayMesh
	for i in mesh.get_surface_count():
		var src := mi.get_active_material(i)
		if not (src is StandardMaterial3D):
			continue
		var has_vc := am != null and (am.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0
		var key := "%d|%s|%s|%s" % [src.get_instance_id(), arch, has_vc, skinned]
		if not _cache.has(key):
			_cache[key] = _toon(src as StandardMaterial3D, not arch, has_vc and not skinned, skinned, width)
		mi.set_surface_override_material(i, _cache[key])


static func _in_arch(n: Node) -> bool:
	# Godot strips the "-col" suffix and may parent the mesh under a body.
	var cur := n
	for _i in 3:
		if cur == null:
			break
		if String(cur.name).begins_with("Arch_"):
			return true
		cur = cur.get_parent()
	return false


static func _toon(src: StandardMaterial3D, outline: bool, color_normal: bool, character: bool, width: float) -> StandardMaterial3D:
	var m := src.duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = false
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.metallic = 0.0
	m.metallic_specular = 0.25 if character else 0.15
	m.roughness = clampf(m.roughness, 0.55, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_BACK
	var clear := m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	if clear:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return m
	if character:
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.6
	if outline and not m.emission_enabled:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("width", width * (1.15 if character else 1.0))
		o.set_shader_parameter("use_color_normal", color_normal)
		m.next_pass = o
	return m
