shader_type canvas_item;
render_mode blend_add;

uniform float black_key_start : hint_range(0.0, 0.1) = 0.035;
uniform float black_key_end : hint_range(0.01, 0.25) = 0.17;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.62;
uniform float saturation : hint_range(0.5, 2.0) = 1.38;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 4.0;
	vec4 center = texture(TEXTURE, UV) * 0.34;
	vec4 bloom = center;
	bloom += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.11;
	bloom += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.11;
	bloom += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.11;
	bloom += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.11;
	bloom += texture(TEXTURE, UV + px) * 0.055;
	bloom += texture(TEXTURE, UV - px) * 0.055;
	bloom += texture(TEXTURE, UV + vec2(px.x, -px.y)) * 0.055;
	bloom += texture(TEXTURE, UV + vec2(-px.x, px.y)) * 0.055;
	float brightness = max(bloom.r, max(bloom.g, bloom.b));
	float minimum_channel = min(bloom.r, min(bloom.g, bloom.b));
	float chroma = brightness - minimum_channel;
	float keyed_alpha = max(
		smoothstep(black_key_start, black_key_end, brightness),
		smoothstep(0.02, 0.11, chroma)
	);
	float luma = dot(bloom.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid = max(vec3(0.0), mix(vec3(luma), bloom.rgb, saturation));
	COLOR = vec4(vivid * glow_strength, bloom.a * keyed_alpha) * COLOR;
}
