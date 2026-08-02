shader_type canvas_item;

uniform float left_cleanup_band : hint_range(0.0, 0.5) = 0.45;
uniform float right_cleanup_band : hint_range(0.5, 1.0) = 0.8;
uniform float minimum_vertical_coverage : hint_range(1.0, 9.0) = 9.0;
uniform float left_disconnected_cut : hint_range(0.0, 0.25) = 0.0;
uniform float right_wisp_cut : hint_range(0.75, 1.0) = 1.0;
uniform vec4 cloud_tint : source_color = vec4(1.0);

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
	COLOR = sampled * cloud_tint;
}
