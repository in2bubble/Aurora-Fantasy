#include "/lib/config.glsl"

// MAIN FUNCTION ------------------

#if defined THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

/* Uniforms */

uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
uniform float frameTime;
uniform float far;
uniform sampler2D tex;
uniform int isEyeInWater;
uniform float nightVision;
uniform float rainStrength;
uniform float wetness;
uniform float light_mix;
uniform float pixel_size_x;
uniform float pixel_size_y;
uniform sampler2D gaux4;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform sampler2D depthtex0;
uniform float near;
uniform mat4 gbufferProjectionMatrix;

#if defined GBUFFER_BLOCK
    uniform float frameTimeCounter;
    uniform vec3 cameraPosition;
    uniform mat4 gbufferModelViewInverse; 
#endif

#if defined DISTANT_HORIZONS
    uniform float dhNearPlane;
#endif

#if defined GBUFFER_ENTITIES
    uniform int entityId;
    uniform vec4 entityColor;
#endif

#if defined SHADOW_CASTING
    uniform sampler2DShadow shadowtex1;
    #if defined COLORED_SHADOW
        uniform sampler2DShadow shadowtex0;
        uniform sampler2D shadowcolor0;
    #endif
#endif

uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
    uniform float darknessLightFactor;
#endif

#ifdef MATERIAL_GLOSS
     // Don't remove
#endif

#if defined MATERIAL_GLOSS && !defined NETHER
    uniform int worldTime;
    uniform vec3 moonPosition;
    #if defined THE_END
        uniform mat4 gbufferModelView;
    #endif
#endif

/* Ins / Outs */

varying vec2 texcoord;
varying vec4 tint_color;
varying float fog_adj;
varying vec3 direct_light_color;
varying vec3 candle_color;
varying float direct_light_strength;
varying vec3 omni_light;
varying float block_type_f;
varying float exposure;
varying float depth;
varying vec4 position;

#if defined EMMISIVE_MATERIAL || defined EMMISIVE_ORE
    varying float ore_type_f;
    varying float emitter_type_f;
#endif

#if defined GBUFFER_BLOCK
    varying vec3 worldPos;
#elif defined RAIN_PUDDLES && !defined NETHER && !defined THE_END && (defined GBUFFER_TERRAIN || defined GBUFFER_TEXTURED)
    varying vec3 worldPos;
#endif

#ifdef FOLIAGE_V
    varying float is_foliage;
#endif

#if defined RAIN_PUDDLES && !defined NETHER && !defined THE_END && (defined GBUFFER_TERRAIN || defined GBUFFER_TEXTURED)
    varying vec3 world_normal;
    #if !defined GBUFFER_BLOCK
        uniform vec3 cameraPosition;
        uniform float frameTimeCounter;
    #endif
    varying float no_puddle_f;
    varying float sky_light_f;
#endif

#if defined SHADOW_CASTING && !defined NETHER
    varying vec3 shadow_pos;
    varying float shadow_diffuse;
#endif

#if defined MATERIAL_GLOSS && !defined NETHER
    varying vec3 flat_normal;
    varying vec3 sub_position3;
    varying vec3 sub_position3_norm;
    varying vec2 lmcoord_alt;
    varying float gloss_factor;
    varying float gloss_power;
    varying float luma_factor;
    varying float luma_power;
#endif

/* Utility functions */

#include "/lib/luma.glsl"

#if (defined SHADOW_CASTING && !defined NETHER) || defined DISTANT_HORIZONS
    #include "/lib/dither.glsl"
#endif

#if defined SHADOW_CASTING && !defined NETHER
    #include "/lib/shadow_frag.glsl"
#endif

#if defined MATERIAL_GLOSS && !defined NETHER
    #include "/lib/material_gloss_fragment.glsl"
#endif

#if defined GBUFFER_BLOCK
    #include "/lib/end_portal.glsl"
#endif

#include "/lib/lod.glsl"

