#include "/lib/config.glsl"
const bool colortex1MipmapEnabled = true;

/* Color utils */

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

/* Uniforms */

uniform sampler2D colortex1;
uniform float far;
uniform float near;
uniform float blindness;
uniform float rainStrength;
uniform float wetness;
uniform sampler2D depthtex0;
uniform int isEyeInWater;

#if defined DISTANT_RENDER_MOD && defined DISTANT_HORIZONS
    uniform sampler2D dhDepthTex0;
    uniform float dhNearPlane;
    uniform float dhFarPlane;
#endif
uniform ivec2 eyeBrightnessSmooth;

#if !defined NETHER && !defined THE_END
    uniform vec3 sunPosition;
    uniform mat4 gbufferProjection;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferProjectionInverse;
    uniform vec3 cameraPosition;
#endif

#if defined RAIN_PUDDLES && !defined NETHER && !defined THE_END
    uniform sampler2D colortex8; // SSR Normals from gbuffers
    uniform sampler2D colortex9; // SSR Reflectivity + Roughness from gbuffers
    uniform sampler2D colortex0; // Puddle-local torch/emissive light strength
    uniform sampler2D depthtex2; // Depth without hand & translucents — used to skip hand pixels in SSR
    uniform mat4 gbufferModelView;
    uniform bool firstPersonCamera;
#endif

/* Ins / Outs */

varying vec2 texcoord;
varying vec3 direct_light_color;
varying vec3 direct_light_strength;
varying float exposure;

/* Utility functions */

#include "/lib/basic_utils.glsl"
#include "/lib/depth.glsl"

#if defined DISTANT_RENDER_MOD && defined DISTANT_HORIZONS
    #include "/lib/depth_dh.glsl"
#endif

#include "/lib/luma.glsl"

#define FRAGMENT
#include "/lib/downscale.glsl"

// Aurora fantasy-puddle reflection system
#if defined RAIN_PUDDLES && !defined NETHER && !defined THE_END
    #include "/lib/aurora.glsl"
    #include "/lib/fantasy_reflections.glsl"
    #include "/lib/water_palette.glsl"
#endif

// Aurora fantasy fireflies system
#include "/lib/fireflies.glsl"

#if defined RAIN_PUDDLES && !defined NETHER && !defined THE_END
float sample_fantasy_habitat(vec2 sampleCoord) {
    vec4 habitatData = texture2D(
        colortex9, clamp(sampleCoord, vec2(0.0), vec2(1.0)));
    if (habitatData.z < 0.49) {
        return 0.0;
    }
    return clamp(
        (habitatData.z - 0.5) / 0.49,
        0.0, 1.0);
}
#endif



// --- NOISE FUNCTIONS FOR MOON TEXTURE (VORONOI / CRATERS) ---
vec2 moon_hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

// Cellular Noise (Voronoi) - Good for Craters
float moon_voronoi(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);
    float m = 8.0;
    for(int j=-1; j<=1; j++)
    for(int i=-1; i<=1; i++) {
        vec2 g = vec2(float(i),float(j));
        vec2 o = moon_hash22( n + g );
        // Animate? No, static moon.
        vec2 r = g - f + o;
        float d = dot(r,r);
        if( d<m ) m=d;
    }
    return m;
}

// FBM for Maria (Dark patches) - Keep standard noise for this
float moon_hash12_low(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
float moon_noise_low(in vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);
    f = f*f*(3.0-2.0*f);
    float res = mix(mix( moon_hash12_low(p), moon_hash12_low(p + vec2(1.0, 0.0)), f.x),
                    mix( moon_hash12_low(p + vec2(0.0, 1.0)), moon_hash12_low(p + vec2(1.0, 1.0)), f.x), f.y);
    return res;
}
float moon_fbm_low(vec2 p) {
    float f = 0.0; float w = 0.5;
    for (int i = 0; i < 4; i++) { f += w * moon_noise_low(p); p *= 2.0; w *= 0.5; }
    return f;
}
// ----------------------------------------

// MAIN FUNCTION ------------------

