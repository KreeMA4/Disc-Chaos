shader_type spatial;
render_mode cull_back;
// Vertex-colored toon material for merged props and characters.
#include "res://shaders/toon_light.gdshaderinc"
uniform vec4 albedo : source_color = vec4(1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.28;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform sampler2D pattern_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float pattern_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec2 pattern_scale = vec2(4.0, 4.0);
uniform float dust : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 base = albedo.rgb * COLOR.rgb;
	if (pattern_mix > 0.0) {
		vec4 pt = texture(pattern_tex, UV * pattern_scale);
		base = mix(base, pt.rgb * base * 1.4, pattern_mix * pt.a);
	}
	if (dust > 0.0) {
		float up = clamp(NORMAL.y, 0.0, 1.0);
		base = mix(base, vec3(0.78, 0.74, 0.68), dust * up * 0.35);
	}
	ALBEDO = base;
	ROUGHNESS = 0.85;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = base * rim * rim_strength;
}
