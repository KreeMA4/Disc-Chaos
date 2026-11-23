shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
// Inverted-hull outline, used as next_pass on High/Ultra.
uniform float width = 0.008;
uniform vec4 line_color : source_color = vec4(0.16, 0.12, 0.22, 1.0);
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = line_color.rgb;
}
