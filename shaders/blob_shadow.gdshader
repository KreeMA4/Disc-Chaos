shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
// Soft fake contact shadows under furniture (UV-based radial falloff, no texture).
uniform vec4 tint : source_color = vec4(0.22, 0.14, 0.26, 1.0);
void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float a = 1.0 - smoothstep(0.35, 1.0, length(d));
	ALBEDO = tint.rgb;
	ALPHA = a * 0.38 * COLOR.a;
}
