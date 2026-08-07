shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 primary_tint : source_color = vec4(1.0);
uniform vec4 secondary_tint : source_color = vec4(0.45, 0.8, 1.0, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.22, 0.16, 0.5, 1.0);
uniform float mutation_mix : hint_range(0.0, 1.0) = 0.35;
uniform float distortion_strength : hint_range(0.0, 0.08) = 0.0;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.2;
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float glow_strength : hint_range(0.0, 3.0) = 1.0;
uniform float timeline : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 345.45));
	point += dot(point, point + 34.345);
	return fract(point.x * point.y);
}

void fragment() {
	vec2 pixel_uv = floor(UV * vec2(textureSize(TEXTURE, 0))) / vec2(textureSize(TEXTURE, 0));
	float stepped_time = floor(timeline * 24.0) / 24.0;
	float wave = sin(pixel_uv.y * 18.0 + stepped_time * 12.0) * distortion_strength;
	vec2 sample_uv = pixel_uv + vec2(wave, 0.0);
	vec4 source = texture(TEXTURE, sample_uv);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 ramp = mix(shadow_tint.rgb, secondary_tint.rgb, smoothstep(0.08, 0.62, luminance));
	ramp = mix(ramp, primary_tint.rgb, smoothstep(0.58, 1.0, luminance));
	float noise = hash21(floor(sample_uv * 96.0) + stepped_time);
	float dissolve_edge = dissolve_progress * 1.12 - 0.06;
	float alpha_mask = smoothstep(dissolve_edge - 0.12, dissolve_edge + 0.08, noise + (1.0 - dissolve_progress));
	vec3 resolved = mix(source.rgb, ramp, mutation_mix);
	resolved *= 1.0 + glow_strength * 0.12 * source.a;
	resolved += secondary_tint.rgb * noise_amount * (noise - 0.5) * 0.12;
	COLOR = vec4(resolved, source.a * alpha_mask) * COLOR;
}
