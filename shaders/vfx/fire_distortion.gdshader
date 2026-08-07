shader_type canvas_item;

uniform vec2 flow_direction = vec2(0.0, -1.0);
uniform float speed : hint_range(0.0, 5.0) = 1.0;
uniform float distortion_strength : hint_range(0.0, 0.12) = 0.025;
uniform float root_stability : hint_range(0.0, 1.0) = 0.78;
uniform float pixel_steps : hint_range(8.0, 128.0) = 48.0;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(41.7, 289.1))) * 951.1357);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), local);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x),
		blend.y
	);
}

void fragment() {
	vec2 pixel_uv = floor(UV * pixel_steps) / pixel_steps;
	vec2 flow_uv = pixel_uv * vec2(4.0, 5.0) + flow_direction * TIME * speed;
	vec2 offset = vec2(noise(flow_uv), noise(flow_uv + vec2(8.3, 2.9))) * 2.0 - 1.0;
	float tip_weight = mix(1.0 - root_stability, 1.0, 1.0 - pixel_uv.y);
	vec4 source = texture(TEXTURE, pixel_uv + offset * distortion_strength * tip_weight);
	COLOR = source;
}
