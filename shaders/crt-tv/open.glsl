vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    float p = niri_clamped_progress;
    vec2 uv = coords_geo.xy;

    float t_x = clamp(p / 0.35, 0.001, 1.0);
    float t_y = clamp((p - 0.2) / 0.8, 0.001, 1.0);

    vec2 center = vec2(0.5);
    vec2 st = (uv - center) / vec2(t_x, t_y) + center;

    if (st.x < 0.0 || st.x > 1.0 || st.y < 0.0 || st.y > 1.0) {
        return vec4(0.0);
    }

    vec3 tc = niri_geo_to_tex * vec3(st, 1.0);
    vec4 col = texture2D(niri_tex, tc.st);

    float flash = (1.0 - t_y) * 0.35;
    col.rgb = clamp(col.rgb + vec3(flash), 0.0, 1.0);

    return col;
}
