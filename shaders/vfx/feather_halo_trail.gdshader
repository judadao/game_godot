shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 head_color : source_color = vec4(1.0, 1.0, 0.86, 1.0);
uniform vec4 tail_color : source_color = vec4(0.65, 0.38, 1.0, 0.0);
uniform float timeline = 0.0;
uniform float energy : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	float center_distance = abs(UV.y - 0.5) * 2.0;
	float cross_section = 1.0 - smoothstep(0.55, 1.0, center_distance);
	float head = smoothstep(0.08, 1.0, UV.x);
	float cadence = 0.82 + 0.18 * sin(UV.x * 14.0 - timeline * 8.0);
	vec4 gradient_color = mix(tail_color, head_color, head);
	COLOR = vec4(
		gradient_color.rgb * energy * cadence,
		gradient_color.a * cross_section * smoothstep(0.0, 0.18, UV.x)
	) * COLOR;
}
