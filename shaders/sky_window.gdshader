shader_type spatial;
render_mode unshaded, cull_back;
// Painted sky seen through windows: gradient, sun glow and drifting clouds.
uniform vec4 top : source_color = vec4(0.35, 0.6, 0.95, 1.0);
uniform vec4 horizon : source_color = vec4(0.98, 0.86, 0.72, 1.0);
uniform vec4 cloud : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform float night = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = UV;
	float h = 1.0 - uv.y;
	vec3 c = mix(horizon.rgb, top.rgb, smoothstep(0.0, 1.0, h));
	vec2 cp = vec2(wp.x + wp.z, wp.y) * 0.6 + vec2(TIME * 0.02, 0.0);
	float n = noise(cp * 2.0) * 0.6 + noise(cp * 4.3) * 0.3 + noise(cp * 9.1) * 0.1;
	float cl = smoothstep(0.55, 0.75, n) * smoothstep(0.1, 0.5, h);
	c = mix(c, cloud.rgb, cl * 0.85);
	// distant hills
	float hill = 0.18 + 0.06 * sin(wp.x * 1.3 + wp.z * 0.7) + 0.03 * sin(wp.x * 4.1);
	c = mix(c, vec3(0.45, 0.68, 0.45), step(h, hill) * 0.9);
	c = mix(c, c * vec3(0.25, 0.3, 0.55), night);
	ALBEDO = c * 1.15;
}
