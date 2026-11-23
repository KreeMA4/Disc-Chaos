shader_type spatial;
render_mode cull_back;
// Individually drawn items (physics bodies, puppets) sharing one material via instance uniforms.
#include "res://shaders/item_common.gdshaderinc"
instance uniform vec4 inst_custom = vec4(0.0);
instance uniform vec4 inst_color : source_color = vec4(1.0);
void fragment() {
	vec3 a; vec3 e; float m; float r;
	item_shade(UV, inst_custom, inst_color, NORMAL, VIEW, a, e, m, r);
	ALBEDO = a;
	EMISSION = e;
	METALLIC = m;
	ROUGHNESS = r;
}
