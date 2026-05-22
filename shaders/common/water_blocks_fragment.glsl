#include "/lib/config.glsl"

/* Color utils */

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

/* Uniforms */

uniform sampler2D tex;
uniform float viewWidth;
uniform float viewHeight;
uniform float pixel_size_x;
uniform float pixel_size_y;
uniform float near;
uniform float far;
uniform sampler2D gaux1;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float sunAngle;
uniform int worldTime;
uniform float nightVision;
uniform float rainStrength;
uniform float wetness;
uniform float light_mix;
uniform ivec2 eyeBrightnessSmooth;
uniform sampler2D gaux4;
uniform float alphaTestRef;
uniform vec4 lightningBoltPosition;
uniform float frameTime;
uniform mat4 gbufferModelViewInverse;

#if defined DISTANT_HORIZONS
    uniform float dhNearPlane;
    uniform float dhFarPlane;
    uniform sampler2D dhDepthTex1;
#endif

#if V_CLOUDS > 0
    uniform sampler2D gaux2;
#endif

#if defined SHADOW_CASTING && !defined NETHER
    uniform sampler2DShadow shadowtex1;
    #if defined COLORED_SHADOW
        uniform sampler2DShadow shadowtex0;
        uniform sampler2D shadowcolor0;
    #endif
#endif

#ifdef CLOUD_REFLECTION
  // Don't remove
#endif

#if defined CLOUD_REFLECTION && (V_CLOUDS > 0 && !defined UNKNOWN_DIM) && !defined NETHER
    uniform vec3 cameraPosition;
#endif

uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
    uniform float darknessLightFactor;
#endif

/* Ins / Outs */

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 tint_color;
varying float fog_adj;
varying vec3 water_normal;
varying float block_type;
varying vec4 worldposition;
varying vec3 fragposition;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 direct_light_color;
varying vec3 candle_color;
varying float direct_light_strength;
varying vec3 omni_light;
varying float visible_sky;
varying vec3 up_vec;
varying vec3 hi_sky_color;
varying vec3 mid_sky_color;
varying vec3 low_sky_color;
varying vec3 pure_hi_sky_color;
varying vec3 pure_mid_sky_color;
varying vec3 pure_low_sky_color;
uniform int frameCounter;

vec4 fragpos = gbufferProjectionInverse * (vec4(gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), gl_FragCoord.z, 1.0) * 2.0 - 1.0);
vec3 nfragpos = normalize(fragpos.xyz);

#if defined SHADOW_CASTING && !defined NETHER
    varying vec3 shadow_pos;
    varying float shadow_diffuse;
#endif

#if (V_CLOUDS > 0 && !defined UNKNOWN_DIM) && !defined NO_CLOUDY_SKY
    varying float umbral;
    varying vec3 cloud_color;
    varying vec3 dark_cloud_color;
#endif

/* Utility functions */
#include "/lib/fps_correction.glsl"
#include "/lib/luma.glsl"

#include "/lib/projection_utils.glsl"
#include "/lib/basic_utils.glsl"
#include "/lib/dither.glsl"
#include "/lib/water.glsl"
#include "/src/current_sky_color.glsl"

#define PREPARE_SHADER
#include "/lib/biome_sky.glsl"

#if defined SHADOW_CASTING && !defined NETHER
    #include "/lib/shadow_frag.glsl"
#endif

#if defined CLOUD_REFLECTION && (V_CLOUDS > 0 && !defined UNKNOWN_DIM) && !defined NETHER
    #include "/lib/volumetric_clouds.glsl"
#endif

#define FRAGMENT
#include "/lib/downscale.glsl"

// MAIN FUNCTION ------------------

