shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.32, 0.78, 1.0, 0.62);
uniform float speed : hint_range(0.0, 12.0) = 7.0;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.5;
uniform float phase_offset : hint_range(0.0, 8.0) = 0.0;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.08, 0.72, across);
	float halo = 1.0 - smoothstep(0.24, 1.0, across);
	float cell = floor((UV.x + TIME * speed) * 22.0);
	float current_noise = mix(0.72, 1.18, hash21(vec2(cell, phase_offset)));
	float pulse = mix(0.84, 1.18, 0.5 + 0.5 * sin(TIME * speed * 4.7 + phase_offset));
	float energy = mix(pulse, current_noise, turbulence) * intensity;
	vec3 rgb = mix(glow_color.rgb, core_color.rgb, core) * energy;
	float alpha = COLOR.a * max(core, halo * glow_color.a) * clamp(energy, 0.0, 1.5);
	COLOR = vec4(rgb, alpha);
}
