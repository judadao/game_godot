shader_type canvas_item;
render_mode unshaded;

uniform vec4 deep_color : source_color = vec4(0.04, 0.28, 0.62, 0.86);
uniform vec4 body_color : source_color = vec4(0.08, 0.65, 0.84, 0.9);
uniform vec4 highlight_color : source_color = vec4(0.78, 0.98, 1.0, 1.0);
uniform vec2 flow = vec2(0.7, 0.15);
uniform float speed : hint_range(0.0, 5.0) = 0.8;
uniform float distortion : hint_range(0.0, 0.2) = 0.035;
uniform float pixel_steps : hint_range(8.0, 160.0) = 64.0;

float wave(vec2 point) {
	return sin(point.x * 19.0 + point.y * 7.0) * 0.55 + sin(point.x * 37.0 - point.y * 13.0) * 0.25;
}

void vertex() {
	VERTEX.y += sin(VERTEX.x * 0.055 + TIME * speed * 3.0) * 1.5;
}

void fragment() {
	vec2 pixel_uv = floor(UV * pixel_steps) / pixel_steps;
	float motion = TIME * speed;
	float distortion_value = wave(pixel_uv + flow * motion);
	vec2 distorted_uv = pixel_uv + vec2(distortion_value, wave(pixel_uv.yx - flow * motion)) * distortion;
	float band = wave(distorted_uv * 1.8 + flow * motion * 0.4) * 0.5 + 0.5;
	vec4 color = mix(deep_color, body_color, smoothstep(0.12, 0.75, band));
	float highlight = smoothstep(0.78, 0.92, band) * step(0.45, distorted_uv.y);
	color = mix(color, highlight_color, highlight);
	color.a *= texture(TEXTURE, UV).a;
	COLOR = color;
}
