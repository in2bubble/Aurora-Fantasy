#include "/lib/config.glsl"

/* Color utils */

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

/* Uniforms */

uniform float rainStrength;
uniform float wetness;
uniform ivec2 eyeBrightnessSmooth;


uniform sampler2D colortex1;
uniform sampler2D gaux3;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTime;
uniform float frameTimeCounter;

/* Ins / Outs */

varying vec2 texcoord;
varying vec3 direct_light_color;
varying vec3 direct_light_strength;


varying float exposure;  // Flat


/* Utility functions */

#include "/lib/luma.glsl"

// MAIN FUNCTION ------------------

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = gl_MultiTexCoord0.xy;

    vec2 eye_bright_smooth = vec2(eyeBrightnessSmooth);

    direct_light_color = day_blend_lgcy(LIGHT_SUNSET_COLOR, LIGHT_DAY_COLOR, LIGHT_NIGHT_COLOR);
    direct_light_color = mix(direct_light_color, ZENITH_SKY_RAIN_COLOR * luma(direct_light_color), rainStrength);
    direct_light_strength = v3_luma(direct_light_color * 2);

    // Exposure
    #if !defined SIMPLE_AUTOEXP
        float mipmap_level = log2(min(viewWidth * RENDER_SCALE , viewHeight * RENDER_SCALE)) - 1.0;

        vec3 exposure_col = texture2DLod(colortex1, vec2(0.5 * RENDER_SCALE), mipmap_level).rgb;
        exposure_col += texture2DLod(colortex1, vec2(0.25 * RENDER_SCALE), mipmap_level).rgb;
        exposure_col += texture2DLod(colortex1, vec2(0.75 * RENDER_SCALE), mipmap_level).rgb;
        exposure_col += texture2DLod(colortex1, vec2(0.25 * RENDER_SCALE, 0.75 * RENDER_SCALE), mipmap_level).rgb;
        exposure_col += texture2DLod(colortex1, vec2(0.75 * RENDER_SCALE, 0.25 * RENDER_SCALE), mipmap_level).rgb;
        
        exposure = clamp(luma(exposure_col), 0.0005, 100.0);

        float prev_exposure = texture2D(gaux3, vec2(0.5)).r;

        exposure = (exp(-exposure) * 3.25) + 0.6;
        exposure = mix(exposure, prev_exposure, exp(-frameTime * 1.5));
    #else
        exposure = 1.0;
    #endif

}
