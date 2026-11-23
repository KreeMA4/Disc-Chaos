// Shared item shading. Atlas cells are addressed by an index; faces are encoded in UV.x's
// integer part: 0 = front / disc label, 1 = back / disc underside, 2 = spine / edge, 3 = plastic.
#include "res://shaders/toon_light.gdshaderinc"
uniform sampler2DArray covers : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2DArray spines : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2DArray labels : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 cover_grid = vec2(21.0, 15.0);
uniform vec2 cover_cell = vec2(0.046875, 0.06640625);
uniform vec2 spine_grid = vec2(10.0, 102.0);
uniform vec2 spine_cell = vec2(0.1, 0.0098);
uniform vec2 label_grid = vec2(21.0, 21.0);
uniform vec2 label_cell = vec2(0.046875, 0.046875);
uniform int mode = 0; // 0 case/box, 1 disc, 2 piece-with-cover, 3 plain figurine
uniform float dust_amount : hint_range(0.0, 1.0) = 0.0;

vec4 cell_sample(sampler2DArray tex, vec2 grid, vec2 cell, float idx, vec2 uv) {
	float per = grid.x * grid.y;
	float layer = floor((idx + 0.5) / per);
	float i = idx - layer * per;
	float cy = floor((i + 0.5) / grid.x);
	float cx = i - cy * grid.x;
	vec2 pad = cell * 0.04;
	vec2 a = vec2(cx, cy) * cell + pad + clamp(uv, 0.0, 1.0) * (cell - 2.0 * pad);
	return texture(tex, vec3(a, layer));
}

float hash1(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

void item_shade(vec2 uv_in, vec4 custom, vec4 plastic, vec3 nrm, vec3 view, out vec3 albedo, out vec3 emission, out float metallic, out float rough) {
	float face = floor(uv_in.x);
	vec2 uv = vec2(fract(uv_in.x), uv_in.y);
	int flags = int(custom.b + 0.5);
	bool steel = (flags & 1) != 0;
	bool hl = (flags & 2) != 0;
	metallic = 0.0;
	rough = 0.75;
	emission = vec3(0.0);
	vec3 c = plastic.rgb;
	if (mode == 1) {
		// disc: label on top, rainbow underside, silver edge
		vec2 d = uv - 0.5;
		float r = length(d) * 2.0;
		if (face < 0.5) {
			c = cell_sample(labels, label_grid, label_cell, custom.g, uv).rgb;
			if (r < 0.36) c = mix(vec3(0.85, 0.87, 0.9), c, step(0.3, r));
		} else if (face < 1.5) {
			float ang = atan(d.y, d.x);
			float vd = dot(nrm, view);
			vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + r * 1.6 + ang * 0.3 + vd * 1.5));
			c = mix(vec3(0.82, 0.84, 0.9), rainbow, 0.45);
			// tiny ring text near the hub
			float ring = step(0.38, r) * step(r, 0.43);
			float glyph = step(0.5, hash1(vec2(floor(ang * 18.0), custom.g)));
			c = mix(c, vec3(0.25, 0.25, 0.3), ring * glyph * 0.8);
			metallic = 0.7;
			rough = 0.18;
			emission = rainbow * 0.08;
		} else {
			c = vec3(0.8, 0.82, 0.86);
		}
	} else if (mode == 3) {
		c = face < 0.5 ? vec3(1.0) : (face < 1.5 ? vec3(0.12, 0.09, 0.18) : plastic.rgb);
		rough = 0.5;
	} else {
		if (face < 0.5) {
			c = cell_sample(covers, cover_grid, cover_cell, custom.r, uv).rgb;
		} else if (face < 1.5) {
			// back cover: tinted panel with three "screenshots" and blurb lines
			vec3 panel = mix(plastic.rgb, vec3(0.95), 0.25);
			c = panel;
			for (int i = 0; i < 3; i++) {
				vec2 o = vec2(0.08 + float(i) * 0.3, 0.12);
				if (uv.x > o.x && uv.x < o.x + 0.26 && uv.y > o.y && uv.y < o.y + 0.2) {
					vec2 suv = (uv - o) / vec2(0.26, 0.2);
					c = cell_sample(covers, cover_grid, cover_cell, custom.r, suv * 0.45 + vec2(0.1 + 0.2 * float(i), 0.35)).rgb;
				}
			}
			float lines = step(0.4, uv.y) * step(uv.y, 0.75) * step(0.5, fract(uv.y * 28.0)) * step(0.08, uv.x) * step(uv.x, 0.92);
			c = mix(c, c * 0.55, lines * 0.6);
			if (uv.y > 0.86 && uv.x > 0.65 && uv.x < 0.92) c = mix(vec3(1.0), vec3(0.0), step(0.5, fract(uv.x * 60.0)));
		} else if (face < 2.5) {
			c = cell_sample(spines, spine_grid, spine_cell, custom.r, uv).rgb;
		} else {
			c = plastic.rgb;
			rough = 0.45;
		}
		if (steel) {
			float l = dot(c, vec3(0.3, 0.55, 0.15));
			vec3 silver = vec3(0.72, 0.74, 0.8);
			c = mix(silver * (0.55 + 0.6 * l), c, 0.18);
			metallic = 0.85;
			rough = 0.28;
			float sheen = pow(1.0 - clamp(dot(nrm, view), 0.0, 1.0), 2.0);
			emission = vec3(0.9, 0.92, 1.0) * (sheen * 0.25 + 0.05);
		}
	}
	if (dust_amount > 0.0) {
		c = mix(c, vec3(0.72, 0.68, 0.62), dust_amount * 0.35 * clamp(nrm.y, 0.0, 1.0));
	}
	if (hl) {
		emission += vec3(0.35, 0.85, 1.0) * (0.35 + 0.25 * sin(TIME * 7.0));
	}
	albedo = c;
}
