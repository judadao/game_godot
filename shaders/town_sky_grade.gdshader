shader_type canvas_item;

uniform vec4 grade_color : source_color = vec4(1.0, 0.68, 0.4, 1.0);
uniform float grade_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 vertex_color = COLOR;
	vec4 sampled = texture(TEXTURE, UV);
	float luminance = dot(sampled.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graded = luminance * grade_color.rgb;
	float horizon_weight = mix(0.35, 1.0, smoothstep(0.05, 0.9, UV.y));
	vec3 final_color = mix(sampled.rgb, graded, grade_strength * horizon_weight);
	COLOR = vec4(final_color, sampled.a) * vertex_color;
}
