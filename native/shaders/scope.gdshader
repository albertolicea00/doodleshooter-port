shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

uniform vec4 paper_color : source_color = vec4(0.96, 0.95, 0.90, 1.0);
uniform vec4 ink_color : source_color = vec4(0.10, 0.19, 0.76, 1.0);

void fragment() {
    vec2 p = (UV - vec2(0.5)) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
    float radius = length(p);
    float outside = smoothstep(0.38, 0.385, radius);
    float lines = max(1.0 - smoothstep(0.0004, 0.0012, abs(p.x)), 1.0 - smoothstep(0.0004, 0.0012, abs(p.y)));
    float rim = (1.0 - smoothstep(0.003, 0.006, abs(radius - 0.38)));
    float ink_alpha = max(lines * (1.0 - outside) * 0.85, rim);
    float paper_alpha = outside * 0.98 * (1.0 - ink_alpha);
    COLOR = vec4(ink_color.rgb * ink_alpha + paper_color.rgb * paper_alpha, ink_alpha + paper_alpha);
}
