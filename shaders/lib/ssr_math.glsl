// SSR Math utilities - Ported from Reflectify RT (in2bubble)
#ifndef SSR_MATH_GLSL
#define SSR_MATH_GLSL

float ssr_random(vec2 v) {
    return fract(sin(dot(v, vec2(18.9898, 28.633))) * 4378.5453);
}

float ssr_random3_single(vec3 v) {
    return fract(sin(dot(v, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

vec3 ssr_random3(vec3 v) {
    v = fract(v * vec3(0.3183099, 0.3678794, 0.7071068));
    v += dot(v, v.yzx + 19.19);
    return fract(vec3(v.x * v.y * 95.4307,
                      v.y * v.z * 97.5901,
                      v.z * v.x * 93.8365)) - 0.5;
}

float ssr_luma(vec3 color) {
    return dot(vec3(0.299, 0.587, 0.114), color);
}

float ssr_rescale(float x, float a, float b) {
    return clamp((x - a) / (b - a), 0.0, 1.0);
}

float ssr_round(float x) {
    return floor(x + 0.5);
}

vec3 ssr_round3(vec3 x) {
    return floor(x + 0.5);
}

float ssr_stepify(float x, float stepSize) {
    return ssr_round(x / stepSize) * stepSize;
}

vec3 ssr_stepify3(vec3 x, float stepSize) {
    return ssr_round3(x / stepSize) * stepSize;
}

#endif
