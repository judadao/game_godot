shader_type canvas_item;

uniform float wind_strength = 0.0;
uniform float wind_phase = 0.0;
uniform float sunset_light_strength : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer_time = 0.0;
uniform float shimmer_phase = 0.0;
uniform vec4 sunset_leaf_light : source_color = vec4(1.13, 1.045, 0.9, 1.0);


void vertex() {
	float height_from_root = 1.0 - UV.y;
	float canopy_influence = smoothstep(0.18, 0.82, height_from_root);
	float branch_variation = 0.82 + sin(UV.y * 11.0 + wind_phase) * 0.18;
	VERTEX.x += wind_strength * canopy_influence * canopy_influence * branch_variation;
}


void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	float luminance = dot(sampled.rgb, vec3(0.299, 0.587, 0.114));
	float chroma = max(sampled.r, max(sampled.g, sampled.b))
		- min(sampled.r, min(sampled.g, sampled.b));
	float autumn_hue = smoothstep(0.015, 0.16, sampled.r - sampled.b)
		* smoothstep(-0.035, 0.12, sampled.g - sampled.b);
	float leaf_color = smoothstep(0.12, 0.38, chroma)
		* smoothstep(0.12, 0.42, luminance)
		* autumn_hue;
	float branch_and_root_guard = 1.0 - smoothstep(0.72, 0.94, UV.y);
	float leaf_mask = leaf_color * branch_and_root_guard * sampled.a;

	// Broad, phase-staggered clusters let highlights travel through the crown
	// without turning pixel noise into a synchronized yellow flash.
	float breeze_wave = 0.5 + 0.5 * sin(
		UV.x * 17.0 - UV.y * 11.0
		+ shimmer_time * 0.72
		+ shimmer_phase
		+ sin(wind_phase) * 0.45
	);
	float cluster_wave = 0.5 + 0.5 * sin(
		UV.x * 7.0 + UV.y * 5.0
		- shimmer_time * 0.31
		+ shimmer_phase * 1.7
	);
	float left_sun_reach = mix(0.64, 1.0, 1.0 - UV.x);
	float moving_highlight = mix(0.38, 1.0, breeze_wave * 0.62 + cluster_wave * 0.38);
	float highlight_amount = sunset_light_strength
		* leaf_mask
		* left_sun_reach
		* moving_highlight
		* 0.16;
	vec3 lit_color = sampled.rgb * mix(vec3(1.0), sunset_leaf_light.rgb, highlight_amount);
	COLOR = vec4(lit_color, sampled.a);
}
