shader_type spatial;
// Inverted-hull cartoon outline, used as next_pass on toon materials.
// Environment meshes carry smoothed normals in COLOR (baked in Blender, see
// blender/lib.py) so hard-edged boxes don't crack at the corners; skinned
// characters use their real (smooth) normals.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.10, 0.08, 0.12, 1.0);
uniform float width = 0.02;
uniform bool use_color_normal = false;

void vertex() {
	vec3 n = NORMAL;
	if (use_color_normal) {
		n = normalize(COLOR.rgb * 2.0 - 1.0);
	}
	VERTEX += n * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
