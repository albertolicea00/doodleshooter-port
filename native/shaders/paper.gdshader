shader_type canvas_item;
render_mode unshaded;
void fragment() {
    float ruled = 1.0 - smoothstep(0.0, 0.035, abs(fract(FRAGCOORD.y / 29.0) - 0.5));
    float margin = 1.0 - smoothstep(0.0, 1.2, abs(FRAGCOORD.x - 70.0));
    float noise = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 color = mix(vec3(0.38, 0.53, 0.82), vec3(0.86, 0.12, 0.2), margin);
    COLOR = vec4(color, max(ruled * 0.11, margin * 0.25) + noise * 0.018);
}
