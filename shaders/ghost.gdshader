shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 color : source_color = vec4(0.4, 0.9, 1.0, 1.0);
void fragment() {
	float pulse = 0.55 + 0.25 * sin(TIME * 6.0);
	float f = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	ALBEDO = color.rgb * (0.25 + f) * pulse;
}