#define FRAGMENT
#include "/lib/downscale.glsl"

#if defined RAIN_PUDDLES && !defined NETHER && !defined THE_END && (defined GBUFFER_TERRAIN || defined GBUFFER_TEXTURED)
    #include "/lib/rain_puddles.glsl"
    #include "/lib/ssr_noise.glsl"

    // Reflectify-style puddle distribution (FBM-based organic shapes)
    float ComputeWetnessDistribution(vec3 wPos) {
        float nVal = ssr_fbm2D(wPos.xz * 0.05, 3);
        return smoothstep(-0.1, 0.05, nVal);
    }

    // Reflectify-style raindrop ripple normal distortion
    vec3 CalculateRaindropDistortion(vec3 wPos, float maskFactor) {
        if (maskFactor < 0.01) return vec3(0.0, 1.0, 0.0);
        float tOff1 = frameTimeCounter * 6.0;
        float tOff2 = frameTimeCounter * 5.0;
        float dMix = (ssr_noise2D(wPos.xz * 25.0 - tOff1) + ssr_noise2D(wPos.zx * 20.0 + tOff2)) * 0.5;
        vec3 rippleNormal = vec3(
            dMix * 0.08 * maskFactor * rainStrength,
            1.0,
            dMix * 0.08 * maskFactor * rainStrength
        );
        return normalize(rippleNormal);
    }
#endif

#if defined EMMISIVE_MATERIAL || defined EMMISIVE_ORE
    int ore_type = int(round(ore_type_f));
    int emitter_type = int(round(emitter_type_f));
#endif

int block_type = int(round(block_type_f));

vec3 computeRealLight(vec3 omni, vec3 directColor, float directStrength, vec3 shadow, vec3 material, vec3 candle) {
    // Soft fantasy shadows: prevent pure black by adding ambient floor
    vec3 soft_shadow = max(shadow, vec3(0.35));
    return omni + soft_shadow * directColor * (directStrength + material) * (1.0 - (rainStrength * 0.75)) + candle;
}

