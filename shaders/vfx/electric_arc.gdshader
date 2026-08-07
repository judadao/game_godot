shader_type canvas_item;
render_mode unshaded;

uniform vec4 core_color : source_color = vec4(0.94, 1.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.22, 0.55, 1.0, 0.6);
uniform float speed : hint_range(0.0, 12.0) = 4.0;
uniform float width : hint_range(0.002, 0.2) = 0.026;
uniform float glow_width : hint_range(0.01, 0.35) = 0.11;
uniform float variation : hint_range(0.0, 0.45) = 0.12;
uniform float segment_count : hint_range(4.0, 96.0) = 32.0;

float hash(float value) {
	return fract(sin(value * 91.3458) * 47453.5453);
}

void fragment() {
	float segment = floor(UV.x * segment_count);
	float frame = floor(TIME * speed * 18.0);
	float jitter = (hash(segment + frame * 17.0) - 0.5) * variation;
	float envelope = sin(UV.x * 3.14159265);
	float center = 0.5 + jitter * envelope;
	float distance_to_arc = abs(UV.y - center);
	float core = 1.0 - smoothstep(width * 0.35, width, distance_to_arc);
	float glow = 1.0 - smoothstep(width, glow_width, distance_to_arc);
	vec4 color = glow_color * glow + core_color * core;
	color.a = max(glow_color.a * glow, core_color.a * core);
	COLOR = color;
}
