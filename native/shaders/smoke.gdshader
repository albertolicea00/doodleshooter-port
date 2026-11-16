shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Port addition: a pencil-smudge smoke puff. Soft at the rim, scribbled
// inside, and never written to depth so the ink outline pass ignores it.
uniform float fade = 1.0;
varying vec3 local;
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
    local = VERTEX;
}
void fragment() {
    float rim = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float billow = vnoise(local.xy * 1.1 + vec2(TIME * 0.12, 0.0)) * 0.6 + vnoise(local.zy * 2.3 - vec2(0.0, TIME * 0.09)) * 0.4;
    float scribble = smoothstep(0.35, 0.65, 0.5 + 0.5 * sin((local.x + local.y * 0.7 + local.z * 0.4 + billow * 2.4) * 7.0));
    ALBEDO = mix(vec3(0.66, 0.67, 0.70), vec3(0.34, 0.36, 0.43), scribble * 0.55 + billow * 0.3);
    ALPHA = pow(rim, 1.5) * (0.5 + 0.3 * billow + 0.2 * scribble) * fade;
}
