shader_type spatial;
render_mode cull_back;
// Held / inspected items: dedicated high-resolution textures (>= 512 px tall).
#include "res://shaders/toon_light.gdshaderinc"
uniform sampler2D front_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D back_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D spine_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 plastic : source_color = vec4(0.9, 0.9, 0.95, 1.0);
uniform int mode = 0; // 0 case, 1 disc, 2 piece-with-cover, 3 plain
uniform bool steel = false;
uniform bool highlight = false;
float hash1(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
void fragment() {
	float face = floor(UV.x);
	vec2 uv = vec2(fract(UV.x), UV.y);
	vec3 c = plastic.rgb;
	float metal = 0.0;
	float rough = 0.7;
	vec3 em = vec3(0.0);
	if (mode == 1) {
		vec2 d = uv - 0.5;
		float r = length(d) * 2.0;
		if (face < 0.5) {
			c = texture(front_tex, uv).rgb;
			if (r < 0.36) c = mix(vec3(0.85, 0.87, 0.9), c, step(0.3, r));
		} else if (face < 1.5) {
			float ang = atan(d.y, d.x);
			vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + r * 1.6 + ang * 0.3 + dot(NORMAL, VIEW) * 1.5));
			c = mix(vec3(0.82, 0.84, 0.9), rainbow, 0.45);
			// readable ring text (sampled from the spine texture strip, wrapped around the hub)
			if (r > 0.37 && r < 0.45) {
				vec2 tuv = vec2(fract(ang / 6.2831 * 2.0), (r - 0.37) / 0.08);
				vec3 t = texture(spine_tex, tuv).rgb;
				c = mix(c, t * 0.6, 0.55);
			}
			metal = 0.7; rough = 0.18; em = rainbow * 0.08;
		} else {
			c = vec3(0.8, 0.82, 0.86);
		}
	} else if (mode == 3) {
		c = plastic.rgb;
	} else {
		if (face < 0.5) c = texture(front_tex, uv).rgb;
		else if (face < 1.5) c = texture(back_tex, uv).rgb;
		else if (face < 2.5) c = texture(spine_tex, uv).rgb;
		else { c = plastic.rgb; rough = 0.45; }
		if (steel && face < 2.5) {
			float l = dot(c, vec3(0.3, 0.55, 0.15));
			c = mix(vec3(0.72, 0.74, 0.8) * (0.55 + 0.6 * l), c, 0.18);
			metal = 0.85; rough = 0.28;
			em = vec3(0.9, 0.92, 1.0) * (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0) * 0.25 + 0.05);
		}
	}
	if (highlight) em += vec3(0.35, 0.85, 1.0) * (0.3 + 0.2 * sin(TIME * 7.0));
	ALBEDO = c;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = em;
}