void main() {
    vec4 block_color = texture2DLod(colortex1, texcoord, 0);
    float fireflyReactiveMask = 0.0;
    float d = texture2DLod(depthtex0, texcoord, 0).r;
    float linear_d = ld(d);

    #if defined DISTANT_RENDER_MOD && defined DISTANT_HORIZONS
        float dh_d = texture2DLod(dhDepthTex0, texcoord, 0).r;
        float linear_dh_d = ld_dh(dh_d);
        bool is_sky = linear_d > 0.9999 && linear_dh_d > 0.9999;
    #else
        bool is_sky = linear_d > 0.9999;
    #endif

    vec2 eye_bright_smooth = vec2(eyeBrightnessSmooth);

    // Depth to distance
    float screen_distance = linear_d * far * 0.5;
    
    #if defined THE_END || defined NETHER
        #define NIGHT_CORRECTION 1.0
        #define COLOR_CORRECTION day_blend(vec3(1.0, 0.8, 1.0), vec3(1.0), vec3(1.0, 0.6, 1.0))
    #else
        #define NIGHT_CORRECTION day_blend_float(0.5, 0.75, 5.0)
        #define COLOR_CORRECTION day_blend(vec3(1.0, 0.8, 1.0), vec3(1.0), vec3(1.0, 0.6, 1.0))
    #endif

    // Underwater fog
    // Pre-calculating values.
    float water_absorption_exponent_val = WATER_FOG + (WATER_ABSORPTION * 4.0);
    float eye_brightness_scaled_val = (eye_bright_smooth.y * .8 + 48.0) * 0.004166666666666667;
    vec3 water_light_color_base = NIGHT_CORRECTION * WATER_COLOR * COLOR_CORRECTION * direct_light_strength;

    if(isEyeInWater == 1) {
        float water_absorption = clamp(-pow((-linear_d + 1.0), water_absorption_exponent_val) + 1.0, 0.0, 1.0);

        block_color.rgb =
            mix(block_color.rgb, water_light_color_base * eye_brightness_scaled_val, water_absorption);

    } else if(isEyeInWater == 2) {
        block_color = mix(block_color, vec4(1.0, .1, 0.0, 1.0), clamp(sqrt(linear_d * (far * 0.125)), 0.0, 1.0));
    }

    #if MC_VERSION >= 11900
        if((blindness > .01 || darknessFactor > .01) && linear_d > 0.999) {
            block_color.rgb = vec3(0.0);
        }
    #else
        if(blindness > .01 && linear_d > 0.999) {
            block_color.rgb = vec3(0.0);
        }
    #endif


    
    // Dentro de la nieve
    #ifdef BLOOM
        if(isEyeInWater == 3) {
            block_color.rgb =
                mix(block_color.rgb, vec3(0.7, 0.8, 1.0) / exposure, clamp(screen_distance, 0.0, 1.0));
        }
    #else
        if(isEyeInWater == 3) {
            block_color.rgb =
                mix(block_color.rgb, vec3(0.85, 0.9, 0.6), clamp(screen_distance, 0.0, 1.0));
        }
    #endif

    // --- ANALYTIC SUN & MOON FOR NON-VOLUMETRIC SKY PASSES ---
    // With volumetric clouds enabled, this is drawn in deferred before clouds.
    // Sun/moon use gbufferProjection so they move with the world, not independently.
    // Only the angular RADIUS uses FOV compensation to keep disc size stable.
    #if !defined(NETHER) && !defined(THE_END) && (V_CLOUDS <= 0 || defined(UNKNOWN_DIM) || defined(NO_CLOUDY_SKY))

        // sunPosition is view-space — project through the real game projection matrix
        // so the sun sticks to the sky exactly like every other object in the world.
        vec4 sunClipPos  = gbufferProjection * vec4(sunPosition, 1.0);
        vec2 sunScreen   = (sunClipPos.xy / sunClipPos.w) * 0.5 + 0.5;

        vec4 moonClipPos = gbufferProjection * vec4(-sunPosition, 1.0);
        vec2 moonScreen  = (moonClipPos.xy / moonClipPos.w) * 0.5 + 0.5;

        float aspectRatio = viewWidth / viewHeight;

        // FOV-compensated scale: gbufferProjection[1][1] = 1/tan(fov_y/2)
        // This keeps the angular disc size constant when FOV changes (sprint, zoom).
        float fovScale = gbufferProjection[1][1] * 0.5;

        // Angular radii — multiply by fovScale so the disc covers the same angle at any FOV
        float sunRad      = 0.03923 * fovScale;
        float sunGlowRad  = 0.16806 * fovScale;
        float moonRad     = 0.03923 * fovScale;
        float moonGlowRad = 0.21007 * fovScale;

        // Horizon fade: convert sun direction to world space for a stable Y check
        vec3 sunWorldDir = normalize((gbufferModelViewInverse * vec4(normalize(sunPosition), 0.0)).xyz);
        float sunHorizonFade  = smoothstep(-0.05, 0.05, sunWorldDir.y);
        float moonHorizonFade = smoothstep(-0.05, 0.05, -sunWorldDir.y);
        
        // Depth Check (Don't draw over blocks - strict sky-only, DH-aware)
        if (is_sky) {
            // Weather Visibility Factor (Hide during rain)
            float weatherVisibility = 1.0 - rainStrength;
            
            // --- DRAW SUN ---
            if (sunClipPos.w > 0.0 && sunHorizonFade > 0.001) { // In front of camera AND above horizon
                vec2 distVec = (texcoord - sunScreen);
                distVec.x *= aspectRatio;
                float dist = length(distVec);
                
                if (dist < sunRad) {
                    float edge = fwidth(dist) * 2.0;
                    float alpha = smoothstep(sunRad, sunRad - edge, dist);
                    
                    // Texture Mapping for Solar Granulation
                    // Normalize by radius so texture is FOV-independent
                    vec2 sunUV = (distVec / sunRad) * 14.0;
                    
                    // Solar Granulation (Convection cells)
                    float granulation = moon_voronoi(sunUV * 2.0);
                    granulation = smoothstep(0.1, 0.6, granulation);
                    
                    // Add turbulence
                    float turbulence = moon_fbm_low(sunUV * 1.5);
                    
                    // Radial gradient from center
                    float grad = 1.0 - (dist / sunRad);
                    
                    // Color palette
                    vec3 sunCore = vec3(1.0, 1.0, 0.9);      // Bright yellow-white center
                    vec3 sunMid = vec3(1.0, 0.85, 0.4);      // Yellow
                    vec3 sunEdge = vec3(1.0, 0.5, 0.1);      // Orange-red edge
                    
                    // Base color with limb darkening
                    vec3 sunColor = mix(sunEdge, sunCore, pow(grad, 0.4));
                    
                    // Apply granulation (darker spots)
                    sunColor *= 0.7 + 0.3 * granulation;
                    
                    // Apply turbulence (variation)
                    sunColor *= 0.85 + 0.15 * turbulence;
                    
                    // Brightness (much lower to reveal texture)
                    sunColor *= 1.2;
                    
                    // Clamp to prevent color artifacts
                    sunColor = clamp(sunColor, vec3(0.0), vec3(10.0));
                    
                    // Apply Weather Visibility and Horizon Fade
                    alpha *= weatherVisibility * sunHorizonFade;
                    
                    block_color.rgb = mix(block_color.rgb, sunColor, alpha);
                }
                
                // Sun Glow (Halo)
                if (dist < sunGlowRad) {
                    float glow = smoothstep(sunGlowRad, sunRad, dist);
                    // Reduced glow intensity for balance + Weather/Horizon Visibility
                    block_color.rgb += vec3(1.0, 0.8, 0.4) * glow * 0.3 * weatherVisibility * sunHorizonFade; 
                }
            }

            // --- DRAW MOON ---
            if (moonClipPos.w > 0.0 && moonHorizonFade > 0.001) { // In front of camera AND above horizon
                vec2 distVec = (texcoord - moonScreen);
                distVec.x *= aspectRatio;
                float dist = length(distVec);
                
                // Draw Body
                if (dist < moonRad + 0.005 * fovScale / 0.71405) {
                    float edge = fwidth(dist) * 2.0;
                    float alpha = smoothstep(moonRad, moonRad - edge, dist);
                    
                    // Texture Mapping - Normalize by radius for FOV independence
                    vec2 moonUV = (distVec / moonRad) * 11.2;
                    
                    // 1. Craters (Voronoi)
                    // Voronoi returns distance to center. Invert for craters.
                    float v = moon_voronoi(moonUV * 1.5);
                    // Sharp edge craters
                    float craters = smoothstep(0.1, 0.4, v); 
                    
                    // 2. Maria (Dark Patches - FBM)
                    float mareNoise = moon_fbm_low(moonUV * 0.3 + vec2(8.0));
                    float mare = smoothstep(0.4, 0.7, mareNoise);
                    
                    // 3. Composite Colors (Reference Image Match)
                    // The reference is a cold, pale blue-grey with dark grey seas.
                    
                    vec3 colBright = vec3(0.9, 0.95, 1.0); // Pale Blue-White (Highlands)
                    vec3 colDark   = vec3(0.4, 0.45, 0.5); // Dark Grey-Blue (Maria)
                    vec3 colCrater = vec3(0.6, 0.65, 0.7); // Shadow inside craters
                    
                    // Base: Highlands vs Maria
                    vec3 moonColor = mix(colBright, colDark, mare);
                    
                    // Apply Craters (Small distinct dots)
                    // If 'craters' is low, it's a hole.
                    float craterMask = 1.0 - smoothstep(0.0, 0.2, v); // Points are 1.0
                    moonColor = mix(moonColor, colCrater, craterMask * 0.7);
                    
                    // 4. Falloff / Limb Darkening (Sphere shape)
                    float sphereGrad = sqrt(1.0 - clamp(dist/moonRad, 0.0, 1.0)); // Spherical normal Z
                    moonColor *= 0.5 + 0.5 * sphereGrad; // Shadow at edges
                   
                    // Brightness (Controlled - No Burn)
                    // Further reduced to 0.5 to show maximum crater detail
                    moonColor *= 0.5;
                    
                    // Apply Weather Visibility and Horizon Fade
                    alpha *= weatherVisibility * moonHorizonFade;
                    
                    block_color.rgb = mix(block_color.rgb, moonColor, alpha);
                }
                 
                // Moon Glow (Separate)
                if (dist < moonGlowRad) {
                    float glow = smoothstep(moonGlowRad, moonRad, dist);
                    // Subtle Glow (Reduced intensity from 1.5 to 0.4) + Weather/Horizon Visibility
                    block_color.rgb += vec3(0.1, 0.3, 1.0) * glow * 0.4 * weatherVisibility * moonHorizonFade;
                }
            }
        }
    #endif

    // === Clean Aurora Fantasy puddle reflections ===
    #if defined RAIN_PUDDLES && !defined NETHER && !defined THE_END
    {
        // depthtex2 owns the terrain surface carrying the puddle.  If the final
        // visible depth differs, an entity, player skin layer, hand, or other
        // foreground surface covers that terrain pixel.  Never composite the
        // puddle through it.  This is camera-mode independent and does not
        // remove mobs from reflection rays elsewhere on the puddle.
        float visibleDepth = texture2DLod(depthtex0, texcoord, 0).x;
        float terrainDepth = texture2DLod(depthtex2, texcoord, 0).x;
        bool hasForegroundSurface =
            abs(visibleDepth - terrainDepth) > 0.000075;

        vec4 reflectData = texture2D(colortex9, texcoord);
        float puddleMask = reflectData.x;
        float ssrPatchMask = reflectData.y;
        float puddleDepth = reflectData.w;
        float localPuddleLight = texture2D(colortex0, texcoord).r;
        float localPuddleLightMask = smoothstep(
            0.035, 0.42, localPuddleLight);
        vec4 puddleNormalData = texture2D(colortex8, texcoord);
        float surfaceDepth = terrainDepth;
        vec3 viewPos = fantasyScreenToView(texcoord, surfaceDepth);
        float visibleSurfaceDistance = clamp(
            log2(1.0 + length(viewPos)) / log2(1.0 + far),
            0.0, 1.0);
        float puddleSurfaceDelta = abs(
            puddleNormalData.a - visibleSurfaceDistance);
        bool ownsPuddleData = puddleNormalData.a > 0.0001
            && puddleSurfaceDelta < 0.00045;

        if (puddleMask > 0.002 && reflectData.z >= 0.49
                && !hasForegroundSurface && ownsPuddleData) {
            vec3 worldNormal = normalize(
                puddleNormalData.xyz * 2.0 - 1.0);
            vec3 viewNormal = normalize(mat3(gbufferModelView) * worldNormal);

            // Stable environment reflection for the whole pool. Unlike the old
            // constant blue value, this samples an actual horizon-to-zenith
            // storm gradient with the animated water normal, so the night-water
            // texture remains visible even where an SSR ray does not hit.
            vec3 worldViewIncident = normalize(
                mat3(gbufferModelViewInverse) * normalize(viewPos));
            vec3 environmentDirection = reflect(
                worldViewIncident, worldNormal);
            float environmentSkyHeight = sqrt(clamp(
                environmentDirection.y * 0.92 + 0.08, 0.0, 1.0));
            vec3 stormHorizon = max(
                mix(fogColor, skyColor, 0.18), vec3(0.0));
            vec3 stormZenith = max(
                mix(skyColor, fogColor, 0.34), vec3(0.0));
            vec3 currentWeatherSky = mix(
                stormHorizon, stormZenith, environmentSkyHeight);

            // Weather-aware night palette for water only. At early night this
            // removes the obsolete warm sun-direction tint; at midnight it
            // supplies the small amount of diffuse moon/cloud radiance needed
            // to reveal moving normals. It never replaces the rendered sky.
            float puddleNightAmount = day_blend_float(0.0, 0.0, 1.0);
            float midnightWindow = smoothstep(0.62, 0.72, day_moment)
                * (1.0 - smoothstep(0.90, 0.985, day_moment));
            float stormNightBalance = rainStrength
                * smoothstep(0.025, 0.62, puddleNightAmount);
            float weatherSkyLuma = dot(
                currentWeatherSky, vec3(0.2126, 0.7152, 0.0722));
            vec3 neutralNightSky = max(
                vec3(weatherSkyLuma)
                    * auroraWaterPaletteHue(puddleDepth * 0.36),
                mix(vec3(0.012, 0.019, 0.030),
                    vec3(0.016, 0.026, 0.043), midnightWindow));
            currentWeatherSky = mix(
                currentWeatherSky, neutralNightSky,
                stormNightBalance
                * mix(0.92, 0.72, localPuddleLightMask));

            // Optical body for the shallow water layer. The shared animated
            // normal bends the view of the ground beneath the puddle; RGB
            // absorption and restrained in-scattering increase with procedural
            // depth. This creates readable water thickness without moving the
            // terrain geometry or painting an opaque colour over it.
            vec2 puddlePixel = vec2(1.0 / viewWidth, 1.0 / viewHeight);
            float opticalThickness = puddleMask
                * mix(0.16, 1.0, puddleDepth);
            vec2 refractionOffset = viewNormal.xy * puddlePixel
                * mix(0.8, 3.8, puddleDepth) * puddleMask;
            vec2 refractedUV = clamp(
                texcoord + refractionOffset, vec2(0.001), vec2(0.999));
            float refractedTerrainDepth = texture2D(depthtex2, refractedUV).r;
            float refractionAgreement = 1.0 - smoothstep(
                0.00015, 0.0025,
                abs(refractedTerrainDepth - terrainDepth));
            vec3 refractedGround = texture2D(colortex1, refractedUV).rgb;
            float refractedLuma = dot(
                refractedGround, vec3(0.2126, 0.7152, 0.0722));
            float readableRefractedLuma = max(
                refractedLuma, sqrt(max(refractedLuma, 0.0)) * 0.14);
            vec3 neutralRefractedGround = vec3(readableRefractedLuma)
                * auroraWaterPaletteHue(puddleDepth * 0.36);
            refractedGround = mix(
                refractedGround, neutralRefractedGround,
                stormNightBalance
                * mix(0.36, 0.28, localPuddleLightMask));
            vec3 waterTransmittance = exp(
                -vec3(1.32, 0.78, 0.42) * opticalThickness);
            vec3 shallowScatter = currentWeatherSky
                * (vec3(1.0) - waterTransmittance) * 0.18;
            vec3 volumeWater = refractedGround * waterTransmittance
                + shallowScatter;
            float refractionBlend = puddleMask * refractionAgreement
                * mix(0.22, 0.60, puddleDepth);
            block_color.rgb = mix(
                block_color.rgb, volumeWater,
                clamp(refractionBlend, 0.0, 0.56));

            // Moving normal contrast remains visible even when both the ground
            // and the storm sky are extremely dark. This is reflected ambient
            // energy shaped by wave slope, not a uniform colour overlay.
            float compositeWaveEnergy = clamp(
                length(worldNormal.xz) * 1.55, 0.0, 1.0);
            float nightWaveVisibility = puddleMask * rainStrength
                * puddleNightAmount
                * (0.012 + 0.105 * compositeWaveEnergy);
            block_color.rgb += currentWeatherSky * nightWaveVisibility;

            vec3 toCamera = normalize(-viewPos);
            float waterFresnel = 0.04 + 0.96 * pow(
                1.0 - max(dot(viewNormal, toCamera), 0.0), 5.0);
            float depthStrength = mix(0.68, 1.0, puddleDepth);
            float baseWeatherBlend = puddleMask * depthStrength
                * mix(0.12, 0.28, waterFresnel);
            block_color.rgb = mix(block_color.rgb, currentWeatherSky,
                clamp(baseWeatherBlend, 0.0, 0.32));

            // The terrain pass stored the real block-light field before this
            // optical water body was assembled. Reintroduce it here so nearby
            // torches, lanterns and emissive blocks illuminate the final water
            // surface, with moving-normal contrast instead of a flat overlay.
            float configuredBlockLightPeak = max(
                CANDLE_BASELIGHT.r,
                max(CANDLE_BASELIGHT.g, CANDLE_BASELIGHT.b));
            vec3 configuredBlockLightHue = CANDLE_BASELIGHT
                / max(configuredBlockLightPeak, 0.0001);
            // Diffuse illumination stays mostly neutral, like a softer local
            // daylight exposure, while the separate specular lobe retains the
            // source's configured block-light colour.
            vec3 localDiffuseLightTint = mix(
                vec3(1.0), configuredBlockLightHue, 0.32);
            vec3 localSourceReflectionTint = mix(
                vec3(1.0), configuredBlockLightHue, 0.68);
            vec3 localGlintDirectionA = normalize(
                vec3(0.58, 0.78, 0.23));
            vec3 localGlintDirectionB = normalize(
                vec3(-0.31, 0.89, 0.33));
            float localDirectionalGlint = pow(max(dot(
                worldNormal, localGlintDirectionA), 0.0), 18.0)
                + pow(max(dot(
                    worldNormal, localGlintDirectionB), 0.0), 28.0) * 0.72;
            float localWaveGlint = clamp(
                0.18 + compositeWaveEnergy * 0.42
                    + localDirectionalGlint * 1.65,
                0.18, 1.72);
            float localWaveHighlight = smoothstep(
                0.28, 1.05, localWaveGlint);
            float concentratedLocalLight = pow(
                clamp(localPuddleLight, 0.0, 1.0), 1.45);

            // Illuminate the existing water body multiplicatively. This reveals
            // ground transmission and moving texture without replacing either
            // with a flat coloured patch. The nonlinear response keeps the
            // effect close to the emitting blocks and preserves their falloff.
            float localDiffuseIllumination = puddleMask
                * localPuddleLightMask
                * concentratedLocalLight
                * mix(0.72, 0.48, puddleDepth)
                * mix(0.90, 1.08, localWaveHighlight)
                * mix(0.18, 1.0, puddleNightAmount);
            block_color.rgb *= vec3(1.0)
                + localDiffuseLightTint
                * localDiffuseIllumination * 1.15;

            // A much smaller coloured lobe belongs only to wave highlights.
            // It supplies torch/lantern colour without tinting the whole pool.
            float localLightSurfaceWeight = puddleMask
                * localPuddleLightMask
                * mix(0.006, 0.065, concentratedLocalLight)
                * mix(0.25, 0.78, waterFresnel)
                * mix(0.20, 1.0, localWaveHighlight)
                * mix(0.38, 1.0, puddleNightAmount);
            block_color.rgb += localSourceReflectionTint
                * localLightSurfaceWeight;

            // Ordinary geometry remains sparse, but genuinely illuminated parts
            // of a puddle receive a wider SSR footprint. This stays local to
            // block light and cannot turn the whole pool into a moving mirror.
            float litSSRMask = max(
                ssrPatchMask,
                localPuddleLightMask
                    * mix(0.05, 0.46, concentratedLocalLight));
            if (litSSRMask > 0.002) {
                vec4 reflectionColor = traceFantasyReflection(
                    viewPos, viewNormal, colortex1, depthtex0, depthtex2,
                    firstPersonCamera);
                vec3 reflectViewDir = reflect(
                    normalize(viewPos), viewNormal);
                vec2 reflectedSceneUV = fantasyViewToScreen(
                    reflectViewDir * 64.0);
                float reflectionDirectionVisible = step(
                    reflectViewDir.z, -0.001);
                float reflectedScreenWeight = reflectionDirectionVisible
                    * fantasyReflectionEdgeFade(reflectedSceneUV);

                // A compact three-tap rough reflection removes razor-sharp
                // screen pixels and reads as shallow moving water thickness.
                vec2 reflectionBlurOffset = vec2(
                    1.0 / viewWidth, 1.0 / viewHeight)
                    * mix(2.4, 0.75, puddleDepth);
                vec2 reflectionUV = clamp(
                    reflectedSceneUV, vec2(0.001), vec2(0.999));
                vec2 reflectionUVPositive = clamp(
                    reflectionUV + reflectionBlurOffset,
                    vec2(0.001), vec2(0.999));
                vec2 reflectionUVNegative = clamp(
                    reflectionUV - reflectionBlurOffset,
                    vec2(0.001), vec2(0.999));
                vec3 reflectedCurrentScene =
                    texture2D(colortex1, reflectionUV).rgb * 0.50
                    + texture2D(colortex1, reflectionUVPositive).rgb * 0.25
                    + texture2D(colortex1, reflectionUVNegative).rgb * 0.25;
                vec3 reflectedPatchSky = mix(
                    currentWeatherSky,
                    reflectedCurrentScene,
                    reflectedScreenWeight);
                float ssrConfidence = reflectionColor.a;
                vec3 patchReflection = mix(
                    reflectedPatchSky,
                    reflectionColor.rgb,
                    ssrConfidence);
                float ssrBlend = puddleMask * litSSRMask
                    * depthStrength * mix(0.16, 0.50, waterFresnel)
                    * mix(0.55, 1.0, ssrConfidence)
                    * (float(SSR_STRENGTH) * 0.1);
                float localGeometryReflection = puddleMask
                    * localPuddleLightMask
                    * concentratedLocalLight
                    * depthStrength
                    * mix(0.07, 0.22, waterFresnel)
                    * mix(0.45, 1.0, ssrConfidence);
                ssrBlend = max(ssrBlend, localGeometryReflection);
                block_color.rgb = mix(
                    block_color.rgb,
                    patchReflection,
                    clamp(ssrBlend, 0.0, 0.34));

                // Preserve the actual on-screen colour of bright reflected
                // sources. Dark buildings and terrain receive no additive lift;
                // only torch, lantern and luminous-block energy creates this
                // restrained highlight over the water texture.
                float patchReflectionLuma = dot(
                    patchReflection, vec3(0.2126, 0.7152, 0.0722));
                float reflectedSourceSignal = smoothstep(
                    0.10, 0.52, patchReflectionLuma)
                    * localPuddleLightMask;
                vec3 compressedSourceReflection = patchReflection
                    / (vec3(1.0) + patchReflection * 0.35);
                float reflectedSourceWeight = puddleMask
                    * litSSRMask
                    * reflectedSourceSignal
                    * mix(0.025, 0.13, waterFresnel)
                    * mix(0.58, 1.0, localWaveHighlight);
                block_color.rgb += compressedSourceReflection
                    * reflectedSourceWeight;
            }
        }
    }
    #endif


    #if defined FANTASY_LIFE_SYSTEM && FANTASY_FIREFLIES > 0 && !defined NETHER && !defined THE_END
    if (isEyeInWater == 0) {
        vec4 sceneViewHomogeneous = gbufferProjectionInverse
            * vec4(texcoord * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
        vec3 sceneViewPosition = sceneViewHomogeneous.xyz
            / max(sceneViewHomogeneous.w, 0.00001);
        vec3 viewRay = normalize(sceneViewPosition);
        vec3 worldRay = normalize(
            (gbufferModelViewInverse * vec4(viewRay, 0.0)).xyz);

        float sceneDistance = is_sky
            ? min(far, 48.0)
            : length(sceneViewPosition);
        vec3 visibleSurfaceWorld = cameraPosition
            + worldRay * sceneDistance;
        float nightAmount = day_blend_float(0.0, 0.0, 1.0);
        float skyLight = clamp(eye_bright_smooth.y / 240.0, 0.0, 1.0);
        float fireflyGroundY = visibleSurfaceWorld.y;
        float fireflyGroundVisibility = 1.0;
        float projectedGroundHabitat = 0.0;

        // Sky pixels have no native surface depth, which previously disabled
        // every volumetric firefly silhouetted against the horizon. Scan down
        // the same screen column for visible terrain, reconstruct its world Y,
        // and use that local surface as the swarm floor. Updating through the
        // scan favors the lower dirt/grass surface beneath foliage silhouettes.
        if (is_sky && nightAmount > 0.01 && worldRay.y < 0.52) {
            #if PROFILE_QUALITY == 1
                const int fireflyGroundSteps = 4;
            #else
                const int fireflyGroundSteps = 7;
            #endif
            for (int groundStep = 1; groundStep <= fireflyGroundSteps; groundStep++) {
                float groundScanAmount = float(groundStep)
                    / float(fireflyGroundSteps);
                vec2 groundSampleCoord = vec2(
                    texcoord.x,
                    mix(texcoord.y, 0.055, groundScanAmount));
                #ifdef RAIN_PUDDLES
                    float groundDepth = texture2DLod(
                        depthtex2, groundSampleCoord, 0).x;
                #else
                    float groundDepth = texture2DLod(
                        depthtex0, groundSampleCoord, 0).x;
                #endif

                if (ld(groundDepth) < 0.9999) {
                    vec4 groundViewHomogeneous =
                        gbufferProjectionInverse * vec4(
                            groundSampleCoord * 2.0 - 1.0,
                            groundDepth * 2.0 - 1.0,
                            1.0);
                    vec3 groundViewPosition =
                        groundViewHomogeneous.xyz
                        / max(groundViewHomogeneous.w, 0.00001);
                    vec3 groundRelativeWorld =
                        mat3(gbufferModelViewInverse)
                        * groundViewPosition;
                    fireflyGroundY =
                        cameraPosition.y + groundRelativeWorld.y;
                    fireflyGroundVisibility = 1.0;

                    #ifdef RAIN_PUDDLES
                        projectedGroundHabitat = max(
                            projectedGroundHabitat,
                            sample_fantasy_habitat(
                                groundSampleCoord));
                    #endif
                }
            }
        }

        vec3 habitatColor = max(block_color.rgb, vec3(0.0));
        float greenHabitat = clamp(
            habitatColor.g
                - max(habitatColor.r, habitatColor.b) * 0.62,
            0.0, 1.0);
        float habitatPeak = max(
            max(habitatColor.r, habitatColor.g), habitatColor.b);
        float habitatLow = min(
            min(habitatColor.r, habitatColor.g), habitatColor.b);
        float flowerHabitat = clamp(
            (habitatPeak - habitatLow) * 0.42, 0.0, 0.35);
        float horizonHabitat = 1.0
            - smoothstep(0.16, 0.56, worldRay.y);
        float materialHabitat = 0.0;
        float nearbyMaterialHabitat = 0.0;
        #ifdef RAIN_PUDDLES
            materialHabitat = sample_fantasy_habitat(texcoord);
            if (nightAmount > 0.01) {
                vec2 habitatPixel = vec2(
                    1.0 / viewWidth, 1.0 / viewHeight);
                vec2 habitatOffsetX = vec2(
                    habitatPixel.x * 13.0, 0.0);
                vec2 habitatOffsetY = vec2(
                    0.0, habitatPixel.y * 13.0);
                #if PROFILE_QUALITY == 1
                    // Two diagonal probes retain a wide vegetation catchment
                    // with half the material-buffer reads.
                    nearbyMaterialHabitat = max(
                        sample_fantasy_habitat(
                            texcoord + habitatOffsetX + habitatOffsetY),
                        sample_fantasy_habitat(
                            texcoord - habitatOffsetX - habitatOffsetY));
                #else
                    nearbyMaterialHabitat = max(
                        max(
                            sample_fantasy_habitat(
                                texcoord + habitatOffsetX),
                            sample_fantasy_habitat(
                                texcoord - habitatOffsetX)),
                        max(
                            sample_fantasy_habitat(
                                texcoord + habitatOffsetY),
                            sample_fantasy_habitat(
                                texcoord - habitatOffsetY)));
                #endif
            }
        #endif
        float orbitHabitat = max(
            materialHabitat, nearbyMaterialHabitat * 0.94);
        float releaseHabitat = max(
            materialHabitat, nearbyMaterialHabitat);
        float releaseAmount = smoothstep(
            0.82, 0.98, releaseHabitat);
        float habitatAmount = is_sky
            ? clamp(
                0.25 * horizonHabitat
                    + nearbyMaterialHabitat * 0.72
                    + projectedGroundHabitat * 0.68,
                0.0, 1.0)
            : clamp(
                0.35
                + greenHabitat * 0.40
                + flowerHabitat * 0.30
                + orbitHabitat * 0.85,
                0.0, 1.0);

        vec3 fireflyLighting = render_fantasy_fireflies(
            cameraPosition,
            worldRay,
            sceneDistance,
            nightAmount,
            skyLight,
            rainStrength,
            habitatAmount,
            releaseAmount,
            fireflyGroundY,
            fireflyGroundVisibility,
            persistentTimeSeconds,
            fireflyReactiveMask
        );
        block_color.rgb += fireflyLighting;
    }
    #endif

    #ifdef BLOOM
        // Bloom source
        float bloom_luma;
        if(fragment_cull()){
            bloom_luma = 0.0;
        } else {
            bloom_luma = smoothstep(0.85, 1.0, luma(block_color.rgb * exposure)) * 0.5;
        }
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));     
        /* DRAWBUFFERS:146 */
        gl_FragData[0] = block_color;
        // RGB remains the bloom source. Alpha carries a full-resolution
        // firefly reactive mask; bloom only samples RGB.
        gl_FragData[1] = vec4(
            block_color.rgb * bloom_luma,
            fireflyReactiveMask);
        gl_FragData[2] = vec4(exposure, 0.0, 0.0, 0.0);
    #else
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        /* DRAWBUFFERS:16 */
        gl_FragData[0] = block_color;
        gl_FragData[1] = vec4(exposure, 0.0, 0.0, 0.0);
    #endif
}
