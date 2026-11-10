shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 ink : source_color = vec4(0.10, 0.19, 0.76, 1.0);
float inverse_depth(vec2 uv, mat4 inverse_projection) {
    float depth = texture(depth_texture, uv).r;
    vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
    vec4 position = inverse_projection * vec4(ndc, 1.0);
    return 1.0 / max(0.04, -position.z / position.w);
}
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
    vec2 px = 1.25 / VIEWPORT_SIZE;
    float center = inverse_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
    float left = inverse_depth(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
    float right = inverse_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
    float above = inverse_depth(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
    float below = inverse_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
    float laplacian = abs(left + right + above + below - 4.0 * center);
    float edge = smoothstep(0.0015, 0.009, laplacian / max(0.02, center));
    ALBEDO = ink.rgb;
    ALPHA = edge * 0.86;
}
