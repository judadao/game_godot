shader_type canvas_item;
// The semantic plate carries its own painted light. Alpha compositing preserves
// that material hierarchy; additive stacking seven copies of the same plate
// destroys hue and turns the contact frame into a white flash.
render_mode blend_mix, unshaded;

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float warp : hint_range(0.0, 1.0) = 0.0;
uniform float energy : hint_range(0.0, 2.0) = 1.0;
uniform float phase = 0.0;
uniform vec2 reveal_axis = vec2(1.0, 0.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform bool edge_only = false;
uniform float edge_width : hint_range(1.0, 5.0) = 1.0;
uniform float piece_softness : hint_range(0.0, 0.2) = 0.0;
uniform sampler2D semantic_texture : source_color, filter_linear_mipmap;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float material_mask(vec2 uv) {
	vec3 sampled = texture(semantic_texture, uv).rgb;
	return smoothstep(0.018, 0.13, max(sampled.r, max(sampled.g, sampled.b)));
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	vec2 axis = normalize(reveal_axis + vec2(0.0001));
	float reveal_coordinate = dot(centered, axis) * 0.72 + 0.5;
	float reveal_mask = 1.0 - smoothstep(reveal, reveal + 0.08, reveal_coordinate);
	float noise = hash21(floor(UV * 112.0) + floor(phase * 3.0));
	vec2 warped_uv = UV;
	warped_uv.x += sin(UV.y * 19.0 + phase) * 0.004 * warp;
	warped_uv.y += sin(UV.x * 15.0 - phase * 0.8) * 0.003 * warp;
	vec4 source = texture(semantic_texture, warped_uv);
	float mask = material_mask(warped_uv);
	vec2 texel = TEXTURE_PIXEL_SIZE * edge_width;
	float neighbor_max = max(max(material_mask(warped_uv + vec2(texel.x, 0.0)), material_mask(warped_uv - vec2(texel.x, 0.0))), max(material_mask(warped_uv + vec2(0.0, texel.y)), material_mask(warped_uv - vec2(0.0, texel.y))));
	float neighbor_min = min(min(material_mask(warped_uv + vec2(texel.x, 0.0)), material_mask(warped_uv - vec2(texel.x, 0.0))), min(material_mask(warped_uv + vec2(0.0, texel.y)), material_mask(warped_uv - vec2(0.0, texel.y))));
	float contour = clamp(max(neighbor_max - mask, mask - neighbor_min) * 1.7, 0.0, 1.0);
	float dissolve_keep = 1.0 - smoothstep(1.0 - dissolve - 0.16, 1.0 - dissolve + 0.02, noise);
	float semantic_mask = edge_only ? contour : mask;
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float piece_mask = piece_softness > 0.0001 ? smoothstep(0.0, piece_softness, edge_distance) : 1.0;
	float alpha = source.a * semantic_mask * reveal_mask * dissolve_keep * tint.a * piece_mask;
	vec3 compressed_source = source.rgb / (source.rgb + vec3(0.38));
	float exposure = mix(0.72, 1.0, clamp(energy / 1.65, 0.0, 1.0));
	vec3 material_color = edge_only ? tint.rgb * 0.78 : compressed_source * mix(vec3(1.0), tint.rgb, 0.2);
	COLOR = vec4(clamp(material_color * exposure, vec3(0.0), vec3(0.92)), alpha);
}
