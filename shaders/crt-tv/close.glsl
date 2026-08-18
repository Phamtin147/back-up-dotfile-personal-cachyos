// CRT TV Close Shader Animation for Niri (Exact reverse of open)

float is_crt_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 close_color(vec3 coords_geo, vec3 size_geo) {
    float p = 1.0 - niri_clamped_progress; // 1.0 -> 0.0 (closing)
    vec2 uv = coords_geo.xy;

    // Stage 1 (p: 1.0 -> 0.25): Collapse vertical height (1.0 -> 0.0)
    // Stage 2 (p: 0.35 -> 0.0): Collapse horizontal line into dot (1.0 -> 0.0)
    float t_x = clamp(p / 0.35, 0.0001, 1.0);
    float t_y = clamp((p - 0.25) / 0.75, 0.0001, 1.0);

    vec2 center = vec2(0.5);
    vec2 st = (uv - center) / vec2(t_x, t_y) + center;

    if (st.x < 0.0 || st.x > 1.0 || st.y < 0.0 || st.y > 1.0) {
        return vec4(0.0);
    }

    vec3 tc = niri_geo_to_tex * vec3(st, 1.0);
    vec4 col = texture2D(niri_tex, tc.st);

    // CRT Scanline & Flash effect
    float scanline = sin(uv.y * size_geo.y * 1.5) * 0.08 * (1.0 - p);
    float flash = (1.0 - t_y) * 0.4;
    col.rgb = clamp(col.rgb + vec3(flash - scanline), 0.0, 1.0);

    return col;
}
