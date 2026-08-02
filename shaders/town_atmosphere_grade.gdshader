shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 warm_highlight_tint : source_color = vec4(1.08, 1.0, 0.88, 1.0);
uniform vec4 cool_shadow_tint : source_color = vec4(0.88, 0.9, 1.03, 1.0);
uniform vec4 horizon_haze_color : source_color = vec4(1.0, 0.64, 0.34, 1.0);
uniform float grade_strength : hint_range(0.0, 1.0) = 0.0;
uniform float haze_strength : hint_range(0.0, 1.0) = 0.0;
uniform float sun_reach : hint_range(0.0, 1.0) = 0.8;
uniform vec4 sunset_light_color : source_color = vec4(1.0, 0.75, 0.38, 1.0);
uniform vec2 sun_direction = vec2(1.0, 0.18);
uniform float sunlight_strength : hint_range(0.0, 1.0) = 0.0;
uniform float cozy_palette_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 ray_world_offset = vec2(0.0);
uniform vec2 ray_canvas_scale = vec2(1.0);
uniform float cloud_shadow_strength : hint_range(0.0, 0.25) = 0.0;
uniform int cloud_shadow_count : hint_range(0, 8) = 0;
uniform vec4 cloud_shadows[3];
uniform vec4 cloud_shadow_shapes[3];
uniform int debug_view : hint_range(0, 3) = 0;

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float highlight_weight = smoothstep(0.24, 0.78, luminance);
	vec3 split_tint = mix(cool_shadow_tint.rgb, warm_highlight_tint.rgb, highlight_weight);
	vec3 split_color = source.rgb * split_tint;

	float horizon_weight = smoothstep(0.12, 0.88, SCREEN_UV.y);
	float west_light = mix(1.0, 1.0 - smoothstep(0.0, 1.0, SCREEN_UV.x), sun_reach);
	float haze_weight = horizon_weight * mix(0.32, 1.0, west_light) * haze_strength;
	vec3 haze_multiplier = mix(vec3(1.0), horizon_haze_color.rgb, haze_weight * 0.045);
	vec3 graded = split_color * haze_multiplier;

	vec2 normalized_sun_direction = normalize(sun_direction);
	vec2 ray_normal = vec2(-normalized_sun_direction.y, normalized_sun_direction.x);
	vec2 world_uv = SCREEN_UV / max(ray_canvas_scale, vec2(0.001)) + ray_world_offset;
	float ray_coordinate = dot(world_uv, ray_normal);
	float broad_rays = sin(ray_coordinate * 4.8 + sin(world_uv.x * 2.1) * 0.72 + 0.8);
	broad_rays += sin(ray_coordinate * 9.7 - world_uv.x * 1.35 + 2.1) * 0.34;
	broad_rays += sin(ray_coordinate * 17.3 + world_uv.y * 1.6 + 4.0) * 0.12;
	float ray_mask = smoothstep(-0.34, 0.46, broad_rays);
	float left_to_right_reach = mix(1.0, 0.82, smoothstep(0.0, 1.0, SCREEN_UV.x));
	float town_surface = smoothstep(0.05, 0.43, SCREEN_UV.y);
	float sunlight_mask = mix(0.2, 1.0, town_surface) * mix(0.22, 1.0, ray_mask);
	sunlight_mask *= left_to_right_reach;
	vec3 base_graded = mix(source.rgb, graded, grade_strength);
	float palette_luminance = dot(base_graded, vec3(0.299, 0.587, 0.114));
	float palette_chroma = max(base_graded.r, max(base_graded.g, base_graded.b))
		- min(base_graded.r, min(base_graded.g, base_graded.b));
	float saturation_scale = mix(1.035, 0.92, smoothstep(0.08, 0.62, palette_chroma));
	vec3 balanced_palette = vec3(palette_luminance)
		+ (base_graded - vec3(palette_luminance)) * saturation_scale;
	base_graded = mix(base_graded, balanced_palette, cozy_palette_strength);
	float contrast_gain = 1.0 + cozy_palette_strength * 0.42;
	base_graded = clamp((base_graded - vec3(0.5)) * contrast_gain + vec3(0.5), vec3(0.0), vec3(1.0));
	float material_response = mix(0.72, 1.0, smoothstep(0.08, 0.72, palette_luminance));
	float sunlight_amount = sunlight_strength * sunlight_mask * material_response;
	float light_luminance = max(dot(sunset_light_color.rgb, vec3(0.299, 0.587, 0.114)), 0.001);
	vec3 normalized_light_color = sunset_light_color.rgb / light_luminance;
	vec3 sunlight_chroma = mix(vec3(1.0), normalized_light_color, 0.15);
	vec3 sunlight_screen = base_graded * (1.0 + sunlight_amount * 0.22)
		* mix(vec3(1.0), sunlight_chroma, sunlight_amount);

	float cloud_shadow_mask = 0.0;
	for (int index = 0; index < 3; index++) {
		if (index >= cloud_shadow_count) {
			continue;
		}
		vec4 shadow = cloud_shadows[index];
		vec4 shape = cloud_shadow_shapes[index];
		vec2 shadow_delta = SCREEN_UV - shadow.xy;
		shadow_delta.x -= shadow_delta.y * shape.y;
		vec2 normalized_shadow = shadow_delta / vec2(max(shadow.z, 0.001), max(shape.x, 0.001));
		float broken_edge = sin(normalized_shadow.x * 2.4 + shape.z) * 0.11;
		broken_edge += sin(normalized_shadow.x * 5.3 - shape.z * 0.7) * 0.045;
		broken_edge += sin(normalized_shadow.x * 9.1 + shape.z * 1.3) * 0.018;
		float cross_distance = abs(normalized_shadow.y + broken_edge);
		float cross_falloff = 1.0 - smoothstep(0.48 - shape.w, 1.08 + shape.w, cross_distance);
		float length_warp = 1.0 + sin(normalized_shadow.y * 3.0 + shape.z) * 0.09;
		float along_falloff = 1.0 - smoothstep(0.62, 1.32, abs(normalized_shadow.x) * length_warp);
		float contour_variation = sin(normalized_shadow.x * 3.7 + shape.z)
			+ sin(normalized_shadow.x * 7.9 - normalized_shadow.y * 1.8 + shape.z * 0.4) * 0.35;
		float feather_variation = mix(0.78, 1.0, smoothstep(-0.9, 0.65, contour_variation));
		float soft_cloud_shape = cross_falloff * along_falloff * feather_variation;
		cloud_shadow_mask = 1.0 - (1.0 - cloud_shadow_mask) * (1.0 - soft_cloud_shape * shadow.w);
	}
	float sky_blue = smoothstep(0.1, 0.28, source.b - max(source.r, source.g));
	float source_chroma = max(source.r, max(source.g, source.b)) - min(source.r, min(source.g, source.b));
	float bright_emissive = smoothstep(0.68, 0.9, luminance) * smoothstep(0.24, 0.48, source_chroma);
	float violet_emissive = smoothstep(0.08, 0.24, source.b - source.g)
		* smoothstep(0.02, 0.18, source.r - source.g);
	float emissive_preservation = max(bright_emissive, violet_emissive);
	float shadow_surface = town_surface * mix(1.0, 0.08, sky_blue) * (1.0 - emissive_preservation);
	float final_shadow = cloud_shadow_mask * shadow_surface * cloud_shadow_strength;
	vec3 cloud_shaded = sunlight_screen * mix(vec3(1.0), vec3(0.6, 0.68, 0.84), final_shadow);

	if (debug_view == 1) {
		COLOR = vec4(vec3(sunlight_mask), 1.0);
	} else if (debug_view == 2) {
		COLOR = vec4(vec3(cloud_shadow_mask * shadow_surface), 1.0);
	} else if (debug_view == 3) {
		float diagnostic_mask = cloud_shadow_mask * shadow_surface;
		vec3 diagnostic_overlay = mix(source.rgb, vec3(1.0, 0.0, 0.72), diagnostic_mask * 0.84);
		COLOR = vec4(diagnostic_overlay, source.a);
	} else {
		COLOR = vec4(cloud_shaded, source.a);
	}
}
