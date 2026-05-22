// Reflectify-style noise functions for puddle generation
// Ported from Reflectify RT (in2bubble)
#ifndef SSR_NOISE_GLSL
#define SSR_NOISE_GLSL

vec2 ssr_hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float ssr_noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(ssr_hash22(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(ssr_hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(ssr_hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(ssr_hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float ssr_fbm2D(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    mat2 rot = mat2(0.8, -0.6, 0.6, 0.8);
    for (int i = 0; i < octaves; i++) {
        value += amplitude * ssr_noise2D(p * frequency);
        p *= rot;
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

#endif
