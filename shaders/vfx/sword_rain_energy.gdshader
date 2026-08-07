shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 edge_color : source_color = vec4(0.35, 0.72, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.94, 0.99, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.23, 0.22, 0.62, 1.0);
uniform float timeline : hint_range(0.0, 1.0) = 0.0;
uniform float energy : hint_range(0.0, 3.0) = 1.0;
uniform float lock_amount : hint_range(0.0, 1.0) = 0.0;
uniform float ghost_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float neighbor_alpha = (
		texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
		+ texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a
		+ texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a
	) * 0.25;
	float inner_edge = clamp(source.a - neighbor_alpha, 0.0, 1.0) * 5.0;
	float flowing_band = pow(
		0.5 + 0.5 * sin((UV.x * 0.65 + UV.y) * 24.0 - timeline * 32.0),
		6.0
	);
	float lock_band = pow(max(0.0, 1.0 - abs(UV.x - 0.5) * 2.0), 4.0) * lock_amount;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 metal = mix(shadow_color.rgb, source.rgb, smoothstep(0.08, 0.72, luminance));
	vec3 energized = metal + edge_color.rgb * inner_edge * (0.28 + energy * 0.22);
	energized += core_color.rgb * flowing_band * source.a * energy * 0.34;
	energized += edge_color.rgb * lock_band * source.a * energy * 0.38;
	COLOR = vec4(energized, source.a * ghost_alpha) * COLOR;
}
