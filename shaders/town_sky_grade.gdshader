shader_type canvas_item;

uniform vec4 zenith_color : source_color = vec4(0.47, 0.64, 0.82, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.7, 0.4, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.79, 0.49, 1.0);
uniform float grade_strength : hint_range(0.0, 1.0) = 0.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;
uniform float sun_x : hint_range(-0.3, 1.3) = 0.12;

void fragment() {
	vec4 vertex_color = COLOR;
	vec4 sampled = texture(TEXTURE, UV);
	float vertical_mix = smoothstep(0.04, 0.62, UV.y);
	float luminance = dot(sampled.rgb, vec3(0.299, 0.587, 0.114));
	vec3 zenith_grade = sampled.rgb * mix(vec3(1.0), zenith_color.rgb * 1.34, 0.58);
	vec3 horizon_grade = horizon_color.rgb * mix(0.57, 1.08, luminance);
	vec3 preserved_grade = mix(zenith_grade, horizon_grade, vertical_mix * 0.86);
	float horizon_weight = mix(0.7, 1.0, smoothstep(0.04, 0.72, UV.y));

	vec2 glow_delta = vec2((UV.x - sun_x) * 0.85, (UV.y - 0.48) * 0.8);
	float glow = exp(-dot(glow_delta, glow_delta) * 5.5) * glow_strength;
	vec3 glow_screen = 1.0 - (1.0 - preserved_grade) * (1.0 - glow_color.rgb * glow * 0.42);
	vec3 graded = mix(preserved_grade, glow_screen, glow);
	vec3 final_color = mix(sampled.rgb, graded, grade_strength * horizon_weight);
	COLOR = vec4(final_color, sampled.a) * vertex_color;
}
