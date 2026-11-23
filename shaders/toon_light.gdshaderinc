// Soft two-band toon lighting with tinted shadows and a stepped highlight.
uniform float toon_soft : hint_range(0.01, 1.0) = 0.22;
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.58, 0.82, 1.0);
uniform float shadow_lift : hint_range(0.0, 1.0) = 0.32;
uniform float spec_amount : hint_range(0.0, 2.0) = 0.18;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-0.05, toon_soft, ndl) * ATTENUATION;
	vec3 band = mix(shadow_tint.rgb * shadow_lift, vec3(1.0), lit);
	// wrap the dark side a bit so omni lights read softly
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI * (0.55 + 0.45 * clamp(ndl * 0.5 + 0.5, 0.0, 1.0));
	vec3 h = normalize(LIGHT + VIEW);
	float s = smoothstep(0.90, 0.95, dot(NORMAL, h)) * lit;
	SPECULAR_LIGHT += s * spec_amount * LIGHT_COLOR / PI;
}
