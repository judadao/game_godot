shader_type canvas_item;

uniform float left_cleanup_band : hint_range(0.0, 0.5) = 0.45;
uniform float right_cleanup_band : hint_range(0.5, 1.0) = 0.8;
uniform float minimum_vertical_coverage : hint_range(1.0, 9.0) = 9.0;
uniform float left_disconnected_cut : hint_range(0.0, 0.25) = 0.0;
uniform float right_wisp_cut : hint_range(0.75, 1.0) = 1.0;
uniform vec4 cloud_tint : source_color = vec4(1.0);
uniform vec4 cloud_shadow_tint : source_color = vec4(1.0);
uniform vec4 cloud_light_tint : source_color = vec4(1.0);
uniform float cloud_lighting_strength : hint_range(0.0, 1.0) = 0.0;
uniform float variant_strength : hint_range(0.0, 1.0) = 0.0;
uniform float variant_phase : hint_range(0.0, 6.2832) = 0.0;
uniform float variant_peak_cut : hint_range(0.0, 0.2) = 0.0;
uniform float variant_tail_cut : hint_range(-0.25, 0.25) = 0.0;

void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	if (UV.x < left_disconnected_cut || UV.x > right_wisp_cut) {
		sampled.a = 0.0;
	}
	bool in_cleanup_band = UV.x < left_cleanup_band || UV.x > right_cleanup_band;
	if (sampled.a > 0.0 && in_cleanup_band) {
		float coverage = 0.0;
		coverage += step(0.1, texture(TEXTURE, UV + vec2(0.0, -4.0 * TEXTURE_PIXEL_SIZE.y)).a);
		coverage += step(0.1, texture(TEXTURE, UV + vec2(0.0, -3.0 * TEXTURE_PIXEL_SIZE.y)).a);
		coverage += step(0.1, texture(TEXTURE, UV + vec2(0.0, -2.0 * TEXTURE_PIXEL_SIZE.y)).a);
		coverage += step(0.1, texture(TEXTURE, UV + vec2(0.0, -1.0 * TEXTURE_PIXEL_SIZE.y)).a);
		coverage += step(0.1, sampled.a);
		coverage += step(0.1, texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
		coverage += step(0.1, texture(TEXTURE, UV + vec2(0.0, 2.0 * TEXTURE_PIXEL_SIZE.y)).a);
		coverage += step(0.1, texture(TEXTURE, UV + vec2(0.0, 3.0 * TEXTURE_PIXEL_SIZE.y)).a);
		coverage += step(0.1, texture(TEXTURE, UV + vec2(0.0, 4.0 * TEXTURE_PIXEL_SIZE.y)).a);
		if (coverage < minimum_vertical_coverage) {
			sampled.a = 0.0;
		}
	}
	vec4 below_1 = texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y));
	vec4 below_2 = texture(TEXTURE, UV + vec2(0.0, 2.0 * TEXTURE_PIXEL_SIZE.y));
	vec4 below_3 = texture(TEXTURE, UV + vec2(0.0, 3.0 * TEXTURE_PIXEL_SIZE.y));
	vec4 below_4 = texture(TEXTURE, UV + vec2(0.0, 4.0 * TEXTURE_PIXEL_SIZE.y));
	bool dark_chroma_fringe = sampled.b > 0.65 && sampled.r < 0.75;
	bool near_lower_edge = below_1.a < 0.1
		|| below_2.a < 0.1
		|| below_3.a < 0.1
		|| below_4.a < 0.1;
	if (sampled.a > 0.0 && near_lower_edge && dark_chroma_fringe) {
		vec4 inward = texture(TEXTURE, UV - vec2(0.0, 8.0 * TEXTURE_PIXEL_SIZE.y));
		if (inward.a > 0.1) {
			sampled.rgb = mix(inward.rgb, vec3(0.68, 0.82, 0.9), 0.65);
		} else {
			sampled.a = 0.0;
		}
	}
	bool lower_blue_outlier = UV.y > 0.5 && sampled.b - sampled.r > 0.18;
	if (sampled.a > 0.0 && lower_blue_outlier) {
		sampled.r = max(sampled.r, sampled.g * 0.8);
		sampled.b = min(sampled.b, sampled.g * 1.12);
	}
	float hand_painted_light = smoothstep(0.12, 0.9, 1.0 - UV.x) * 0.62
		+ smoothstep(0.2, 0.9, 1.0 - UV.y) * 0.38;
	vec3 directional_tint = mix(cloud_shadow_tint.rgb, cloud_light_tint.rgb, clamp(hand_painted_light, 0.0, 1.0));
	sampled.rgb *= mix(vec3(1.0), directional_tint, cloud_lighting_strength);
	// Erode a few source pixels from different directions. This preserves the
	// hand-drawn contour instead of carving obvious geometric crop lines.
	float erosion_pixels = variant_strength * (
		2.5 + variant_peak_cut * 20.0 + abs(variant_tail_cut) * 10.0
	);
	float horizontal_bias = 0.5 + 0.5 * sin(variant_phase);
	float left_support = texture(
		TEXTURE,
		UV - vec2(erosion_pixels * mix(0.48, 1.08, horizontal_bias), 0.0)
			* TEXTURE_PIXEL_SIZE
	).a;
	float right_support = texture(
		TEXTURE,
		UV + vec2(erosion_pixels * mix(1.08, 0.48, horizontal_bias), 0.0)
			* TEXTURE_PIXEL_SIZE
	).a;
	float top_support = texture(
		TEXTURE,
		UV - vec2(0.0, erosion_pixels * mix(0.58, 1.0, horizontal_bias))
			* TEXTURE_PIXEL_SIZE
	).a;
	float bottom_support = texture(
		TEXTURE,
		UV + vec2(0.0, erosion_pixels * mix(1.0, 0.58, horizontal_bias))
			* TEXTURE_PIXEL_SIZE
	).a;
	float silhouette_support = min(
		min(left_support, right_support),
		min(top_support, bottom_support)
	);
	float silhouette_keep = step(0.1, silhouette_support);
	sampled.a *= mix(
		1.0,
		silhouette_keep,
		step(0.001, variant_strength)
	);
	COLOR = sampled * cloud_tint;
}
