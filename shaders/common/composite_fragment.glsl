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
uniform float frameTime;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#if !defined NETHER && !defined THE_END
    uniform vec3 sunPosition;
    uniform mat4 gbufferProjection;
    uniform mat4 gbufferModelViewInverse;
#endif

// SSR uniforms (Reflectify RT system)
#if defined RAIN_PUDDLES && !defined NETHER && !defined THE_END
    uniform sampler2D colortex8; // SSR Normals from gbuffers
    uniform sampler2D colortex9; // SSR Reflectivity + Roughness from gbuffers
    uniform sampler2D depthtex2; // Depth without hand & translucents — used to skip hand pixels in SSR
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelView;
    uniform vec3 cameraPosition;
    uniform float pixel_size_x;
    uniform float pixel_size_y;
#endif

/* Ins / Outs */

varying vec2 texcoord;
varying vec3 direct_light_color;
varying vec3 direct_light_strength;
varying float exposure;



/* Utility functions */

#include "/lib/fps_correction.glsl"
#include "/lib/basic_utils.glsl"
#include "/lib/depth.glsl"

#if defined DISTANT_RENDER_MOD && defined DISTANT_HORIZONS
    #include "/lib/depth_dh.glsl"
#endif

#ifdef BLOOM
    #include "/lib/luma.glsl"
#endif

#define FRAGMENT
#include "/lib/downscale.glsl"

// SSR includes (Reflectify RT system)
#if defined RAIN_PUDDLES && !defined NETHER && !defined THE_END
    #include "/lib/ssr_math.glsl"
    #include "/lib/ssr_transformations.glsl"
    #include "/lib/ssr_reflection.glsl"
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
        // vec2 r = g - f + (0.5+0.5*sin(frameTimeCounter+6.2831*o));
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

    // --- SCREEN SPACE SUN & MOON FALLBACK (WORLD-LOCKED) ---
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

    // === Screen-Space Reflections (Reflectify RT SSR System) ===
    #if defined RAIN_PUDDLES && !defined NETHER && !defined THE_END
    {
        // Skip SSR on hand pixels: depthtex0 includes hand, depthtex2 excludes hand & translucents
        float handDepth = texture2DLod(depthtex0, texcoord, 0).x;
        float noHandDepth = texture2DLod(depthtex2, texcoord, 0).x;
        bool isHandPixel = abs(handDepth - noHandDepth) > 0.0001;

        vec4 reflectData = texture2D(colortex9, texcoord);
        float reflectivity = reflectData.x;
        float roughness = reflectData.y;

        // Only apply SSR where gbuffers wrote reflection data (z == 0.5 marker) and NOT on hand
        if (reflectivity > MIN_REFLECTIVITY && abs(reflectData.z - 0.5) < 0.01 && !isHandPixel) {
            // Read the encoded normal from colortex8
            vec3 prenormal = ssr_screen2ndc(texture2D(colortex8, texcoord).xyz);

            // Read depth (use depthtex2 to exclude hand geometry)
            float ssrDepth = texture2D(depthtex2, texcoord).x;

            // Transform normal from world/player space to view space
            vec3 viewNormal = ssr_eye2view(prenormal);

            // Get view-space position
            vec3 viewPos = ssr_screen2view(texcoord, ssrDepth);
            vec3 feetPos = ssr_view2feet(viewPos);
            vec3 worldPos = ssr_feet2world(feetPos);

            // Add roughness-based normal perturbation (Reflectify style)
            float pixelDistance = min(1.0, length(feetPos) / 16.0);
            float stepSize = ssr_stepify(mix(1.0/512.0, 1.0/64.0, pixelDistance), 1.0/512.0);
            viewNormal += roughness * ssr_random3(ssr_stepify3(worldPos, stepSize));
            viewNormal = normalize(viewNormal);

            // Perform SSR ray-march (use depthtex2 so reflected rays don't hit hand)
            vec4 reflectionColor = getReflectionColor(ssrDepth, viewNormal, viewPos, colortex1, depthtex2);

            // Blend reflection into scene
            block_color.rgb = mix(block_color.rgb, reflectionColor.rgb,
                reflectionColor.a * reflectivity * 0.1 * float(SSR_STRENGTH));
        }
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
        gl_FragData[1] = block_color * bloom_luma;
        gl_FragData[2] = vec4(exposure, 0.0, 0.0, 0.0);
    #else
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        /* DRAWBUFFERS:16 */
        gl_FragData[0] = block_color;
        gl_FragData[1] = vec4(exposure, 0.0, 0.0, 0.0);
    #endif
}
