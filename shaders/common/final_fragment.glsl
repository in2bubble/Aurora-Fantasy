#include "/lib/config.glsl"
#include "/lib/luma.glsl"


// Do not remove comments. It works!
/*

noisetex - Water normals
colortex0 - Unused
colortex1 - Antialiasing auxiliar
colortex2 - Unused
colortex3 - TAA Averages history
gaux1 - Screen-Space-Reflection / Bloom auxiliar
gaux2 - Clouds texture natural and vanilla
gaux3 - Exposure auxiliar
gaux4 - Fog auxiliar

const int noisetexFormat = RG8;
const int colortex0Format = R8;
*/
/*
const int colortex1Format = RGBA16;
const int colortex3Format = RGBA16;
*/
/*
const int gaux1Format = RGBA8;
const int gaux2Format = R8;
const int gaux3Format = R16F;
const int gaux4Format = R11F_G11F_B10F;

const int colortex8Format = RGBA8;
const int colortex9Format = RGBA8;

const int shadowcolor0Format = RGBA8;
*/

// Buffers clear
const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex2Clear = false;
const bool colortex3Clear = false;
const bool gaux1Clear = false;
const bool gaux2Clear = false;
const bool gaux3Clear = false;
const bool gaux4Clear = false;
const bool colortex8Clear = true;
const bool colortex9Clear = true;

/* Uniforms */

#ifdef DEBUG_MODE
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D colortex3;
#endif

uniform sampler2D gaux3;
uniform sampler2D colortex1;
uniform int isEyeInWater;
uniform float nightVision;
uniform float rainStrength;
uniform float wetness;
uniform float day_moment;
uniform float day_mixer;
uniform float night_mixer;
uniform float near;
uniform float far;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

/* Ins / Outs */

varying vec2 texcoord;
varying float exposure;

/* Utility functions */

#include "/lib/basic_utils.glsl"
#include "/lib/depth.glsl"
#include "/lib/tone_maps.glsl"
#include "/lib/dither.glsl"

#ifdef COLOR_BLINDNESS
    #include "/lib/color_blindness.glsl"
#endif

#ifdef CHROMA_ABER
    #include "/lib/aberration.glsl"
#endif

#include "/lib/day_blend.glsl"

// Vignette, Film grain, Sharpening and Fake bloom.
#if defined VIGNETTE || defined FAKE_BLOOM || defined FILM_GRAIN || defined COLOR_BLINDNESS || AA_TYPE == 3
    #include "/lib/post_processing.glsl"    
#endif


#ifdef FXAA
    #include "/lib/fxaa.glsl"
#endif

#define FRAGMENT
#include "/lib/downscale.glsl"

