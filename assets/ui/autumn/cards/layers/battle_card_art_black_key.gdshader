shader_type canvas_item;

uniform float black_floor : hint_range(0.0, 0.25) = 0.025;
uniform float black_feather : hint_range(0.01, 0.30) = 0.175;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float value = max(source.r, max(source.g, source.b));
	float chroma = value - min(source.r, min(source.g, source.b));
	float detail = value + chroma * 0.42;
	float keyed_alpha = smoothstep(black_floor, black_floor + black_feather, detail);
	COLOR = vec4(source.rgb, source.a * keyed_alpha);
}
