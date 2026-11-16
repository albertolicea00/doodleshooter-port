shader_type canvas_item;
render_mode unshaded;
// Port addition: smears the drawn world when smoke gets in the player's eyes,
// when health is low, or after a heavy hit. `blur` softens the picture,
// `dizzy` makes it sway and split into a double image, `haze` greys it out.
uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur = 0.0;
uniform float dizzy = 0.0;
uniform float haze = 0.0;
void fragment() {
    vec2 uv = SCREEN_UV;
    uv += dizzy * vec2(sin(TIME * 1.7 + uv.y * 5.0), cos(TIME * 1.3 + uv.x * 4.0)) * 0.009;
    vec2 reach = SCREEN_PIXEL_SIZE * (1.0 / SCREEN_PIXEL_SIZE.y) * 0.014 * blur;
    vec3 color = texture(screen, uv).rgb;
    for (int i = 0; i < 8; i++) {
        float angle = float(i) * 2.39996;
        float radius = sqrt((float(i) + 0.5) / 8.0);
        color += texture(screen, uv + vec2(cos(angle), sin(angle)) * radius * reach).rgb;
    }
    color /= 9.0;
    vec2 ghost = vec2(sin(TIME * 2.1), cos(TIME * 1.6) * 0.4) * 0.02 * dizzy;
    color = mix(color, texture(screen, uv + ghost).rgb, 0.38 * dizzy);
    color = mix(color, vec3(0.74, 0.75, 0.76), haze * 0.6);
    COLOR = vec4(color, 1.0);
}
