#include "/lib/config.glsl"

/* Color utils */

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

#include "/lib/luma.glsl"

/* Uniforms */

uniform sampler2D tex;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
uniform float frameTime;
#ifdef THE_END
    uniform float frameTimeCounter;
    uniform vec3 cameraPosition;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferProjectionInverse;
#endif

/* Ins / Outs */

varying vec2 texcoord;
varying vec4 tint_color;
varying float sky_luma_correction;
varying vec3 cursed_sky;
varying float current_wetness;
varying vec3 local_pos;

/* Utilitary functions */

#define FRAGMENT
#include "/lib/downscale.glsl"

// MAIN FUNCTION ------------------

void main() {
    if(fragment_cull()) discard;
    #if defined THE_END
        // Hide Vanilla Sun and Moon in The End
        discard;
        vec4 block_color = vec4(0.0);
    #elif defined NETHER
        vec4 background_color_full = vec4(mix(fogColor * 0.1, vec3(1.0), 0.04), 1.0);
        vec3 background_color = background_color_full.rgb;
        vec4 block_color = vec4(background_color, 1.0);
    #else
        // Hide Vanilla Sun and Moon
        discard;

        vec4 block_color = vec4(0.0);
        
        #ifndef CUSTOM_SKYFIX
            block_color.rgb *= sky_luma_correction * current_wetness;
            #if COLOR_SCHEME == 11 && !defined SIMPLE_AUTOEXP
                block_color.rgb *= day_blend_float(1.0, 1.5, sqrt(luma(block_color.rgb) * 0.5));
            #elif COLOR_SCHEME == 11 && defined SIMPLE_AUTOEXP
                block_color.rgb *= day_blend_float(1.0, 1.5, sqrt(luma(block_color.rgb) * 3));
            #else
                block_color.rgb *= day_blend(block_color.rgb, block_color.rgb, sqrt(block_color.rgb));
            #endif

            #if COLOR_SCHEME == 11 && defined SIMPLE_AUTOEXP
                block_color.rgb = pow(block_color.rgb, vec3(ASTRO_POWER * day_blend_float(1.0, 1.0, 0.6)));
            #else
                block_color.rgb = pow(block_color.rgb, vec3(ASTRO_POWER));
            #endif
            
            #if COLOR_SCHEME == 12
                block_color.rgb *= cursed_sky;
            #endif
        #else
            block_color.rgb = saturate(block_color.rgb, day_blend_float(0.75, 1.0, 0.5)) * day_blend_float(0.5, 1.0, 0.15);
        #endif
    #endif

    #include "/src/writebuffers.glsl"
}