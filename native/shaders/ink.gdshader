shader_type spatial;
render_mode unshaded, cull_disabled;
// Pen hatching ported from the original post pass (render.js): strokes are
// laid out in world units on the plane a surface faces, their spacing steps
// in powers of two with distance, and three stroke layers appear as the
// surface turns away from the light. Lit surfaces such as the floor stay
// clean paper.
uniform vec4 ink : source_color = vec4(0.1, 0.19, 0.76, 1.0);
uniform vec4 paper_color : source_color = vec4(0.97, 0.96, 0.91, 1.0);
uniform bool solid = false;
uniform float shade_scale = 1.0;
uniform float shade_bias = 0.0;
// 0: straight strokes, 1 and above: hand-drawn waver fixed to the surface.
uniform float detail = 1.0;
// 0: the original's crossed hatching. 1 (port addition): coloured-pencil
// shading, a soft wash of the ink colour under broken strokes that all lean
// the same way, so shaded faces no longer read as a grid.
uniform float style = 1.0;
varying vec3 world_position;
varying vec3 world_normal;
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
float stripes(vec2 p, vec2 dir, float spacing, float width) {
    float t = dot(p, vec2(-dir.y, dir.x));
    float f = abs(fract(t / spacing) - 0.5) * spacing;
    float soft = width * 0.6;
    return 1.0 - smoothstep(width * 0.5 - soft, width * 0.5 + soft, f);
}
// One layer of pencil strokes: every line has its own gaps and pressure.
float strokes(vec2 p, vec2 dir, float spacing, float width) {
    float across = dot(p, vec2(-dir.y, dir.x)) / spacing;
    float along = dot(p, dir) / spacing;
    float row = floor(across);
    float lifted = smoothstep(0.2, 0.42, vnoise(vec2(along * 0.3 + row * 1.7, row * 3.17)));
    float pressure = 0.62 + 0.38 * vnoise(vec2(along * 1.1, row * 5.3));
    return stripes(p, dir, spacing, width) * lifted * pressure;
}
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec3 paper = paper_color.rgb;
    vec3 n = normalize(world_normal);
    if (!FRONT_FACING) {
        n = -n;
    }
    float shade = clamp((dot(n, normalize(vec3(0.38, 0.82, 0.42))) * 0.5 + 0.5) * shade_scale + shade_bias, 0.0, 1.0);
    float d = -VERTEX.z;
    float hatch = 1.0;
    if (!solid) {
        float sc = VIEWPORT_SIZE.y / 900.0;
        vec2 hp;
        float sp;
        float w;
        if (d < 2.0) {
            // The held weapon rides with the camera, so the screen is its stable frame.
            hp = FRAGCOORD.xy;
            sp = 8.5 * sc;
            w = 1.5 * sc;
        } else {
            vec3 an = abs(n);
            hp = an.y > max(an.x, an.z) ? world_position.xz : (an.x > an.z ? world_position.zy : world_position.xy);
            float lod = exp2(floor(log2(max(1e-4, (0.025 * d) / 0.28))));
            sp = 0.28 * lod;
            w = sp * 0.13;
            if (detail > 0.5) {
                hp += (vnoise(hp * (1.2 / sp)) - 0.5) * sp * 0.15;
            }
        }
        if (style > 0.5) {
            float h1 = strokes(hp, vec2(0.7071, 0.7071), sp * 1.25, w * 1.2);
            float h2 = strokes(hp + vec2(3.7 * sp), vec2(0.8660, 0.5), sp * 0.95, w * 1.2);
            hatch = h1 * smoothstep(0.62, 0.42, shade);
            hatch = max(hatch, h2 * smoothstep(0.36, 0.20, shade));
            // Lit faces stay clean paper; the wash deepens as a face turns from the light.
            float wash = 0.22 * smoothstep(0.82, 0.15, shade);
            hatch = wash + hatch * (1.0 - wash);
        } else {
            float h1 = stripes(hp, vec2(0.7071, 0.7071), sp, w);
            float h2 = stripes(hp, vec2(-0.7071, 0.7071), sp * 1.15, w);
            float h3 = stripes(hp, vec2(0.2588, 0.9659), sp * 0.7, w);
            hatch = h1 * smoothstep(0.64, 0.5, shade);
            hatch = max(hatch, h2 * smoothstep(0.42, 0.32, shade));
            hatch = max(hatch, h3 * smoothstep(0.24, 0.14, shade));
            hatch = max(hatch, smoothstep(0.12, 0.0, shade) * 0.9);
        }
    }
    float fade = mix(1.0, 0.28, smoothstep(14.0, 110.0, d));
    ALBEDO = mix(paper, ink.rgb, hatch * 0.72 * fade);
}