void main() {
    vec2 pixelUV = texcoord;

    #ifdef PS1_LIKE
        pixelUV = floor(texcoord * vec2(viewWidth, viewHeight) / PIXEL_SIZE) * PIXEL_SIZE / vec2(viewWidth, viewHeight) * RENDER_SCALE;
    #endif // PS1 filter

    #ifdef CHROMA_ABER
        vec3 block_color = color_aberration();
    #else
       vec3 block_color = texture2DLod(colortex1, pixelUV, 0.0).rgb;

       #if AA_TYPE == 3 && !defined PS1_LIKE
            #ifdef FXAA
               block_color = fxaa311(block_color, 3, pixelUV);
            #endif

            block_color = sharpen(colortex1, block_color, pixelUV);
        #endif
    #endif

    // Dark areas dessaturation and blueness.
    if (isEyeInWater == 1) {
        float luma_factor = luma(block_color);
        float shadow_desaturation = smoothstep(0.01, 0.455, luma_factor);
        // Blue-green tint stronger in darker underwater areas, natural in lit areas
        block_color = mix(block_color * vec3(0.7, 0.95, 1.3), block_color, shadow_desaturation);
    } else {
        float luma_factor = luma(block_color);
        float shadow_desaturation = smoothstep(0.01, 0.175, luma_factor);
        vec3 stylized_shadow = saturate(
            block_color,
            clamp(luma_factor + 0.5, 0.7, 1.0)
        ) * vec3(0.9, 0.95, 1.1);

        // Keep the original material chroma after sunset. The legacy shadow
        // grade deliberately desaturates and blues dark pixels, which is useful
        // by day but turns night terrain into a flat grey-green surface.
        #if !defined NETHER && !defined THE_END
            float night_color_retention = smoothstep(
                0.48, 0.54, day_moment
            ) * (1.0 - smoothstep(0.90, 0.99, day_moment));
        #else
            float night_color_retention = 0.0;
        #endif
        float original_color_weight = max(
            shadow_desaturation,
            night_color_retention * 0.82
        );
        block_color = mix(
            stylized_shadow,
            block_color,
            original_color_weight
        );
    } // Water overlay

    #if !defined NETHER && !defined THE_END
        // Cache a sky-only Night Vision response here, but apply its visible
        // floor after tonemapping. Applying it before exposure allowed the
        // later night grade to crush the horizon back to pure black.
        float finalNightVision = clamp(
            nightVision * NIGHT_VISION_BOOST,
            0.0,
            1.0
        );
        float nightVisionNight = day_blend_float(0.0, 0.0, 1.0);
        float nightVisionDepth = texture2DLod(
            depthtex0,
            pixelUV,
            0.0
        ).r;
        float nightVisionSkyMask = smoothstep(
            0.9990,
            0.99995,
            nightVisionDepth
        );
        float nightVisionSkyWeight = finalNightVision
            * nightVisionNight
            * nightVisionSkyMask;
    #endif

    #if defined SIMPLE_AUTOEXP && COLOR_SCHEME != 11
        float exposure_final = day_blend_float(1.5, 0.85, 2.25);
    #elif COLOR_SCHEME == 11 && defined SIMPLE_AUTOEXP
        float exposure_final = day_blend_float(0.75, 0.75, 2.0);
    #elif COLOR_SCHEME == 11 && !defined SIMPLE_AUTOEXP
        float exposure_final = exposure * day_blend_float(0.8, 1.0, 1.0);
    #else
        float exposure_final = exposure;
    #endif

    // Time-aware Overworld grading. A small common night response keeps the
    // sky, fog and world in one exposure domain. Extra terrain visibility fades
    // continuously with distance so silhouettes never form a cut-out horizon.
    float temporal_vibrance = 0.0;
    float foliage_compression_scale = 1.0;
    float midnight_surface_grade = 0.0;

    #if !defined NETHER && !defined THE_END
        float morning_distance = min(
            abs(day_moment - 0.045),
            abs(day_moment - 1.045)
        );
        float morning_grade = 1.0
            - smoothstep(0.035, 0.17, morning_distance);
        float afternoon_grade = 1.0
            - smoothstep(0.075, 0.22, abs(day_moment - 0.25));
        float early_night_grade = smoothstep(0.49, 0.545, day_moment)
            * (1.0 - smoothstep(0.64, 0.72, day_moment));
        float midnight_grade = smoothstep(0.64, 0.72, day_moment)
            * (1.0 - smoothstep(0.84, 0.96, day_moment));

        // depthtex0 is the closest visible surface, including translucent
        // water. depthtex1 points behind water and previously made an entire
        // lake inherit the gain of its distant floor.
        float scene_depth = texture2DLod(depthtex0, pixelUV, 0.0).r;
        float scene_linear_depth = ld(scene_depth);
        float opaque_depth = texture2DLod(depthtex1, pixelUV, 0.0).r;
        float opaque_linear_depth = ld(opaque_depth);
        float geometry_mask = 1.0
            - smoothstep(0.995, 0.9999, scene_linear_depth);
        midnight_surface_grade = midnight_grade * geometry_mask;
        float distance_continuity = 1.0
            - smoothstep(0.10, 0.62, scene_linear_depth);
        float translucent_separation = smoothstep(
            0.002,
            0.035,
            max(opaque_linear_depth - scene_linear_depth, 0.0)
        );
        float solid_surface_weight = 1.0
            - translucent_separation * 0.82;
        float scene_luma = luma(max(block_color, vec3(0.0)));
        float deep_shadow_mask = 1.0
            - smoothstep(0.025, 0.34, scene_luma);
        // Multiplicative lift preserves RGB ratios and therefore the authored
        // block hue. Unlike a neutral additive floor, it cannot wash terrain
        // into grey. Near-black geometry stays appropriately dark.
        float global_night_gain = 1.0
            - early_night_grade * 0.04
            - midnight_grade * 0.06;
        block_color *= global_night_gain;

        float rainy_midnight_amount = rainStrength * midnight_grade;
        float temporal_shadow_gain = 1.0
            + early_night_grade * 0.40
            + midnight_grade * mix(0.28, 0.10, rainStrength);
        block_color *= mix(
            1.0,
            temporal_shadow_gain,
            deep_shadow_mask * geometry_mask
                * distance_continuity * solid_surface_weight
        );

        // A fully overcast midnight must not inherit the apparent exposure of
        // a rainy afternoon. Darken the open sky/fog more than nearby terrain,
        // then compress the flat weather blue into a restrained moonlit navy.
        // This is active only while rain and the midnight window overlap, so
        // clear nights and daytime weather keep their established calibration.
        float rainy_midnight_gain = mix(0.66, 0.78, geometry_mask);
        block_color *= mix(
            1.0,
            rainy_midnight_gain,
            rainy_midnight_amount
        );
        float rainy_midnight_luma = luma(max(block_color, vec3(0.0)));
        vec3 rainy_midnight_tint = vec3(rainy_midnight_luma)
            * vec3(0.72, 0.82, 1.0);
        float rainy_midnight_tint_strength = mix(
            0.28,
            0.16,
            geometry_mask
        ) * rainy_midnight_amount;
        block_color = mix(
            block_color,
            rainy_midnight_tint,
            rainy_midnight_tint_strength
        );

        // Morning receives the most color recovery. Afternoon is deliberately
        // restrained because its existing balance is already close to ideal.
        temporal_vibrance = morning_grade * 0.14
            + afternoon_grade * 0.04
            + early_night_grade * 0.008
            + midnight_grade * 0.004;
        foliage_compression_scale = 1.0
            - morning_grade * 0.44
            + early_night_grade * 0.30
            + midnight_grade * 0.48
            + max(rainStrength, wetness) * 0.16;
    #endif

    block_color *= vec3(RED, GREEN, BLUE) * vec3(exposure_final * EXPOSURE) * BRIGHTNESS; // Color balance, Exposure, Brightness. 
    block_color = (block_color - 0.5) * CONTRAST + 0.5; // Contrast
    block_color = saturate(block_color.rgb, SATURATION); // Saturation
    block_color = vibrance(
        block_color.rgb,
        VIBRANCE + temporal_vibrance
    ); // User vibrance plus subtle time-aware color recovery.

    // Preserve hue detail in strongly biome-tinted foliage. This is selective:
    // neutral blocks, skin, clouds and the authored aurora palette are not
    // globally desaturated.
    float color_peak = max(block_color.r, max(block_color.g, block_color.b));
    float color_floor = min(block_color.r, min(block_color.g, block_color.b));
    float color_chroma = max(color_peak - color_floor, 0.0);
    float green_dominance = max(
        block_color.g - max(block_color.r, block_color.b), 0.0);
    float foliage_chroma = smoothstep(0.025, 0.24, green_dominance)
        * smoothstep(0.08, 0.62, color_chroma);
    block_color = mix(
        block_color,
        saturate(block_color, 0.76),
        foliage_chroma * 0.52 * foliage_compression_scale
    );

    // Grass at midnight often has modest chroma, so the stronger general
    // foliage detector above barely sees it. A wider, surface-only detector
    // removes the remaining green excess without touching the aurora or sky.
    float midnight_green_mask = smoothstep(
        0.012,
        0.15,
        green_dominance
    ) * smoothstep(0.025, 0.30, color_chroma);
    block_color = mix(
        block_color,
        saturate(block_color, 0.58),
        midnight_green_mask * midnight_surface_grade * 0.68
    );

    // Soft gamut compression keeps very intense colors from flattening into a
    // single clipped channel after tonemapping, at every time and dimension.
    float gamut_edge = smoothstep(0.72, 1.35, color_chroma)
        * smoothstep(0.45, 1.35, color_peak);
    block_color = mix(
        block_color,
        saturate(block_color, 0.82),
        gamut_edge * 0.32
    );
    block_color = max(block_color, vec3(0.0));
    block_color = pow(block_color.rgb, vec3(1 / GAMMA)); // Gamma
    
    #if TONEMAPPING == 0
        block_color = custom_sigmoid_alt(block_color);
    #elif TONEMAPPING == 1
        #ifdef HDR
        block_color = Lottes(block_color, 1.75);
        #else
        block_color = Lottes(block_color, 1.3);
        #endif
    #elif TONEMAPPING == 2
        block_color = ACESFilm(block_color, 2.6);
    #elif TONEMAPPING == 3
        block_color = Lottes(block_color, 0.1);
    #endif

    #if !defined NETHER && !defined THE_END
        // Keep Night Vision sky recognisably nocturnal: only near-black sky is
        // raised, using a subdued navy rather than a neutral grey. This runs in
        // display space so the final exposure/tonemap cannot erase it again.
        float nightVisionDisplaySkyLuma = luma(max(block_color, vec3(0.0)));
        float nightVisionDisplaySkyDarkness = 1.0 - smoothstep(
            0.035,
            0.20,
            nightVisionDisplaySkyLuma
        );
        vec3 nightVisionDisplaySkyFloor = vec3(0.055, 0.082, 0.135);
        block_color = mix(
            block_color,
            max(block_color, nightVisionDisplaySkyFloor),
            nightVisionSkyWeight * nightVisionDisplaySkyDarkness * 0.88
        );
    #endif

    #ifdef VIGNETTE
        block_color *= vignette(texcoord); // Vignette
    #endif

    #ifdef FAKE_BLOOM
        float threshold = 0.5; 
        block_color = fakeBloom(block_color, threshold); // Fake Bloom
    #endif
    
    #ifdef FILM_GRAIN
        float grainIntensity = GRAIN_FACTOR; 
        block_color = filmGrain(block_color, grainIntensity, texcoord); // Film grain
    #endif

    #ifdef COLOR_BLINDNESS
        block_color = color_blindness(block_color); // Color Blindness
    #endif

    // Final display-space quantization dither. A stable, zero-mean signal
    // smaller than one 8-bit code value removes visible gradient bands without
    // blur, extra texture samples, or temporal shimmer.
    #if !defined DEBUG_MODE && !defined PS1_LIKE
        vec3 quantizationDither = vec3(
            dither_makeup(gl_FragCoord.xy),
            dither_makeup(gl_FragCoord.xy + vec2(19.0, 7.0)),
            dither_makeup(gl_FragCoord.xy + vec2(43.0, 29.0))
        ) - vec3(0.5);
        block_color += quantizationDither * (1.0 / 255.0);
    #endif

    #ifdef DEBUG_MODE
        if(texcoord.x < 0.5 && texcoord.y < 0.5) {
            block_color = texture2D(shadowtex1, texcoord * 2.0).rrr;
        } else if(texcoord.x >= 0.5 && texcoord.y >= 0.5) {
            block_color = vec3(texture2D(gaux3, vec2(0.5)).r * 0.25);
        } else if(texcoord.x < 0.5 && texcoord.y >= 0.5) {
            block_color = texture2D(colortex1, ((texcoord - vec2(0.0, 0.5)) * 2.0)).rgb;
        } else if(texcoord.x >= 0.5 && texcoord.y < 0.5) {
            block_color = texture2D(shadowcolor0, ((texcoord - vec2(0.5, 0.0)) * 2.0)).rgb;
        } else {
            block_color = vec3(0.5);
        }

        gl_FragData[0] = vec4(block_color, 1.0);

    #else
        gl_FragData[0] = vec4(block_color, 1.0);
    #endif
}
