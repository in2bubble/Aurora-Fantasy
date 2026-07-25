#include "/lib/config.glsl"

/* Color utils */

#if MC_VERSION < 11604
    #ifdef THE_END
        #include "/lib/color_utils_end.glsl"
    #elif defined NETHER
        #include "/lib/color_utils_nether.glsl"
    #else
        #include "/lib/color_utils.glsl"
    #endif
#else
    uniform vec3 skyColor;
#endif

/* Uniforms */

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

#if MC_VERSION < 11604
    uniform float wetness;
#endif

uniform float rainStrength;

/* Ins / Outs */

#if MC_VERSION < 11604
    varying vec3 hi_sky_color;
    varying vec3 mid_sky_color;
    varying vec3 low_sky_color;
    varying vec3 pure_hi_sky_color;
    varying vec3 pure_mid_sky_color;
    varying vec3 pure_low_sky_color;
#endif

varying vec4 star_data;
varying vec3 up_vec;
varying vec2 texcoord;
varying vec4 position;

/* Utility functions */

#if AA_TYPE > 0
    #include "/src/taa_offset.glsl"
#endif

#if MC_VERSION < 11604
    #include "/lib/luma.glsl"
#endif
#include "/lib/downscale.glsl"

// MAIN FUNCTION ------------------

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    resize_vertex(gl_Position);

    #if AA_TYPE > 0
        gl_Position.xy += taa_offset * gl_Position.w;
    #endif

    #if !defined THE_END
        float color_distance = dot(gl_Color.rgb - skyColor, gl_Color.rgb - skyColor);

        float sky_dark_gate = 1.0;
        #if MC_VERSION >= 11604
            sky_dark_gate = float(max(max(skyColor.r, skyColor.g), skyColor.b) < 0.18);
        #endif

        star_data = vec4(
            float(gl_Color.r == gl_Color.g &&
            gl_Color.g == gl_Color.b &&
            gl_Color.r > 0.0 &&
            color_distance > 0.0) * sky_dark_gate * gl_Color.r // MC 26.2 can tint sky geometry gray in daylight; only treat gray vertices as stars when the sky is dark.
        );
    #else
        star_data = vec4(0.0);
    #endif
    position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    up_vec = normalize(gbufferModelView[1].xyz);

    #if MC_VERSION < 11604
        #include "/src/hi_sky.glsl"
        #include "/src/mid_sky.glsl"
        #include "/src/low_sky.glsl"
    #endif
}
