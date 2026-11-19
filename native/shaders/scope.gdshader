shader_type canvas_item;
void fragment() {
    vec2 p = (UV - vec2(0.5)) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
    float radius = length(p);
    float outside = smoothstep(0.38, 0.385, radius);
    float lines = max(1.0 - smoothstep(0.0004, 0.0012, abs(p.x)), 1.0 - smoothstep(0.0004, 0.0012, abs(p.y)));
    float rim = (1.0 - smoothstep(0.003, 0.006, abs(radius - 0.38)));
    COLOR = vec4(vec3(93), max(outside * 0.98, max(lines * 0.85, rim)));
}
