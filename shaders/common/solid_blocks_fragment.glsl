#include "/lib/config.glsl"
#include "/lib/fantasy_life.glsl"

#ifdef RAIN_PUDDLES
    // Direct boolean reference required by Iris' shader-option discovery.
    #if !defined NETHER && !defined THE_END && defined GBUFFER_TERRAIN
        #define RAIN_SURFACE_PASS
    #endif
#endif

// MAIN FUNCTION ------------------

#if defined THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

/* Uniforms */

uniform float far;
uniform sampler2D tex;
uniform int isEyeInWater;
uniform float nightVision;
uniform float rainStrength;
uniform float wetness;
uniform float light_mix;
uniform sampler2D gaux4;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform sampler2D depthtex0;
uniform float near;

#ifdef RAIN_SURFACE_PASS
    uniform sampler2D noisetex;
#endif

#if defined GBUFFER_BLOCK || defined RAIN_SURFACE_PASS || (defined FANTASY_LIFE_SYSTEM && defined FANTASY_NIGHT_FLORA && !defined NETHER && !defined THE_END)
    uniform vec3 cameraPosition;
#endif

#if defined GBUFFER_BLOCK
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
#elif defined RAIN_SURFACE_PASS
    varying vec3 worldPos;
#endif

#ifdef FOLIAGE_V
    varying float is_foliage;
#endif

#if defined FANTASY_LIFE_SYSTEM && defined FANTASY_NIGHT_FLORA
    varying float fantasy_plant_f;
#endif

#ifdef RAIN_SURFACE_PASS
    varying vec3 world_normal;
    varying vec3 puddle_sky_zenith;
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

