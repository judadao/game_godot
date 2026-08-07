shader_type canvas_item;

uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.25) = 0.06;
uniform vec4 edge_color : source_color = vec4(1.0, 0.82, 0.28, 1.0);
uniform float noise_scale : hint_range(1.0, 64.0) = 18.0;
uniform vec2 direction = vec2(0.0, -1.0);

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(29.3, 113.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x),
		blend.y
	);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 safe_direction = normalize(direction + vec2(0.0001));
	float directional_mask = dot(UV - vec2(0.5), safe_direction) * 0.35 + 0.5;
	float mask = mix(noise(UV * noise_scale), directional_mask, 0.28);
	float alpha_mask = step(threshold, mask);
	float edge = step(threshold, mask) - step(threshold + edge_width, mask);
	COLOR = vec4(mix(source.rgb, edge_color.rgb, edge), source.a * alpha_mask);
}