void main() {
    if(fragment_cull()) discard;
    // Reconstruct view-space fragment position from screen coordinates.
    // 'position' is player/feet space (gbufferModelViewInverse * viewPos) and must NOT
    // be dotted with sunPosition which is view space. Use gbufferProjectionInverse instead.
    vec4 fragpos = gbufferProjectionInverse * (vec4(gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y) / RENDER_SCALE, gl_FragCoord.z, 1.0) * 2.0 - 1.0);
    vec3 nfragpos = normalize(fragpos.xyz);
    float sun_influence = dot(nfragpos, sunPosition * 0.01);
    float final_sun_factor = pow(smoothstep(-1.0, 1.0, sun_influence), day_blend_float(1.0, 1.0, 1.75));
    float final_sun_factor2 = pow(smoothstep(-1.0, 1.0, sun_influence), day_blend_float(1.5, 0.0, 10.0));

    float lod = get_lod();
    
    #if (defined SHADOW_CASTING && !defined NETHER) || defined DISTANT_HORIZONS
        #if AA_TYPE > 0 
            float dither = shifted_dither13(gl_FragCoord.xy);
        #else
            float dither = r_dither(gl_FragCoord.xy);
        #endif
    #endif
    // Avoid render in DH transition
    #if defined DISTANT_HORIZONS && !defined GBUFFER_BEACONBEAM
        float t = far - dhNearPlane;
        float sup = t * TRANSITION_DH_SUP;
        float inf = t * TRANSITION_DH_INF;
        float umbral = (gl_FogFragCoord - (dhNearPlane + inf)) / (far - sup - inf - dhNearPlane);
        if(umbral > dither) {
            discard;
            return;
        }
    #endif
    // Toma el color puro del bloque
    #if defined GBUFFER_ENTITIES && BLACK_ENTITY_FIX == 1
        vec4 block_color = texture2D(tex, texcoord);
        if(block_color.a < 0.1 && entityId != 10101) {   // Black entities bug workaround
            discard;
        }
    #else
        #if RENDER_SCALE_INT != 100 && defined FSR
            vec4 block_color = texture2D(tex, texcoord,lod );
        #else
            vec4 block_color = texture2D(tex, texcoord);
        #endif
    #endif
    
    vec4 pure_block_color = block_color;
    block_color *= tint_color;
    float block_luma = luma(block_color.rgb);
    
    vec3 final_candle_color = candle_color;

    #ifdef GBUFFER_WEATHER
        block_color.a *= .5;
    #endif

    #if defined GBUFFER_ENTITIES
        // Thunderbolt render
        if(entityId == 10101) {
            block_color.a = 1.0;
        }
    #endif

    #if defined GBUFFER_BLOCK
    if (block_type == 1){
        block_color.rgb = end_portal();
    }
    #endif

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

    #if defined GBUFFER_BEACONBEAM
        block_color.rgb *= block_color.rgb * 2 / exposure;
    #elif defined GBUFFER_ENTITY_GLOW
        block_color.rgb =
            clamp(v3_luma(block_color.rgb) * vec3(0.75, 0.75, 1.5), vec3(0.3), vec3(1.0));
    #else
    
        #if defined MATERIAL_GLOSS && !defined NETHER
            float final_gloss_power = gloss_power;
            block_luma *= luma_factor;
            block_luma = pow(block_luma, luma_power);
            vec3 material_gloss_factor = vec3(material_gloss(reflect(sub_position3_norm, flat_normal), lmcoord_alt, final_gloss_power, flat_normal, mix(v3_luma(direct_light_color), direct_light_color, 0.5) * gloss_factor));
                        
            vec3 real_light = computeRealLight(omni_light, direct_light_color, direct_light_strength, shadow_c, material_gloss_factor * block_luma, candle_color);
        #else
            vec3 real_light = computeRealLight(omni_light, direct_light_color, direct_light_strength, shadow_c, vec3(0.0), final_candle_color);
        #endif

        // Subsurface scattering for foliage (light through leaves)
        #if defined FOLIAGE_V && !defined NETHER && defined GBUFFER_TERRAIN
        {
            float sss_mask = clamp(is_foliage, 0.0, 1.0);
            if (sss_mask > 0.1) {
                vec3 viewDir = normalize(fragpos.xyz);
                vec3 sunDir = normalize(sunPosition);
                // Forward scattering: light passing through from behind
                float sss_dot = max(dot(viewDir, -sunDir), 0.0);
                float sss_power = pow(sss_dot, 3.0) * 0.35;
                // Tint with block color for colored light transmission
                vec3 sss_color = block_color.rgb * direct_light_color * sss_power * sss_mask;
                sss_color *= light_mix * (1.0 - rainStrength * 0.7);
                real_light += sss_color;
            }
        }
        #endif

        block_color.rgb *= mix(real_light, vec3(1.0), nightVision * 0.125);
        block_color.rgb *= mix(vec3(1.0, 1.0, 1.0), vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B), nightVision);
        
        #if defined GBUFFER_TERRAIN || defined GBUFFER_TEXTURED || defined GBUFFER_ENTITIES
            #include "/lib/emissive_materials.glsl"
        #endif

        // === Rain Puddles & Wet Surfaces (Reflectify RT SSR System) ===
        // SSR output variables — declared before puddle code so they can be set, then read by writebuffers
        vec3 ssr_normal_out = vec3(0.5, 1.0, 0.5); // Encoded UP normal (0..1 range) — default
        float ssr_reflectivity_out = 0.0;
        float ssr_roughness_out = 1.0;

        #if defined RAIN_PUDDLES && !defined NETHER && !defined THE_END && (defined GBUFFER_TERRAIN || defined GBUFFER_TEXTURED)
        {
            // Skip puddles on hot/dry blocks (sand, magma, lava)
            float hotBlockMask = step(0.5, no_puddle_f);
            // Sky exposure mask: only apply rain effects where sky light reaches the surface
            float skyExposure = sky_light_f;
            float upDot = world_normal.y;
            float wetFactor = get_surface_wetness(upDot, wetness, rainStrength) * (1.0 - hotBlockMask) * skyExposure;

            // Reflectify-style puddle mask using FBM noise
            float puddleMask = get_puddle_mask(worldPos, upDot, wetness, rainStrength) * (1.0 - hotBlockMask) * skyExposure;
            float reflectifyPuddleMask = ComputeWetnessDistribution(worldPos) * smoothstep(0.7, 0.95, upDot) * max(wetness, rainStrength * 0.5) * (1.0 - hotBlockMask) * skyExposure;
            puddleMask = max(puddleMask, reflectifyPuddleMask);

            // Darken wet surfaces (kept from Aurora + Reflectify style heavy darkening)
            if (wetFactor > 0.01) {
                block_color.rgb = apply_wetness(block_color.rgb, wetFactor);
            }
            if (puddleMask > 0.01) {
                // Reflectify style: extra darkening on puddle areas for wet look
                block_color.rgb *= mix(1.0, 0.45, puddleMask * rainStrength);
            }

            // Compute normals and reflectivity for SSR pass
            if (puddleMask > 0.01) {
                // View-space normal for puddle surface
                vec3 worldUpNormal = vec3(0.0, 1.0, 0.0);

                // Add Reflectify-style rain ripple distortion
                vec3 worldRippleNormal = CalculateRaindropDistortion(worldPos, puddleMask);
                vec3 mixedWorldNormal = normalize(mix(worldUpNormal, worldRippleNormal, puddleMask * rainStrength * 0.7));

                // Aurora rain ripples layered on top
                #ifdef RAIN_RIPPLES
                    vec2 ripple = get_rain_ripples(worldPos, frameTimeCounter);
                    mixedWorldNormal = normalize(mixedWorldNormal + vec3(ripple.x * puddleMask * rainStrength * 0.5, 0.0, ripple.y * puddleMask * rainStrength * 0.5));
                #endif

                // Encode normal to 0..1 range for buffer storage
                ssr_normal_out = mixedWorldNormal * 0.5 + 0.5;

                // Reflectify style: mirror-like reflectivity on puddles
                ssr_reflectivity_out = mix(0.0, 0.99, puddleMask * rainStrength);
                ssr_roughness_out = mix(1.0, 0.0, puddleMask * rainStrength);

                // Specular highlight from sun/moon on puddle (immediate visual feedback)
                vec3 viewDir = normalize(fragpos.xyz);
                vec3 reflectDir = reflect(viewDir, vec3(mixedWorldNormal.x, 1.0, mixedWorldNormal.z));
                float sunSpec = pow(max(dot(reflectDir, normalize(sunPosition)), 0.0), 256.0);
                block_color.rgb += direct_light_color * sunSpec * puddleMask * 0.5 * (1.0 - rainStrength * 0.5);
            }
        }
        #endif
    #endif
    
    #ifdef GBUFFER_WEATHER
        block_color = saturate_v4(block_color, 0.25);
    #endif

    #if defined GBUFFER_ENTITIES
        if(entityId == 10101) {
        // Thunderbolt render
            block_color = vec4(1.0, 1.0, 1.0, 0.5);
        } else {
            vec3 real_light = computeRealLight(omni_light, direct_light_color, direct_light_strength, shadow_c, vec3(0.0), final_candle_color);
            float entity_poderation = luma(real_light); // Red damage bright ponderation
            block_color.rgb = mix(block_color.rgb, entityColor.rgb, entityColor.a * entity_poderation * 3.0);
        }
    #endif

    #if MC_VERSION < 11300 && defined GBUFFER_TEXTURED
        block_color.rgb *= 1.5;
    #endif

    // block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));

    #include "/src/finalcolor.glsl"
    #include "/src/writebuffers.glsl"
}