shader_type canvas_item;

uniform float wind_strength = 0.0;
uniform float wind_phase = 0.0;


void vertex() {
	float height_from_root = 1.0 - UV.y;
	float canopy_influence = smoothstep(0.18, 0.82, height_from_root);
	float branch_variation = 0.82 + sin(UV.y * 11.0 + wind_phase) * 0.18;
	VERTEX.x += wind_strength * canopy_influence * canopy_influence * branch_variation;
}
