shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 head_color : source_color = vec4(0.95, 1.0, 1.0, 1.0);
uniform vec4 tail_color : source_color = vec4(0.25, 0.55, 1.0, 0.0);
uniform float timeline : hint_range(0.0, 1.0) = 0.0;
uniform float layer_energy : hint_range(0.0, 2.0) = 1.0;
uniform float edge_softness : hint_range(0.02, 0.5) = 0.18;

void fragment() {
	float longitudinal = smoothstep(0.0, 0.18, UV.x);
	float head = smoothstep(0.22, 1.0, UV.x);
	float center_distance = abs(UV.y - 0.5) * 2.0;
	float cross_section = 1.0 - smoothstep(1.0 - edge_softness, 1.0, center_distance);
	float pulse = 0.86 + 0.14 * sin(UV.x * 18.0 - timeline * 28.0);
	vec4 gradient_color = mix(tail_color, head_color, head);
	COLOR = vec4(
		gradient_color.rgb * layer_energy * pulse,
		gradient_color.a * longitudinal * cross_section
	) * COLOR;
}
