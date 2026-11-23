shader_type spatial;
render_mode unshaded, cull_back;
uniform float strength = 1.6;
void fragment() {
	ALBEDO = COLOR.rgb * strength;
}
