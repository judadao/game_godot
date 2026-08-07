shader_type particles;
render_mode keep_data;

uniform float initial_speed = 140.0;
uniform float spiral_strength = 2.4;
uniform vec3 gravity = vec3(0.0, 90.0, 0.0);
uniform vec4 start_color : source_color = vec4(0.9, 1.0, 1.0, 1.0);
uniform vec4 end_color : source_color = vec4(0.2, 0.5, 1.0, 0.0);

void start() {
	float ratio = float(NUMBER % 64u) / 64.0;
	float angle = ratio * 6.28318530718;
	VELOCITY = vec3(cos(angle), sin(angle), 0.0) * initial_speed;
	COLOR = start_color;
	CUSTOM.x = 0.0;
}

void process() {
	CUSTOM.x = clamp(CUSTOM.x + DELTA / max(LIFETIME, 0.001), 0.0, 1.0);
	vec2 tangent = normalize(vec2(-VELOCITY.y, VELOCITY.x) + vec2(0.0001));
	VELOCITY.xy += tangent * spiral_strength * initial_speed * DELTA;
	VELOCITY += gravity * DELTA;
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	COLOR = mix(start_color, end_color, CUSTOM.x);
	float scale_value = mix(1.0, 0.15, CUSTOM.x);
	vec3 axis_x = normalize(TRANSFORM[0].xyz + vec3(0.0001, 0.0, 0.0));
	vec3 axis_y = normalize(TRANSFORM[1].xyz + vec3(0.0, 0.0001, 0.0));
	TRANSFORM[0].xyz = axis_x * scale_value;
	TRANSFORM[1].xyz = axis_y * scale_value;
}
