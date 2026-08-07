shader_type canvas_item;

uniform float corrosion : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.055;
uniform vec4 acid_color : source_color = vec4(0.62, 1.0, 0.16, 1.0);
uniform vec4 rot_color : source_color = vec4(0.19, 0.05, 0.28, 1.0);
uniform float noise_scale : hint_range(2.0, 80.0) = 26.0;

float cellular(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	float nearest = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 seed = fract(sin(vec2(dot(cell + neighbor, vec2(127.1, 311.7)), dot(cell + neighbor, vec2(269.5, 183.3)))) * 43758.5453);
			nearest = min(nearest, length(neighbor + seed - local));
		}
	}
	return nearest;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float mask = cellular(UV * noise_scale);
	float removed = step(mask, corrosion);
	float edge = step(mask, corrosion + edge_width) - removed;
	vec3 stained = mix(source.rgb, rot_color.rgb, corrosion * 0.55);
	stained = mix(stained, acid_color.rgb, edge);
	COLOR = vec4(stained, source.a * (1.0 - removed));
}
