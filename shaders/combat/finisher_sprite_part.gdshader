shader_type canvas_item;
render_mode blend_mix;

uniform float black_key_start : hint_range(0.0, 0.1) = 0.028;
uniform float black_key_end : hint_range(0.01, 0.25) = 0.15;
uniform float highlight_rolloff : hint_range(0.5, 2.0) = 1.18;
uniform float exposure : hint_range(0.5, 2.0) = 1.32;
uniform float saturation : hint_range(0.5, 2.0) = 1.26;

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float brightness = max(sample_color.r, max(sample_color.g, sample_color.b));
	float minimum_channel = min(sample_color.r, min(sample_color.g, sample_color.b));
	float chroma = brightness - minimum_channel;
	float keyed_alpha = max(
		smoothstep(black_key_start, black_key_end, brightness),
		smoothstep(0.018, 0.1, chroma)
	);
	vec3 compressed = sample_color.rgb * exposure / (vec3(1.0) + sample_color.rgb * 0.10);
	float luma = dot(compressed, vec3(0.2126, 0.7152, 0.0722));
	compressed = mix(vec3(luma), compressed, saturation);
	compressed = max(compressed, vec3(0.0));
	compressed = pow(compressed, vec3(1.0 / highlight_rolloff));
	COLOR = vec4(compressed, sample_color.a * keyed_alpha) * COLOR;
}
