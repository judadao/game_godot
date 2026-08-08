shader_type canvas_item;

uniform float alpha_cutoff : hint_range(0.0, 0.3) = 0.045;
uniform float edge_softness : hint_range(0.01, 0.4) = 0.11;
uniform float bottom_fade_start : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 center = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 n0 = texture(TEXTURE, UV + vec2(px.x, 0.0));
	vec4 n1 = texture(TEXTURE, UV - vec2(px.x, 0.0));
	vec4 n2 = texture(TEXTURE, UV + vec2(0.0, px.y));
	vec4 n3 = texture(TEXTURE, UV - vec2(0.0, px.y));
	float weight = n0.a + n1.a + n2.a + n3.a;
	vec3 inner_rgb = (
		n0.rgb * n0.a + n1.rgb * n1.a + n2.rgb * n2.a + n3.rgb * n3.a
	) / max(weight, 0.001);
	float neighbor_floor = min(min(n0.a, n1.a), min(n2.a, n3.a));
	float boundary = (1.0 - neighbor_floor) * smoothstep(0.02, 0.92, center.a);
	center.rgb = mix(center.rgb, inner_rgb, boundary * 0.72);
	center.a *= smoothstep(alpha_cutoff, alpha_cutoff + edge_softness, center.a);
	float bottom_fade = 1.0;
	if (bottom_fade_start < 0.999) {
		bottom_fade = 1.0 - smoothstep(bottom_fade_start, 1.0, UV.y);
	}
	center.a *= bottom_fade;
	COLOR = center;
}
