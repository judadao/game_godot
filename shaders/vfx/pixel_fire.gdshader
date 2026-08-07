shader_type canvas_item;
render_mode unshaded;

uniform vec4 inner_color : source_color = vec4(1.0, 0.96, 0.55, 1.0);
uniform vec4 outer_color : source_color = vec4(1.0, 0.24, 0.03, 1.0);
uniform vec4 edge_color : source_color = vec4(0.45, 0.03, 0.01, 0.0);
uniform float speed : hint_range(0.0, 6.0) = 1.4;
uniform float turbulence : hint_range(0.0, 1.0) = 0.42;
uniform float pixel_size : hint_range(1.0, 32.0) = 6.0;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float low = mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x);
	float high = mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x);
	return mix(low, high, blend.y);
}

float layered_noise(vec2 point) {
	float result = 0.0;
	float amplitude = 0.58;
	for (int octave = 0; octave < 4; octave++) {
		result += value_noise(point) * amplitude;
		point = point * 2.03 + vec2(7.1, 3.7);
		amplitude *= 0.48;
	}
	return result;
}

void fragment() {
	vec2 snapped_uv = floor(UV * pixel_size) / pixel_size;
	vec2 centered = snapped_uv * 2.0 - 1.0;
	float vertical = 1.0 - snapped_uv.y;
	float animated_step = floor(TIME * speed * 12.0) / 12.0;
	float noise = layered_noise(vec2(centered.x * 2.4, snapped_uv.y * 3.2 - animated_step * 2.0));
	float width = mix(0.62, 0.12, pow(vertical, 0.72));
	float flame = smoothstep(width + 0.16, width - 0.08, abs(centered.x) + (noise - 0.5) * turbulence);
	flame *= smoothstep(0.02, 0.18, snapped_uv.y) * smoothstep(1.0, 0.68, snapped_uv.y);
	float heat = clamp(flame * (1.25 - snapped_uv.y) + noise * 0.18, 0.0, 1.0);
	vec4 palette = mix(edge_color, outer_color, smoothstep(0.12, 0.5, heat));
	palette = mix(palette, inner_color, smoothstep(0.58, 0.92, heat));
	COLOR = vec4(palette.rgb * intensity, palette.a * flame);
}
