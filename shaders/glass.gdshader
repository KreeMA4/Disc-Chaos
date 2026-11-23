shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.75, 0.9, 1.0, 0.18);
void fragment() {
	float f = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.5);
	ALBEDO = tint.rgb;
	ALPHA = clamp(tint.a + f * 0.45, 0.0, 0.85);
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = vec3(0.6, 0.75, 0.85) * f * 0.25;
}