#ifdef RAIN_SURFACE_PASS
    #include "/lib/fantasy_puddles.glsl"
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
    vec4 block_color = texture2D(tex, texcoord);

    #if defined GBUFFER_TEXTURED && !defined NETHER && !defined THE_END
        // Minecraft's rain-impact sprites are blue ground-hugging billboards.
        // Iris exposes the particle atlas with the V axis flipped on some
        // drivers/resource paths, so test both atlas orientations. The colour
        // and depth-gap checks are a conservative fallback for repacked atlases.
        if (rainStrength > 0.001) {
            vec2 particleAtlasPixel = texcoord * vec2(512.0, 256.0);
            bool nominalSplash =
                (particleAtlasPixel.x >= 412.0
                    && particleAtlasPixel.x < 420.0
                    && particleAtlasPixel.y >= 240.0
                    && particleAtlasPixel.y < 248.0)
                || (particleAtlasPixel.x >= 422.0
                    && particleAtlasPixel.x < 430.0
                    && particleAtlasPixel.y >= 0.0
                    && particleAtlasPixel.y < 8.0)
                || (particleAtlasPixel.x >= 422.0
                    && particleAtlasPixel.x < 430.0
                    && particleAtlasPixel.y >= 10.0
                    && particleAtlasPixel.y < 18.0)
                || (particleAtlasPixel.x >= 422.0
                    && particleAtlasPixel.x < 430.0
                    && particleAtlasPixel.y >= 20.0
                    && particleAtlasPixel.y < 28.0);
            bool flippedSplash =
                (particleAtlasPixel.x >= 412.0
                    && particleAtlasPixel.x < 420.0
                    && particleAtlasPixel.y >= 8.0
                    && particleAtlasPixel.y < 16.0)
                || (particleAtlasPixel.x >= 422.0
                    && particleAtlasPixel.x < 430.0
                    && particleAtlasPixel.y >= 248.0
                    && particleAtlasPixel.y < 256.0)
                || (particleAtlasPixel.x >= 422.0
                    && particleAtlasPixel.x < 430.0
                    && particleAtlasPixel.y >= 238.0
                    && particleAtlasPixel.y < 246.0)
                || (particleAtlasPixel.x >= 422.0
                    && particleAtlasPixel.x < 430.0
                    && particleAtlasPixel.y >= 228.0
                    && particleAtlasPixel.y < 236.0);

            vec3 particleColour = block_color.rgb * tint_color.rgb;
            bool stronglyBlue = particleColour.b > 0.045
                && particleColour.b > particleColour.r * 1.22
                && particleColour.b > particleColour.g * 1.06;

            vec2 particleScreenUV = gl_FragCoord.xy
                * vec2(pixel_size_x, pixel_size_y) / RENDER_SCALE;
            float groundDepth = texture2D(depthtex0, particleScreenUV).r;
            vec4 groundViewH = gbufferProjectionInverse *
                (vec4(particleScreenUV, groundDepth, 1.0) * 2.0 - 1.0);
            vec3 groundView = groundViewH.xyz
                / max(abs(groundViewH.w), 0.00001);
            vec3 particleView = fragpos.xyz
                / max(abs(fragpos.w), 0.00001);
            float groundGap = abs(length(groundView) - length(particleView));
            bool blueGroundImpact = stronglyBlue && groundDepth < 0.9999
                && groundGap < 0.95;

            if (nominalSplash || (flippedSplash && stronglyBlue)
                    || blueGroundImpact) discard;
        }
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

        block_color.rgb *= night_vision_lighting(real_light, nightVision);
        
        #if defined GBUFFER_TERRAIN || defined GBUFFER_TEXTURED || defined GBUFFER_ENTITIES
            #include "/lib/emissive_materials.glsl"
        #endif

        float fantasy_habitat_out = 0.0;

        #if defined FANTASY_LIFE_SYSTEM && defined FANTASY_NIGHT_FLORA && defined GBUFFER_TERRAIN && !defined NETHER && !defined THE_END
        {
            float plantType = round(fantasy_plant_f);
            if (plantType > 0.5) {
                float nightAmount = day_blend_float(0.0, 0.0, 1.0)
                    * (1.0 - rainStrength * 0.45)
                    * (1.0 - nightVision * 0.75);
                vec3 absolutePlantPos = position.xyz + cameraPosition;
                vec3 plantCell = floor(absolutePlantPos * 0.5);
                float plantPhase = fantasy_life_hash13(
                    plantCell + 5.17);
                float windPulse = 0.72 + 0.28 * sin(
                    persistentTimeSeconds * (0.70 + float(WIND_FORCE) * 0.15)
                    + dot(absolutePlantPos.xz, vec2(0.21, 0.16))
                    + plantPhase * 4.31);
                float playerDisturbance =
                    fantasy_player_disturbance(
                        absolutePlantPos, cameraPosition);
                float plantRecovery =
                    fantasy_plant_recovery_disturbance(
                        absolutePlantPos, cameraPosition);
                float fantasyLifeStrength = 0.80
                    + 0.10 * clamp(
                        float(FANTASY_LIFE_QUALITY), 1.0, 4.0);

                vec3 texelColor = max(pure_block_color.rgb * tint_color.rgb, vec3(0.0));
                float texelLuma = luma(texelColor);
                float texelPeak = max(max(texelColor.r, texelColor.g), texelColor.b);
                vec3 livingHue = texelColor / max(texelPeak, 0.06);
                float greenDominance =
                    texelColor.g - max(texelColor.r, texelColor.b);
                float grassMask = smoothstep(0.012, 0.18, greenDominance)
                    * smoothstep(0.025, 0.34, texelLuma);
                float petalMask =
                    (1.0 - smoothstep(0.0, 0.022, greenDominance))
                    * smoothstep(0.055, 0.38, texelLuma)
                    * smoothstep(0.10, 0.30, texelPeak);
                float generalFlora = step(3.5, plantType);

                if (plantType < 1.5 || generalFlora > 0.5) {
                    // A shared world-space firefly visit drives the flower.
                    // Between visits the original petal hue stays readable.
                    float fireflyVisit = fantasy_firefly_visit(
                        absolutePlantPos, persistentTimeSeconds)
                        * fantasy_perch_selector(absolutePlantPos);
                    float settledVisit = fireflyVisit
                        * (1.0 - plantRecovery);
                    vec3 visitorColor = fantasy_firefly_life_color(
                        absolutePlantPos);
                    float flowerSparkMask = fantasy_perch_spark_mask(
                        absolutePlantPos);
                    float flowerSpark = flowerSparkMask * settledVisit;
                    vec3 flowerLight = mix(
                        livingHue,
                        visitorColor,
                        0.04 + 0.14 * settledVisit);
                    float flowerEnergy = 0.002
                        + 0.095 * settledVisit;
                    block_color.rgb += flowerLight * petalMask * nightAmount
                        * flowerEnergy * fantasyLifeStrength;
                    block_color.rgb += visitorColor * flowerSpark
                        * nightAmount * 0.38 * fantasyLifeStrength;
                    float flowerSourceMask = max(
                        step(0.08, petalMask),
                        step(0.12, flowerSparkMask));
                    float flowerRelease = flowerSourceMask
                        * step(0.06, fireflyVisit)
                        * smoothstep(
                            0.02, 0.24, playerDisturbance);
                    fantasy_habitat_out = max(
                        fantasy_habitat_out,
                        max(
                            max(petalMask, flowerSparkMask)
                                * fireflyVisit * 0.78,
                            flowerRelease));
                }

                if (generalFlora > 0.5) {
                    float perchSelector = fantasy_perch_selector(
                        absolutePlantPos);
                    float grassVisit = fantasy_firefly_visit(
                        absolutePlantPos, persistentTimeSeconds);
                    float activeGrassVisit = perchSelector * grassVisit;
                    float grassPerch = activeGrassVisit
                        * (1.0 - plantRecovery);
                    float tipMask = fantasy_plant_tip_mask(
                        absolutePlantPos);
                    float grassSparkMask = fantasy_perch_spark_mask(
                        absolutePlantPos);
                    float grassSpark = grassSparkMask * grassPerch;
                    vec3 perchColor = fantasy_firefly_life_color(
                        absolutePlantPos);
                    vec3 grassLight = mix(
                        livingHue * vec3(0.08, 0.24, 0.15),
                        perchColor,
                        0.30);
                    float grassGlow = grassMask * tipMask
                        * nightAmount * grassPerch
                        * (0.10 + 0.06 * windPulse);
                    block_color.rgb += grassLight * grassGlow
                        * fantasyLifeStrength;
                    block_color.rgb += perchColor * grassSpark
                        * grassMask * nightAmount * 0.46
                        * fantasyLifeStrength;
                    float grassSourceMask = max(
                        step(0.08, grassMask),
                        step(0.12, grassSparkMask));
                    float grassRelease = grassSourceMask
                        * step(0.06, activeGrassVisit)
                        * smoothstep(
                            0.02, 0.24, playerDisturbance);
                    fantasy_habitat_out = max(
                        fantasy_habitat_out,
                        max(
                            max(
                                grassMask * activeGrassVisit,
                                grassSparkMask * activeGrassVisit)
                                * 0.72,
                            grassRelease));
                } else if (plantType >= 1.5) {
                    // Dynamic adaptive canopy lights in tree leaves (varied sizes & subtle breathing)
                    float leafDetail = smoothstep(0.045, 0.46, texelLuma);
                    float blossomFactor = step(2.5, plantType);
                    vec3 orbCenter = fantasy_canopy_orb_center(absolutePlantPos);
                    vec3 orbDelta = absolutePlantPos - orbCenter;
                    orbDelta.y *= 1.18;

                    vec3 orbHash = fantasy_life_hash33(orbCenter);
                    float orbSizeScale = mix(0.35, 1.15, orbHash.x);
                    float orbPulseSpeed = mix(0.65, 1.35, orbHash.y);
                    float orbPulsePhase = persistentTimeSeconds * orbPulseSpeed + orbHash.z * 6.28318;
                    float orbPulse = sin(orbPulsePhase) * 0.35 + 0.65;

                    float orbMask = 1.0 - smoothstep(0.12, 1.10 * orbSizeScale, length(orbDelta));
                    float orbVisit = fantasy_firefly_visit(orbCenter, persistentTimeSeconds);
                    float orbDisturbance = fantasy_player_disturbance(orbCenter, cameraPosition);
                    float orbRecovery = fantasy_plant_recovery_disturbance(orbCenter, cameraPosition);
                    float orbLife = orbMask * orbVisit * (1.0 - orbRecovery) * orbPulse;
                    float orbCore = orbMask * orbMask * orbLife;

                    vec3 orbColor = fantasy_firefly_life_color(orbCenter);
                    vec3 leafLight = mix(livingHue * vec3(0.12, 0.32, 0.22), orbColor, 0.48);
                    float leafStrength = mix(0.06, 0.12, blossomFactor) * orbSizeScale;

                    block_color.rgb += leafLight * leafDetail * nightAmount
                        * leafStrength * orbLife * fantasyLifeStrength;
                    block_color.rgb += orbColor * leafDetail
                        * nightAmount * orbCore * 0.18 * orbSizeScale
                        * fantasyLifeStrength;
                    float canopySourceMask =
                        step(0.10, leafDetail)
                        * step(0.06, orbMask);
                    float canopyRelease = canopySourceMask
                        * step(0.06, orbVisit)
                        * smoothstep(
                            0.02, 0.24, orbDisturbance);
                    fantasy_habitat_out = max(
                        fantasy_habitat_out,
                        max(
                            leafDetail * orbMask * orbVisit * 0.76,
                            canopyRelease));
                }
            }
        }
        #endif

        #if defined FANTASY_LIFE_SYSTEM && (defined EMMISIVE_MATERIAL || defined EMMISIVE_ORE)
            fantasy_habitat_out = max(
                fantasy_habitat_out,
                step(0.5, float(emitter_type)) * 0.78);
        #endif

        // === Aurora Fantasy rain puddles and wet surfaces ===
        // SSR output variables — declared before puddle code so they can be set, then read by writebuffers
        vec3 puddle_normal_out = vec3(0.5, 1.0, 0.5);
        float puddle_mask_out = 0.0;
        float puddle_ssr_patch_out = 0.0;
        float puddle_depth_out = 0.0;
        // R8 auxiliary channel consumed after the optical water body has been
        // assembled. It prevents the night palette from painting over the
        // local torch and emissive-block response.
        float puddle_local_light_out = 0.0;
        // Logarithmic view distance identifies the exact terrain surface that
        // authored the puddle data. Composite uses it to reject residual data
        // beneath entities (notably the third-person player).
        vec3 puddleViewPosition = fragpos.xyz
            / max(abs(fragpos.w), 0.00001);
        float puddle_surface_distance_out = clamp(
            log2(1.0 + length(puddleViewPosition))
                / log2(1.0 + far),
            0.0, 1.0);

        #ifdef RAIN_SURFACE_PASS
        {
            // Skip puddles on hot/dry blocks (sand, magma, lava)
            float hotBlockMask = step(0.5, no_puddle_f);
            float skyExposure = sky_light_f;
            float upDot = world_normal.y;
            float rainAmount = max(wetness, rainStrength);
            // Uniform weather branch: avoid paying for wave/ring/environment
            // work in clear weather while retaining the gradual wetness fade.
            if (rainAmount > 0.001) {
            vec2 puddleField = getFantasyPuddleField(worldPos, upDot, rainAmount)
                * (1.0 - hotBlockMask) * skyExposure;
            float puddleMask = puddleField.x;
            float puddleDepth = puddleField.y * rainAmount;
            float puddleOpacity = puddleMask * rainAmount;
            float surfaceWetness = smoothstep(0.30, 0.90, upDot)
                * rainAmount * (1.0 - hotBlockMask) * skyExposure;

            // Use the same block-light field as Aurora's real water. Its
            // strength is forwarded to composite, after refraction is built.
            vec3 safeLocalBlockLight = max(candle_color, vec3(0.0));
            float localBlockLightLuma = dot(
                safeLocalBlockLight, vec3(0.2126, 0.7152, 0.0722));
            float localBlockLightMask = smoothstep(
                0.018, 0.42, localBlockLightLuma);
            float localBlockLightEncoded = clamp(
                localBlockLightLuma * 1.05, 0.0, 1.0);
            puddle_local_light_out = puddleOpacity
                * localBlockLightEncoded;

            // Build Aurora's storm environment once. Zenith comes from the
            // shader's actual sky model; the horizon uses the weather fog/sky.
            // The gradient is sampled by a world-space reflection direction,
            // so the animation is attached to the terrain rather than the screen.
            vec3 zenithEnvironment = max(xyz_to_rgb(puddle_sky_zenith), vec3(0.0));
            vec3 horizonEnvironment = max(mix(fogColor, skyColor, 0.38), vec3(0.0));
            zenithEnvironment /= vec3(1.0) + zenithEnvironment;
            horizonEnvironment /= vec3(1.0) + horizonEnvironment;
            zenithEnvironment *= vec3(0.96, 0.99, 1.03);
            horizonEnvironment *= vec3(0.98, 0.99, 1.01);

            // Once night begins, storm water must stop inheriting the warm
            // sunset lobe that remains around the sun direction. Preserve the
            // measured luminance, but move only the puddle environment toward
            // a neutral moonlit blue. The rest of the world keeps Aurora's
            // original sunset/night grading.
            float puddleNightAmount = day_blend_float(0.0, 0.0, 1.0);
            float stormNightBalance = rainStrength
                * smoothstep(0.025, 0.62, puddleNightAmount);
            float zenithLuma = dot(
                zenithEnvironment, vec3(0.2126, 0.7152, 0.0722));
            float horizonLuma = dot(
                horizonEnvironment, vec3(0.2126, 0.7152, 0.0722));
            vec3 puddlePaletteHue = auroraWaterPaletteHue(puddleDepth * 0.36);
            vec3 coolZenith = vec3(zenithLuma) * puddlePaletteHue;
            vec3 coolHorizon = vec3(horizonLuma)
                * mix(vec3(1.0), puddlePaletteHue, 0.74);
            zenithEnvironment = mix(
                zenithEnvironment, coolZenith, stormNightBalance * 0.88);
            horizonEnvironment = mix(
                horizonEnvironment, coolHorizon, stormNightBalance * 0.92);

            // A storm sky can approach numerical black at night. Real shallow
            // water still retains diffuse sky radiance, so keep a very low,
            // time-aware blue-grey floor instead of producing black decals.
            vec3 puddleAmbientFloor = day_blend(
                vec3(0.018, 0.023, 0.031),
                vec3(0.026, 0.034, 0.044),
                vec3(0.012, 0.020, 0.033)
            );
            zenithEnvironment = max(
                zenithEnvironment,
                puddleAmbientFloor
            );
            horizonEnvironment = max(
                horizonEnvironment,
                puddleAmbientFloor * 0.82
            );

            // All rain-exposed terrain receives a thin, rough moving water film.
            // It preserves the texture and stays much rougher than a deep pool.
            float wetGround = surfaceWetness * (1.0 - puddleMask * 0.70);
            vec3 wetGroundColor = block_color.rgb * 0.82;
            float wetLuma = dot(wetGroundColor, vec3(0.2126, 0.7152, 0.0722));
            wetGroundColor = mix(vec3(wetLuma), wetGroundColor, 1.14);
            block_color.rgb = mix(block_color.rgb, wetGroundColor, wetGround);

            vec3 groundViewDir = normalize(cameraPosition - worldPos);
            float wetFilmRing;
            vec3 wetFilmNormal = getFantasyWetFilmNormal(
                worldPos, frameTimeCounter, length(fragpos.xyz), wetFilmRing);
            vec3 groundWetNormal = normalize(mix(normalize(world_normal),
                wetFilmNormal, wetGround * 0.22));
            vec3 groundReflectDir = reflect(-groundViewDir, groundWetNormal);
            float groundSkyHeight = sqrt(clamp(groundReflectDir.y * 0.92 + 0.08, 0.0, 1.0));
            vec3 groundEnvironment = mix(horizonEnvironment, zenithEnvironment,
                groundSkyHeight);
            float groundFacing = max(dot(groundWetNormal, groundViewDir), 0.0);
            float groundFresnel = 0.035 + 0.26 * pow(1.0 - groundFacing, 5.0);
            block_color.rgb = mix(block_color.rgb, groundEnvironment,
                wetGround * (0.045 + groundFresnel * 0.42));
            block_color.rgb += groundEnvironment * wetGround * wetFilmRing
                * rainStrength * mix(0.045, 0.105, groundFresnel);

            puddle_normal_out = normalize(world_normal) * 0.5 + 0.5;
            puddle_depth_out = puddleDepth;

            if (puddleOpacity > 0.001) {
                float rippleLight;
                float bubbleLight;
                vec3 waterNormal = getFantasyPuddleNormal(
                    worldPos, frameTimeCounter, length(fragpos.xyz),
                    skyExposure,
                    rippleLight, bubbleLight);
                float depthResponse = mix(0.28, 0.76, puddleDepth);
                float thicknessVariation = mix(0.84, 1.16,
                    fantasyBoundaryNoise(
                        worldPos.xz * 0.19 + vec2(12.7, 35.1)));
                float waterThickness = clamp(
                    puddleDepth * thicknessVariation, 0.0, 1.0);
                vec3 mixedWorldNormal = normalize(mix(
                    normalize(world_normal), waterNormal, puddleOpacity * depthResponse));

                // Clear shallow water still reveals the original block texture;
                // deeper centres absorb more light without turning flat grey.
                vec3 absorbedGround = block_color.rgb * vec3(0.68, 0.73, 0.79);
                float absorption = puddleOpacity
                    * mix(0.16, 0.58, waterThickness);
                block_color.rgb = mix(block_color.rgb, absorbedGround, absorption);

                // Remove the warm ground-light contamination that otherwise
                // comes through the shallow body when looking toward sunset at
                // early night. Luminance still comes from the real block, and
                // the gentle dark-range expansion preserves its texture at
                // midnight instead of replacing it with a flat water colour.
                float waterBodyLuma = dot(
                    block_color.rgb, vec3(0.2126, 0.7152, 0.0722));
                float readableNightLuma = max(
                    waterBodyLuma, sqrt(max(waterBodyLuma, 0.0)) * 0.16);
                vec3 neutralNightBody = vec3(readableNightLuma)
                    * auroraWaterPaletteHue(waterThickness * 0.36);
                block_color.rgb = mix(
                    block_color.rgb, neutralNightBody,
                    puddleOpacity * stormNightBalance
                    * mix(0.38, 0.25, localBlockLightMask));

                // Advected noise changes the micro-transmission over time,
                // making the pool body visibly flow even where SSR is absent.
                float animatedSurfaceNoise = fantasyAnimatedWaterNoise(
                    worldPos.xz, frameTimeCounter);
                float movingSheen = animatedSurfaceNoise - 0.5;
                block_color.rgb *= 1.0
                    + movingSheen * puddleOpacity * 0.085;
                block_color.rgb += horizonEnvironment
                    * max(movingSheen, 0.0) * puddleOpacity * 0.075;

                // At midnight, texture motion needs reflected moon/storm
                // radiance to remain readable. This responds to the animated
                // water normal and is therefore not a flat emissive lift.
                float waveSlopeEnergy = clamp(
                    length(waterNormal.xz) * 1.45, 0.0, 1.0);
                float nightWaveResponse = puddleNightAmount * rainStrength
                    * puddleOpacity * (0.018 + 0.115 * waveSlopeEnergy);
                block_color.rgb += mix(
                    horizonEnvironment, zenithEnvironment, 0.58)
                    * nightWaveResponse;

                vec3 worldViewDir = normalize(cameraPosition - worldPos);
                float viewFacing = max(dot(mixedWorldNormal, worldViewDir), 0.0);
                float waterFresnel = 0.04 + 0.96 * pow(1.0 - viewFacing, 5.0);

                // Stable local-light response. The lightmap/candle channel
                // supplies nearby torch and emissive-block colour even when the
                // source itself is outside the screen. Wave slope and moving
                // transmission break it into a living shallow-water sheen.
                vec3 localBlockLightColor = safeLocalBlockLight
                    / (vec3(1.0) + safeLocalBlockLight * 0.42);
                float localLightWaveFocus = 0.36
                    + 0.64 * clamp(length(waterNormal.xz) * 1.55, 0.0, 1.0);
                float localLightReflection = localBlockLightMask
                    * puddleOpacity
                    * mix(0.015, 0.055, waterFresnel)
                    * localLightWaveFocus
                    * mix(0.72, 1.28, animatedSurfaceNoise)
                    * mix(0.34, 1.0, puddleNightAmount);
                block_color.rgb += localBlockLightColor
                    * localLightReflection;

                // Foreshortening compresses the ring when looking forward.
                // Compensate its contrast at grazing angles without changing
                // the storm-tinted colour or making top-down impacts brighter.
                float grazingRippleVisibility = mix(
                    1.0, 2.25, pow(1.0 - viewFacing, 1.35));
                // Composite owns the directional reflection and can see the
                // fully rendered current clouds. Do not inject the clear-sky
                // approximation here: doing so tinted rainy puddles pink at
                // dawn before the real storm reflection was available.

                // Raindrop rings modulate the reflected environment itself.
                // This reads as moving water rather than a bright fake decal.
                // Keep impacts inside the current storm palette. A restrained
                // cool lift provides contrast without white pin-prick flashes.
                vec3 impactLight = max(
                    horizonEnvironment * vec3(0.82, 0.92, 1.02),
                    mix(vec3(0.055, 0.075, 0.095),
                        vec3(0.072, 0.108, 0.165),
                        puddleNightAmount));
                block_color.rgb += impactLight
                    * (rippleLight * mix(0.075, 0.135, waterFresnel)
                    + bubbleLight * 0.15)
                    * puddleOpacity * rainStrength
                    * grazingRippleVisibility;

                puddle_normal_out = mixedWorldNormal * 0.5 + 0.5;
                puddle_mask_out = puddleOpacity * mix(0.62, 1.0, puddleDepth);
                puddle_ssr_patch_out = getFantasyPuddleSSRMask(
                    worldPos, waterThickness);
                puddle_depth_out = waterThickness;
            }
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


    #include "/src/finalcolor.glsl"
    #include "/src/writebuffers.glsl"
}
