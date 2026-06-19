#include "/lib/config.glsl"
#include "/lib/luma.glsl"

/* Color utils */

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

/* Uniforms */

uniform sampler2D gaux4;
#include "/lib/screen_size.glsl"
uniform float rainStrength;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
uniform float frameTime;
uniform vec3 sunPosition;
uniform vec4 lightningBoltPosition;
#if STAR_SLIDER == 2 || defined THE_END || COLOR_SCHEME == 8 || COLOR_SCHEME == 11 || STAR_SLIDER >= 1
    uniform float frameTimeCounter;
    uniform vec3 cameraPosition;
    uniform mat4 gbufferModelViewInverse;
    uniform float sunAngle;
#endif

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
varying vec4 position;

/* Utility functions */

#if STAR_SLIDER == 2 || AA_TYPE > 0
    #include "/lib/dither.glsl"
#endif

#if (STAR_SLIDER >= 1 || defined THE_END) && !defined NETHER
    #include "/lib/stars.glsl"
#endif

#include "/lib/biome_sky.glsl"
#define FRAGMENT
#include "/lib/downscale.glsl"

#include "/lib/aurora.glsl"

// Noise functions for Moon Craters (Simplex-like or FBM)
float moon_hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float moon_noise(in vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);
    f = f*f*(3.0-2.0*f);
    float res = mix(mix( moon_hash12(p), moon_hash12(p + vec2(1.0, 0.0)), f.x),
                    mix( moon_hash12(p + vec2(0.0, 1.0)), moon_hash12(p + vec2(1.0, 1.0)), f.x), f.y);
    return res;
}

float moon_fbm(vec2 p) {
    float f = 0.0;
    float w = 0.5;
    for (int i = 0; i < 5; i++) { // 5 Octaves for detail
        f += w * moon_noise(p);
        p *= 2.0;
        w *= 0.5;
    }
    return f;
}

// MAIN FUNCTION ------------------

void main() {
    if(fragment_cull()) discard;
    #if (STAR_SLIDER >= 1 || defined THE_END) && !defined NETHER
        vec4 star_color = vec4(stars(normalize(position.xyz)), 1.0);
    #endif
    
    float vanilla_mul;
    #if defined THE_END
        vec4 background_color = vec4(ZENITH_DAY_COLOR, 1.0) + star_color;
        vec4 block_color = vec4(ZENITH_DAY_COLOR + star_color.rgb, 1.0);
        vanilla_mul = 1.0;
    #elif defined NETHER  // Unused
        vec4 background_color = vec4(mix(fogColor * 0.1, vec3(1.0), 0.04), 1.0);
        vec4 block_color = vec4(mix(fogColor * 0.1, vec3(1.0), 0.04), 1.0);
        vanilla_mul = 1.0;
    #else
        #if MC_VERSION < 11604
            #include "/src/get_sky.glsl"
        #else
            vec3 hi_sky_color;
            vec3 mid_sky_color;
            vec3 low_sky_color;
            vec3 pure_hi_sky_color;
            vec3 pure_mid_sky_color;
            vec3 pure_low_sky_color;

            #include "/src/hi_sky.glsl"
            #include "/src/mid_sky.glsl"
            #include "/src/low_sky.glsl"
            #include "/src/get_sky.glsl"
        #endif

        #if STAR_SLIDER >= 1
            #if MC_VERSION >= 11604
                if (star_data.r > 0.0) discard;
                vec4 block_color = vec4(sky_color + star_color.rgb * STARS_BRIGHTNESS, 1.0);
            #else
                vec4 block_color = vec4(star_color.rgb * STARS_BRIGHTNESS, 1.0);
            #endif
        #else
            if (star_data.r > 0.0) discard;
            vec4 block_color = vec4(0.0);
        #endif

        #if COLOR_SCHEME == 11// Aurora Vanilla
            vanilla_mul = 1.2;
        #else
            vanilla_mul = 1.0;
        #endif

        block_color = mix(background_color, block_color * vanilla_mul, block_color);

        // --- PROCEDURAL SUN & MOON REMOVED (Drawn later for FOV/cloud handling) ---

        // --- AURORA (Northern Lights) ---
        #if COLOR_SCHEME == 8 || COLOR_SCHEME == 11
            vec3 aurora = getAurora(normalize(position.xyz), sunPosition);
            block_color.rgb += aurora;
        #endif

        #if MC_VERSION >= 11604
            block_color.a = star_data.a;
        #endif
    #endif
    
    #include "/src/writebuffers.glsl"
}
