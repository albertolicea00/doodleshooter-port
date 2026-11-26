shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float dim : hint_range(0.0, 0.5) = 0.0;
uniform vec4 tint : source_color = vec4(0.04, 0.05, 0.09, 1.0);

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * vec2(2.0);
	float dist = length(centered * vec2(1.0, 0.92));
	float inner = mix(0.95, 0.38, strength);
	float outer = mix(1.50, 1.08, strength);
	float edge = smoothstep(inner, outer, dist) * strength * 0.84;
	COLOR = vec4(tint.rgb, clamp(max(dim, edge), 0.0, 0.90));
}
