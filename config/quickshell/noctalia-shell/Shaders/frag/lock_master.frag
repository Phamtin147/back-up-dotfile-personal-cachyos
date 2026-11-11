#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int effectType;
} ubuf;

#define PI 3.141592653589793
#define SQRT_2 1.41421356237

// --- Hash & Random Primitives ---
float rand1(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float rand1d(float n) {
    return fract(sin(n) * 43758.5453);
}

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// --- Perlin 2D Noise ---
float perlinNoise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = rand1(i);
    float b = rand1(i + vec2(1.0, 0.0));
    float c = rand1(i + vec2(0.0, 1.0));
    float d = rand1(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// --- FBM Noise ---
float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * perlinNoise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float p = clamp(ubuf.progress, 0.0, 1.0);
    vec4 col = texture(source, uv);

    // 0: Perlin Noise Dissolve
    if (ubuf.effectType == 0) {
        float n = perlinNoise(uv * 4.0);
        float smoothness = 0.02;
        float pr = mix(-smoothness, 1.0 + smoothness, p);
        float q = smoothstep(pr - smoothness, pr + smoothness, n);
        col *= (1.0 - q);
    }
    // 1: Circle Iris Reveal
    else if (ubuf.effectType == 1) {
        float dist = SQRT_2 * distance(vec2(0.5), uv);
        float m = smoothstep(-0.3, 0.0, dist - p * 1.3);
        col *= (1.0 - m);
    }
    // 2: Polar Function Reveal
    else if (ubuf.effectType == 2) {
        float angle = atan(uv.y - 0.5, uv.x - 0.5);
        float radius = (cos(5.0 * angle) + 4.0) / 4.0;
        float diff = length(uv - vec2(0.5));
        float reveal = step(diff, radius * p);
        col *= reveal;
    }
    // 3: Glitch / Chromatic Aberration & Slice
    else if (ubuf.effectType == 3) {
        float intensity = (1.0 - p) * (1.0 - p);
        float tick = floor(p * 50.0);
        float r1 = rand1d(tick * 1.13);
        float r2 = rand1d(tick * 2.37);
        vec2 off = vec2(r1 - 0.5, r2 - 0.5) * intensity * 0.08;
        float slice = floor(uv.y * 22.0);
        float slice_offset = (rand1d(slice + tick) - 0.5) * intensity * 0.06;
        vec2 uv_r = clamp(uv + off + vec2(slice_offset, 0.0), vec2(0.0), vec2(1.0));
        vec2 uv_b = clamp(uv - off - vec2(slice_offset * 0.7, 0.0), vec2(0.0), vec2(1.0));
        float col_r = texture(source, uv_r).r;
        float col_g = col.g;
        float col_b = texture(source, uv_b).b;
        col = vec4(col_r, col_g, col_b, col.a) * smoothstep(0.0, 0.25, p);
    }
    // 4: Pixelate Wave
    else if (ubuf.effectType == 4) {
        float pixel_size = mix(0.06, 0.0005, p * p);
        vec2 pixelated_uv = floor(uv / pixel_size) * pixel_size + pixel_size * 0.5;
        col = texture(source, clamp(pixelated_uv, vec2(0.0), vec2(1.0))) * smoothstep(0.0, 0.25, p);
    }
    // 5: Random Squares
    else if (ubuf.effectType == 5) {
        vec2 sz = vec2(12.0);
        float r = rand1(floor(sz * uv));
        float reveal = smoothstep(0.0, -0.4, r - (p * 1.4));
        col *= reveal;
    }
    // 6: FBM Smoke / Dissolve
    else if (ubuf.effectType == 6) {
        float n = fbm(uv * 5.0);
        float smoothness = 0.03;
        float pr = mix(-smoothness, 1.0 + smoothness, p);
        float q = smoothstep(pr - smoothness, pr + smoothness, n);
        col *= (1.0 - q);
    }
    // 7: Ripple Waves
    else if (ubuf.effectType == 7) {
        vec2 dir = uv - vec2(0.5);
        float dist = length(dir);
        float intensity = (1.0 - p) * (1.0 - p);
        vec2 offset = dir * (sin(p * dist * 90.0 - p * 45.0) + 0.5) / 32.0;
        vec2 wuv = clamp(uv + offset * intensity, vec2(0.0), vec2(1.0));
        col = texture(source, wuv) * smoothstep(0.0, 0.2, p);
    }
    // 8: Flyeye Lens
    else if (ubuf.effectType == 8) {
        float inv = 1.0 - p;
        vec2 disp = 0.04 * vec2(cos(45.0 * uv.x), sin(45.0 * uv.y));
        vec2 wuv = clamp(uv + inv * disp, vec2(0.0), vec2(1.0));
        col = texture(source, wuv) * p;
    }
    // 9: Overexposure Bloom
    else if (ubuf.effectType == 9) {
        float to_m = p + sin(PI * p) * 0.65;
        col = vec4(col.rgb * to_m, col.a * p);
    }
    // 10: Directional Slide / Wipe
    else if (ubuf.effectType == 10) {
        vec2 q = uv + (1.0 - p) * vec2(0.0, 1.0);
        float inside = step(0.0, q.y) * step(q.y, 1.0) * step(0.0, q.x) * step(q.x, 1.0);
        col *= inside;
    }
    // 11: Voronoi Shatter
    else if (ubuf.effectType == 11) {
        vec2 q = uv * 14.0;
        vec2 g = floor(q);
        vec2 f = fract(q);
        float min_d = 100.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 nb = vec2(float(x), float(y));
                vec2 r = nb + hash2(g + nb) - f;
                min_d = min(min_d, dot(r, r));
            }
        }
        float reveal = smoothstep(0.0, -0.4, min_d - p * 1.4);
        col *= reveal;
    }
    // 12: Wave Warp
    else if (ubuf.effectType == 12) {
        float m = 1.0 - smoothstep(-0.4, 0.0, uv.x - (p * 1.4 - 0.2));
        vec2 warped = clamp((uv - 0.5) * m + 0.5, vec2(0.0), vec2(1.0));
        col = texture(source, warped) * m;
    }
    // 13: Polka Dots Curtain
    else if (ubuf.effectType == 13) {
        float dots = 18.0;
        float reveal = step(distance(fract(uv * dots), vec2(0.5)), p / max(distance(uv, vec2(0.0)), 0.001));
        col *= reveal;
    }
    // 14: Bounce Wave
    else if (ubuf.effectType == 14) {
        float time = 1.0 - p;
        float stime = sin(time * PI * 0.5);
        float phase = time * PI * 3.0;
        float yy = abs(cos(phase)) * (1.0 - stime);
        float d = uv.y - yy;
        col *= step(d, 0.0);
    }
    // 15+: Default / Fade
    else {
        col *= p;
    }

    fragColor = col * ubuf.qt_Opacity;
}
