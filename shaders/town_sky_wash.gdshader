shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 zenith_color : source_color = vec4(0.47, 0.64, 0.82, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.7, 0.4, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.79, 0.49, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 1.0) = 0.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;
uniform float sun_x : hint_range(-0.3, 1.3) = 0.12;

void fragment() {
	float horizon_mix = smoothstep(0.02, 0.72, UV.y);
	vec3 gradient_color = mix(zenith_color.rgb, horizon_color.rgb, horizon_mix);
	vec2 glow_delta = vec2((UV.x - sun_x) * 0.82, (UV.y - 0.46) * 0.78);
	float glow = exp(-dot(glow_delta, glow_delta) * 5.0) * glow_strength;
	vec3 glow_screen = 1.0 - (1.0 - gradient_color) * (1.0 - glow_color.rgb * glow * 0.4);
	float wash_alpha = atmosphere_strength * mix(0.2, 0.6, horizon_mix);
	COLOR = vec4(mix(gradient_color, glow_screen, glow), wash_alpha);
}
