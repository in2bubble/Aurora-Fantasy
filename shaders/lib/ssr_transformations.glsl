// SSR Coordinate transformations - Ported from Reflectify RT (in2bubble)
// Adapted to use Aurora Fantasy's existing uniforms
#ifndef SSR_TRANSFORMATIONS_GLSL
#define SSR_TRANSFORMATIONS_GLSL

// These uniforms are already declared in the composite/final passes
// uniform mat4 gbufferModelView;
// uniform mat4 gbufferModelViewInverse;
// uniform mat4 gbufferProjection;
// uniform mat4 gbufferProjectionInverse;
// uniform vec3 cameraPosition;

vec3 ssr_nvec3(vec4 pos) {
    return pos.xyz / pos.w;
}

vec3 ssr_screen2ndc(vec3 screen) {
    return 2.0 * screen - 1.0;
}

vec3 ssr_ndc2screen(vec3 ndc) {
    return 0.5 * ndc + 0.5;
}

vec3 ssr_ndc2view(vec3 ndc) {
    return ssr_nvec3(gbufferProjectionInverse * vec4(ndc, 1.0));
}

vec3 ssr_view2ndc(vec3 view) {
    return ssr_nvec3(gbufferProjection * vec4(view, 1.0));
}

vec3 ssr_view2screen(vec3 view) {
    return ssr_ndc2screen(ssr_view2ndc(view));
}

vec3 ssr_screen2view(vec2 uv, float depth) {
    return ssr_ndc2view(ssr_screen2ndc(vec3(uv, depth)));
}

vec3 ssr_view2feet(vec3 view) {
    return (gbufferModelViewInverse * vec4(view, 1.0)).xyz;
}

vec3 ssr_feet2world(vec3 feet) {
    return feet + cameraPosition;
}

vec3 ssr_eye2view(vec3 eye) {
    return mat3(gbufferModelView) * eye;
}

#endif
