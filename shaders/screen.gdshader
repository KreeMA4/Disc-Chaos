shader_type spatial;
render_mode unshaded, cull_back;
// Fake "game footage" for TVs, monitors, arcade cabinets and demo kiosks.
uniform float seed = 0.0;
uniform float brightness = 1.25;
void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.7 + seed * 13.0;
	float scene = floor(mod(t / 6.0 + seed, 3.0));
	vec3 c;
	if (scene < 0.5) {
		// platformer: sky, hills, bouncing hero
		c = mix(vec3(0.4, 0.75, 1.0), vec3(0.9, 0.95, 1.0), uv.y);
		float ground = step(0.78 + 0.04 * sin(uv.x * 12.0 + t * 2.0), uv.y);
		c = mix(c, vec3(0.35, 0.8, 0.35), ground);
		vec2 hero = vec2(0.3 + 0.05 * sin(t), 0.7 - abs(sin(t * 3.0)) * 0.2);
		c = mix(c, vec3(1.0, 0.4, 0.3), step(length((uv - hero) * vec2(1.6, 1.0)), 0.05));
		for (int i = 0; i < 4; i++) {
			vec2 coin = vec2(fract(0.2 * float(i) + 0.15 - t * 0.1), 0.45);
			c = mix(c, vec3(1.0, 0.85, 0.2), step(length((uv - coin) * vec2(1.6, 1.0)), 0.02));
		}
	} else if (scene < 1.5) {
		// racer: road perspective with stripes
		c = mix(vec3(1.0, 0.6, 0.4), vec3(0.4, 0.3, 0.7), uv.y * 0.5);
		float road = step(0.45, uv.y) * step(abs(uv.x - 0.5), (uv.y - 0.45) * 0.9 + 0.02);
		c = mix(c, vec3(0.25, 0.25, 0.3), road);
		float stripe = step(0.5, fract((1.0 / max(uv.y - 0.44, 0.01)) * 0.3 - t * 2.0)) * step(abs(uv.x - 0.5), 0.01 + (uv.y - 0.45) * 0.03);
		c = mix(c, vec3(1.0), stripe * road);
		c = mix(c, vec3(0.2, 0.7, 0.3), step(0.45, uv.y) * (1.0 - road));
		c = mix(c, vec3(0.9, 0.2, 0.3), step(abs(uv.x - 0.5 - 0.1 * sin(t)), 0.06) * step(abs(uv.y - 0.85), 0.04));
	} else {
		// space shooter: stars and ships
		c = vec3(0.04, 0.03, 0.12);
		vec2 g = floor(uv * vec2(40.0, 25.0) + vec2(0.0, t * 6.0));
		float star = step(0.97, fract(sin(dot(g, vec2(12.9, 78.2))) * 43758.5));
		c += vec3(star);
		c = mix(c, vec3(0.3, 0.9, 1.0), step(length((uv - vec2(0.5 + 0.2 * sin(t), 0.85)) * vec2(1.6, 1.0)), 0.04));
		c = mix(c, vec3(1.0, 0.3, 0.5), step(length((uv - vec2(0.5 + 0.3 * sin(t * 1.3), 0.25)) * vec2(1.6, 1.0)), 0.05));
		c = mix(c, vec3(1.0, 1.0, 0.5), step(abs(uv.x - 0.5 - 0.2 * sin(t)), 0.004) * step(uv.y, 0.8) * step(0.3, uv.y));
	}
	float scan = 0.9 + 0.1 * sin(uv.y * 300.0);
	float vig = 1.0 - 0.35 * length(uv - 0.5);
	ALBEDO = c * scan * vig * brightness;
}