void main() {
    if(fragment_cull()) discard;
    vec2 eye_bright_smooth = vec2(eyeBrightnessSmooth);

    #if SHADOW_TYPE == 1 || defined DISTANT_HORIZONS || (defined CLOUD_REFLECTION && (V_CLOUDS > 0 && !defined UNKNOWN_DIM) && !defined NETHER) || SSR_TYPE > 0
        #if AA_TYPE > 0
            float dither = shifted_r_dither(gl_FragCoord.xy);
        #else
            float dither = r_dither(gl_FragCoord.xy);
            // dither = 0.0;
        #endif
    #else
        float dither = 1.0;
    #endif

    // vec4 block_color = texture2D(tex, texcoord);
    vec4 block_color;
    vec3 real_light;

    #ifdef VANILLA_WATER
        vec3 water_normal_base = vec3(0.0, 0.0, 1.0);
    #else
        vec3 water_normal_base = normal_waves(worldposition.xzy);
    #endif
    
    vec3 surface_normal;
    float is_water = step(2.5, block_type);
    surface_normal = get_normals(mix(vec3(0.0, 0.0, 1.0), water_normal_base, is_water), fragposition);

    float normal_dot_eye = dot(surface_normal, normalize(fragposition));
    float fresnel = square_pow(1.0 + normal_dot_eye);

    vec3 reflect_water_vec = reflect(fragposition, surface_normal);
    vec3 norm_reflect_water_vec = normalize(reflect_water_vec);

    vec3 sky_color_reflect;
    if(isEyeInWater == 0 || isEyeInWater == 2) {
        sky_color_reflect = mix(current_low_sky_color, hi_sky_color, sqrt(clamp(dot(norm_reflect_water_vec, up_vec), 0.0001, 1.0)));
    } else {
        sky_color_reflect = hi_sky_color * .5 * ((eye_bright_smooth.y * .8 + 48) * 0.004166666666666667);
    }

    sky_color_reflect = xyz_to_rgb(sky_color_reflect);

    #if defined CLOUD_REFLECTION && (V_CLOUDS > 0 && !defined UNKNOWN_DIM) && !defined NETHER
        sky_color_reflect = get_cloud(normalize((gbufferModelViewInverse * vec4(reflect_water_vec * far, 1.0)).xyz), sky_color_reflect, 0.0, dither, worldposition.xyz, int(CLOUD_STEPS_AVG * 0.5), umbral, cloud_color, dark_cloud_color, 1.0);
    #endif
    if(block_type > 2.9 && block_type < 3.1) {  // Water
        #ifdef VANILLA_WATER
            block_color = texture2D(tex, texcoord);
            #if defined SHADOW_CASTING && !defined NETHER
                #if defined COLORED_SHADOW
                    vec3 shadow_c = get_colored_shadow(shadow_pos, dither);
                    shadow_c = mix(shadow_c, vec3(1.0), shadow_diffuse);
                #else
                    vec3 shadow_c = get_shadow(shadow_pos, dither);
                    shadow_c = mix(shadow_c, vec3(1.0), shadow_diffuse);
                #endif
            #else
                vec3 shadow_c = vec3(abs((light_mix * 2.0) - 1.0));
            #endif

            float fresnel_tex = luma(block_color.rgb);

            real_light = omni_light +
                (direct_light_strength * max(shadow_c, vec3(0.35)) * direct_light_color) * (1.0 - rainStrength * 0.75) +
                candle_color;

            real_light *= (fresnel_tex * 2.0) - 0.25;

            block_color.rgb *= mix(real_light, vec3(1.0), nightVision * .125) * tint_color.rgb;

            block_color.rgb = water_shader(fragposition, surface_normal, block_color.rgb, sky_color_reflect, norm_reflect_water_vec, fresnel, visible_sky, dither, direct_light_color);

            block_color.a = sqrt(block_color.a);
        #else
            #if WATER_TEXTURE == 1
                block_color = texture2D(tex, texcoord);
                float water_texture = luma(block_color.rgb);
            #else
                float water_texture = 1.0;
            #endif

            real_light = omni_light +
                (direct_light_strength * visible_sky * direct_light_color) * (1.0 - rainStrength * 0.75) +
                candle_color;

            // === AURORA WATER COLOR SYSTEM ===
            // Depth-based color gradient: shallow = bright teal, deep = indigo-violet
            float water_distance_raw;
            if (isEyeInWater == 0) {
                float wd = 2.0 * near * far / (far + near - (2.0 * gl_FragCoord.z - 1.0) * (far - near));
                float ed = texture2D(depthtex1, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y)).r;
                ed = 2.0 * near * far / (far + near - (2.0 * ed - 1.0) * (far - near));
                water_distance_raw = clamp((ed - wd) * 0.08, 0.0, 1.0);
            } else {
                water_distance_raw = 0.5;
            }

            // Aurora palette: shallow teal → deep indigo
            vec3 shallow_color = vec3(0.06, 0.18, 0.28);  // Bright aurora teal
            vec3 deep_color = vec3(0.05, 0.04, 0.18);      // Deep indigo-violet

            // Time-of-day tinting
            vec3 day_tint = vec3(0.04, 0.15, 0.25);        // Crystal clear blue
            vec3 sunset_tint = vec3(0.12, 0.08, 0.18);      // Warm violet-amber
            vec3 night_tint = vec3(0.02, 0.06, 0.14);       // Deep midnight aurora

            vec3 time_tint = day_blend(sunset_tint, day_tint, night_tint);
            vec3 aurora_water_color = mix(shallow_color, deep_color, water_distance_raw) + time_tint * 0.3;

            #if WATER_COLOR_SOURCE == 0
                block_color.rgb = water_texture * real_light * aurora_water_color;
            #elif WATER_COLOR_SOURCE == 1
                block_color.rgb = 0.3 * water_texture * real_light * tint_color.rgb;
            #endif

            block_color = vec4(refraction(fragposition, block_color.rgb, water_normal_base), 1.0);

            // Subsurface scattering approximation - wave edges glow
            float sss_factor = pow(max(1.0 + normal_dot_eye, 0.0), 3.0) * 0.08;
            vec3 sss_color = day_blend(
                vec3(0.3, 0.4, 0.6),   // Sunset: soft blue-violet glow
                vec3(0.2, 0.5, 0.6),   // Day: teal edge glow
                vec3(0.1, 0.2, 0.5)    // Night: subtle blue glow
            );
            block_color.rgb += sss_color * sss_factor * real_light * visible_sky;

            #if WATER_TEXTURE == 1
                water_texture += 0.25;
                water_texture *= water_texture;
                fresnel = clamp(fresnel * (water_texture), 0.0, 1.0);
            #endif

            // Enhanced Fresnel for more dramatic reflections
            fresnel = mix(fresnel, pow(fresnel, 0.7), 0.4);

            // Specular micro-highlights from wave crests
            float wave_crest = max(water_normal_base.x * water_normal_base.y, 0.0);
            float sparkle = pow(wave_crest, 8.0) * 1.0;
            vec3 sparkle_color = day_blend(
                vec3(0.7, 0.6, 0.5),   // Sunset: warm gold sparkle
                vec3(0.8, 0.9, 1.0),   // Day: white-blue sparkle
                vec3(0.3, 0.5, 0.8)    // Night: blue sparkle
            );
            block_color.rgb += sparkle * sparkle_color * direct_light_color * visible_sky * (1.0 - rainStrength);

            // === Water Edge Foam ===
            #ifdef WATER_FOAM
            {
                float foam_distance;
                if (isEyeInWater == 0) {
                    float wd = 2.0 * near * far / (far + near - (2.0 * gl_FragCoord.z - 1.0) * (far - near));
                    float ed = texture2D(depthtex1, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y)).r;
                    ed = 2.0 * near * far / (far + near - (2.0 * ed - 1.0) * (far - near));
                    foam_distance = ed - wd;
                } else {
                    foam_distance = 100.0; // No foam underwater
                }

                float foam_width = FOAM_WIDTH;
                float foam_mask = smoothstep(foam_width, 0.0, foam_distance);

                // Animated foam pattern using noise
                vec2 foam_coord1 = worldposition.xz * 0.4 + vec2(frameTimeCounter * 0.03, frameTimeCounter * 0.02);
                vec2 foam_coord2 = worldposition.xz * 0.7 - vec2(frameTimeCounter * 0.02, frameTimeCounter * 0.04);
                float foam_noise1 = texture2D(noisetex, foam_coord1).r;
                float foam_noise2 = texture2D(noisetex, foam_coord2).r;
                float foam_pattern = foam_noise1 * 0.6 + foam_noise2 * 0.4;

                // Foam gets denser closer to the edge
                float foam_density = smoothstep(0.35, 0.7, foam_pattern + foam_mask * 0.4);
                float foam_alpha = foam_mask * foam_density;

                // Foam color - white with slight blue tint from sky
                vec3 foam_color = vec3(0.9, 0.95, 1.0) * FOAM_BRIGHTNESS * real_light;

                block_color.rgb = mix(block_color.rgb, foam_color, foam_alpha * 0.7);
            }
            #endif

            block_color.rgb = water_shader(fragposition, surface_normal, block_color.rgb, sky_color_reflect, norm_reflect_water_vec, fresnel, visible_sky, dither, direct_light_color);
        #endif

    } else {  // Otros translúcidos
        block_color = texture2D(tex, texcoord);
        float block_luma = luma(block_color.rgb);
        block_color *= tint_color;

        if(block_type < 0.11 && block_type > 0.09) { // Enhanced Portal
            block_color.rgb *= fourth_pow(block_luma) * 1000;
        } else if(block_type > 2.3 && block_type < 2.5) { // Ice
            block_color = saturate_v4(block_color, 0.5);
            block_color.a *= 0.75;
            block_color.r *= 0.9;
        }

        #if defined SHADOW_CASTING && !defined NETHER
            #if defined COLORED_SHADOW
                vec3 shadow_c = get_colored_shadow(shadow_pos, dither);
                shadow_c = mix(shadow_c, vec3(1.0), shadow_diffuse);
            #else
                vec3 shadow_c = get_shadow(shadow_pos, dither);
                shadow_c = mix(shadow_c, vec3(1.0), shadow_diffuse);
            #endif
        #else
            float shadow_c = abs((light_mix * 2.0) - 1.0);
        #endif

        real_light = omni_light +
            (direct_light_strength * shadow_c * direct_light_color) * (1.0 - rainStrength * 0.75) +
            candle_color;

        block_color.rgb *= mix(real_light, vec3(1.0), nightVision * .125);

        if(block_type > 1.5) {  // Glass
            float sat;
            if(block_type > 2.1 && block_type < 2.3){
                sat = 0.5;
            } else {
                sat = 3.0;
            }
            block_color = cristal_shader(fragposition, water_normal, saturate_v4(block_color, sat), sky_color_reflect, fresnel, visible_sky, dither, direct_light_color);
            if (block_color.a < alphaTestRef) discard;
        }
    }

    // Avoid render in DH transition
    #ifdef DISTANT_HORIZONS
        float t = far - dhNearPlane;
        float sup = t * TRANSITION_DH_SUP;
        float inf = t * TRANSITION_DH_INF;
        float draw_umbral = (gl_FogFragCoord - (dhNearPlane + inf)) / (far - sup - inf - dhNearPlane);
        if(draw_umbral > dither) {
            discard;
            return;
        }
    #endif

    #include "/src/finalcolor.glsl"
    #include "/src/writebuffers.glsl"
}
