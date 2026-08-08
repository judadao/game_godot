shader_type canvas_item;

// The authored lance has a deliberately dark brown rock core surrounded by a
// much brighter gold trail. Keep that core readable while removing only the
// weakest transparent fringe.
uniform float alpha_cutoff : hint_range(0.0, 0.2) = 0.012;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.055;

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float brown_core = smoothstep(0.10, 0.26, sample_color.b)
		* (1.0 - smoothstep(0.78, 0.96, sample_color.g))
		* smoothstep(0.28, 0.50, sample_color.r);
	vec3 strengthened_core = sample_color.rgb * 1.22 + vec3(0.08, 0.035, 0.01);
	sample_color.rgb = mix(sample_color.rgb, strengthened_core, brown_core * 0.82);
	sample_color.a *= smoothstep(alpha_cutoff, alpha_cutoff + edge_softness, sample_color.a);
	COLOR = sample_color;
}
