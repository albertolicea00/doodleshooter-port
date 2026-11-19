shader_type canvas_item;

uniform vec2 preview_size = vec2(1.0);
uniform float corner_radius = 10.0;
varying vec2 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec4 colour = COLOR;
    float radius = min(corner_radius, min(preview_size.x, preview_size.y) * 0.5);
    vec2 corner = vec2(clamp(local_position.x, radius, preview_size.x - radius), radius);
    if (local_position.y < radius) {
        float edge = length(local_position - corner) - radius;
        colour.a *= 1.0 - smoothstep(-0.75, 0.75, edge);
    }
    COLOR = colour;
}
