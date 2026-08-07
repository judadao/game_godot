shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 inner_color : source_color = vec4(0.02, 0.0, 0.06, 1.0);
uniform vec4 rim_color : source_color = vec4(0.62, 0.30, 1.0, 1.0);
uniform float flow_speed : hint_range(0.0, 8.0) = 1.4;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.22;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered);
	float angle = atan(centered.y, centered.x);
	float noise = hash(floor(centered * 22.0 + TIME * flow_speed));
	float spiral = sin(angle * 7.0 - TIME * flow_speed * 3.0 + radius * 34.0 + noise * 1.7);
	float rim = smoothstep(0.48, 0.30, radius) * smoothstep(0.18, 0.31, radius);
	float core = smoothstep(0.31, 0.08, radius);
	vec3 color = inner_color.rgb * core + rim_color.rgb * rim * (0.72 + spiral * distortion_strength);
	float alpha = max(core * inner_color.a, rim * rim_color.a);
	COLOR = vec4(color, alpha) * COLOR;
}
