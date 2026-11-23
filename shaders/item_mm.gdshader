shader_type spatial;
render_mode cull_back;
// MultiMesh item batches: per-instance atlas index in INSTANCE_CUSTOM, case color in COLOR.
#include "res://shaders/item_common.gdshaderinc"
varying flat vec4 v_custom;
varying vec4 v_color;
void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_color = COLOR;
}
void fragment() {
	vec3 a; vec3 e; float m; float r;
	item_shade(UV, v_custom, v_color, NORMAL, VIEW, a, e, m, r);
	ALBEDO = a;
	EMISSION = e;
	METALLIC = m;
	ROUGHNESS = r;
}
