shader_type canvas_item;

uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform float noise_gradient_mix : hint_range(0.0, 1.0) = 0.55;
uniform float edge_width : hint_range(0.0, 0.25) = 0.07;
uniform float block_size : hint_range(1.0, 32.0) = 4.0;
uniform vec2 direction = vec2(0.0, 1.0);
uniform vec2 origin = vec2(0.5, 0.5);
uniform vec4 edge_color : source_color = vec4(0.65, 1.0, 0.12, 1.0);

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(157.2, 93.7))) * 31415.9265);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 blocks = floor(UV * (128.0 / block_size));
	float noise_mask = hash(blocks);
	vec2 safe_direction = normalize(direction + vec2(0.0001));
	float linear_mask = dot(UV - origin, safe_direction) * 0.7 + 0.5;
	float mask = mix(noise_mask, linear_mask, noise_gradient_mix);
	float visible_mask = step(threshold, mask);
	float edge = visible_mask - step(threshold + edge_width, mask);
	COLOR = vec4(mix(source.rgb, edge_color.rgb, edge), source.a * visible_mask);
}
