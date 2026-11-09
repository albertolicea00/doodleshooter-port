shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 ink : source_color = vec4(0.1, 0.19, 0.76, 1.0);
uniform bool solid = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec3 paper = vec3(0.97, 0.96, 0.91);
    float shade = 1.0 - max(dot(normalize(world_normal), normalize(vec3(0.38, 0.82, 0.42))), 0.0);
    // World-space strokes stay attached to surfaces when the camera moves.
    vec3 p = world_position;
    float hatch = step(0.87, fract((p.x + p.y + p.z) * 5.0));
    float cross_hatch = step(0.93, fract((p.x - p.y + p.z) * 6.0));
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 5.0);
    float strength = max(edge * 0.8, hatch * smoothstep(0.15, 0.75, shade) * 0.65);
    strength = max(strength, cross_hatch * smoothstep(0.6, 1.0, shade) * 0.45);
    ALBEDO = solid ? ink.rgb : mix(paper, ink.rgb, strength + shade * 0.045);
}
