shader_type canvas_item;

uniform float flow_speed = 1.2;
uniform float pulse_strength = 0.18;
uniform float glow_boost = 1.25;
uniform float alpha_mult = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	float mask = max(max(tex.r, tex.g), tex.b);

	float flow = sin((UV.x * 18.0) - TIME * flow_speed * 6.0) * 0.5 + 0.5;
	float flow2 = sin((UV.x * 32.0) - TIME * flow_speed * 10.0 + 1.4) * 0.5 + 0.5;
	float combined = mix(flow, flow2, 0.5);

	float pulse = 1.0 + combined * pulse_strength;

	vec3 color = tex.rgb * pulse * glow_boost;
	float alpha = tex.a * mask * alpha_mult;

	COLOR = vec4(color, alpha);
}