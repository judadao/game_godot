shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 core_tint : source_color = vec4(1.0, 0.98, 0.82, 1.0);
uniform vec4 energy_tint : source_color = vec4(0.66, 0.79, 1.0, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.44, 0.38, 0.85, 1.0);
uniform float timeline : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float layer_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float energy_phase : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 345.45));
	point += dot(point, point + 34.345);
	return fract(point.x * point.y);
}

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec4 source = texture(TEXTURE, UV);
	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(texel.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(texel.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, texel.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(0.0, texel.y)).a);
	float outer_edge = max(0.0, neighbor_alpha - source.a * 0.58);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float stepped_time = floor((timeline + energy_phase) * 30.0) / 30.0;
	float flow = 0.5 + 0.5 * sin((UV.x + UV.y) * 24.0 - stepped_time * 18.0);
	float grain = hash21(floor(UV * vec2(textureSize(TEXTURE, 0)) / 4.0) + stepped_time);
	float dissolve_mask = smoothstep(dissolve_progress - 0.18, dissolve_progress + 0.10, grain + 1.0 - dissolve_progress);
	vec3 ramp = mix(shadow_tint.rgb, energy_tint.rgb, smoothstep(0.08, 0.62, luminance));
	ramp = mix(ramp, core_tint.rgb, smoothstep(0.56, 0.94, luminance + flow * 0.14));
	vec3 glow = energy_tint.rgb * outer_edge * (1.25 + intensity * 0.35);
	vec3 resolved = ramp * (0.86 + flow * 0.22 * intensity) + glow;
	float alpha = max(source.a, outer_edge * 0.72) * dissolve_mask * layer_alpha;
	COLOR = vec4(resolved, alpha) * COLOR;
}
