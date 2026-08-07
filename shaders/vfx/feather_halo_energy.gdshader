shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 edge_color : source_color = vec4(1.0, 0.88, 0.42, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 0.92, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.42, 0.24, 0.72, 1.0);
uniform float timeline = 0.0;
uniform float energy : hint_range(0.0, 2.5) = 1.0;
uniform float fade_amount : hint_range(0.0, 1.0) = 0.0;
uniform float aura_alpha : hint_range(0.0, 1.0) = 1.0;

float feather_noise(vec2 uv) {
	return fract(sin(dot(floor(uv * vec2(34.0, 18.0)), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float neighbor_alpha = (
		texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
		+ texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a
		+ texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a
	) * 0.25;
	float inner_edge = clamp(source.a - neighbor_alpha, 0.0, 1.0) * 5.0;
	float shaft_flow = pow(0.5 + 0.5 * sin(UV.x * 32.0 - timeline * 9.0), 7.0);
	float barb_flow = pow(0.5 + 0.5 * sin((UV.x + abs(UV.y - 0.5) * 0.34) * 25.0 - timeline * 12.0), 9.0);
	float noise_value = feather_noise(UV + vec2(timeline * 0.08, 0.0));
	float dissolve_mask = 1.0 - smoothstep(max(0.0, fade_amount - 0.18), fade_amount + 0.08, noise_value);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 body = mix(shadow_color.rgb, source.rgb, smoothstep(0.08, 0.72, luminance));
	body += edge_color.rgb * inner_edge * (0.28 + energy * 0.24);
	body += core_color.rgb * (shaft_flow * 0.30 + barb_flow * 0.18) * source.a * energy;
	COLOR = vec4(body, source.a * dissolve_mask * aura_alpha) * COLOR;
}
