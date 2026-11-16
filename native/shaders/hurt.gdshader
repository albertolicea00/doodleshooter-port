shader_type canvas_item;
render_mode unshaded;
// Red scribble vignette from the original post pass: flashes when hurt and
// pulses while health is low.
uniform float hurt = 0.0;
uniform float low = 0.0;
void fragment() {
    vec2 centred = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
    float vignette = smoothstep(0.32, 0.9, length(centred));
    float t = dot(FRAGCOORD.xy, normalize(vec2(-0.8, 1.0)));
    float scribble = 0.55 + 0.45 * (1.0 - smoothstep(0.4, 2.4, abs(fract(t / 7.0) - 0.5) * 7.0));
    float amount = clamp(hurt * 3.0 + low * (0.35 + 0.25 * sin(TIME * 6.0)), 0.0, 1.0);
    COLOR = vec4(0.82, 0.13, 0.19, amount * vignette * scribble);
}
