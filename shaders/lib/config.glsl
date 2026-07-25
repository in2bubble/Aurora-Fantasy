/* Aurora Fantasy - config.glsl
Config variables (DO NOT DELETE ANY #define)

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_gpu_shader5 : enable

// Useful material properties.

// Plants, Leaves
#define ENTITY_SMALLGRASS   10031.0  // Normal grass like entities
#define ENTITY_LOWERGRASS   10175.0  // Lower half only
#define ENTITY_UPPERGRASS   10176.0  // Upper half only
#define ENTITY_SMALLENTS    10059.0  // Crops like entities
#define ENTITY_SMALLENTS_NW 10032.0  // No waveable small ents
#define ENTITY_LEAVES       10018.0  // Leaves
#define ENTITY_WHITE_LEAVES 10019.0  // White Leaves
#define ENTITY_VINES        10106.0  // Vines
#define ENTITY_FANTASY_FLOWERS 10510.0
#define ENTITY_FLOWERING_LEAVES 10511.0

// Emmisives
#define ENTITY_EMMISIVE     10089.0  // Emissors
#define ENTITY_S_EMMISIVE   10090.0  // Emissors
#define ENTITY_F_EMMISIVE    10213.0  // Fake emissors
#define ENTITY_NO_SHADOW_FIRE 10214.0  // Fire (no shadow)
#define ENTITY_PLAYER       10072.0  // Player (no shadow)
#define ENTITY_PORTAL       10091.0  // Portal

// Reflection
#define ENTITY_WATER        10008.0  // Water
#define ENTITY_STAINED      10079.0  // Glass
#define ENTITY_GLASS_WHITE  10080.0  // White glass
#define ENTITY_ICE          10078.0  // Ice

// Glossy
#define ENTITY_METAL        10400.0  // Metal-like glossy blocks
#define ENTITY_SAND         10410.0  // Sand-like glossy blocks
#define ENTITY_STONE        10411.0  // Stone-like glossy blocks
#define ENTITY_FABRIC       10440.0  // Fabric-like glossy blocks
#define ENTITY_POLISHED     10420.0  // Polished-like glossy blocks
#define ENTITY_ROUGH        10430.0  // Rough-like glossy blocks
#define ENTITY_CONCRETE     10450.0  // Concrete glossy blocks

// White glossy (to avoid peaks of brightness)
#define ENTITY_WHITE_POLISHED 10421.0  // White polished-like glossy blocks
#define ENTITY_WHITE          10415.0  // White blocks (to avoid peaks of brightness)

// Emissive ores
#define ENTITY_GOLD_ORE 9000.0
#define ENTITY_DIAMOND_ORE 9001.0
#define ENTITY_IRON_ORE 9002.0
#define ENTITY_EMERALD_ORE 9003.0
#define ENTITY_REDSTONE_ORE 9004.0
#define ENTITY_QUARTZ_ORE 9005.0
#define ENTITY_LAPIS_ORE 9006.0
#define ENTITY_COPPER_ORE 9007.0

// Emissive materials
#define ENTITY_EMMISIVE_REDSTONE 9008.0
#define ENTITY_SOLAR_PANEL 9009.0
#define ENTITY_CRYING_OBSIDIAN 9010.0
#define ENTITY_HIGHLIGHTS 9011.0
#define ENTITY_FIRE 9012.0
#define ENTITY_SCULK 9013.0
#define ENTITY_RAIL 9014.0
#define ENTITY_END_FRAME 9015.0

// Other constants
#define ZENITH_SKY_RAIN_COLOR vec3(0.7, 0.85, 1.0)
#define HORIZON_SKY_RAIN_COLOR vec3(0.35 , 0.425, 0.5)

// Style (Default or Vanilla)
#define STYLE 1 // [1 2]

// Options
#define TEXTURE_QUALITY 1 // [1 2] Resolution tier for Aurora's cloud and water detail textures.
#define AUX_BUFFER_QUALITY 1 // [1 2] Resolution tier for smooth auxiliary atmosphere buffers.
#define PROFILE_QUALITY 1 // [1 2] Internal profile tier: 1 keeps every effect with temporally stable balanced sampling; 2 preserves the original Extreme path.
#define REFLECTION_SLIDER 2 // [0 1 2] Reflection quality. - Flipped image: Inaccurate but quick reflection. - §a§lRaymarching§r: Raytraced Screen Space Reflection.

#if REFLECTION_SLIDER == 0
  #define REFLECTION 0
  #define SSR_TYPE 0
  #define REFLEX_INDEX 0.45
#elif REFLECTION_SLIDER == 1
  #define REFLECTION 1
  #define SSR_TYPE 0
  #define REFLEX_INDEX 0.7
#elif REFLECTION_SLIDER == 2
  #define REFLECTION 1
  #define SSR_TYPE 1
  #define REFLEX_INDEX 0.7
#endif

// Water SSR distributes its samples over the same useful exponential range,
// so higher profile values improve hit precision instead of marching farther
// beyond the scene. Puddle SSR has a separate budget below.
#define WATER_REFLECTION_STEPS 12 // [10 12 16 24 32] Water reflection ray samples.
#define RAYMARCH_STEPS WATER_REFLECTION_STEPS

// Optional compatibility for render-distance mods that do not expose the
// DISTANT_HORIZONS define. The internal DISTANT_RENDER_MOD flag is derived
// once below, which avoids Iris seeing two conflicting defaults for one option.
//#define DISTANT_RENDER_COMPAT

#define FOG_ACTIVE // Toggle fog
#define NETHER_FOG_DISTANCE 0 // [0 1] // Sets Nether fog distance to half of the render distance (maximum of 96 blocks)
#define ACERCADE 4 // [1 2 3 4 5 6 7]
#define WAVING 1 // [0 1] Makes objects like leaves or grass move in the wind (Low perfomance cost)
#define TINTED_WATER 1  // [0 1] Use the resource pack color for water.
#define AO 1  // [0 1] Turn on for enhanced ambient occlusion (Medium performance cost).
#define VANILLA_AO 1 // [0 1] Turn on for vanilla ambient occlusion (Faster than main AO).
#define REFRACTION 1  // [0 1] Activate refractions.
#define AOSTEPS 3.0 // [2.0 3.0 4.0 5.0 6.0 7.0 8.0 10.0] How many samples are taken for AO (High performance cost, Vanilla AO does not use it).
#define AO_STRENGTH 1.15 // [0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.66 0.70 0.75 0.80 0.85 0.90 0.95 1.0 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.0] Ambient occlusion strength (strength NOT affect performance).
#define AA_TYPE 3 // [0 1 2 3]  No: Disable antialiasing (not recommended). Denoise only: Supersampling is only used to eliminate noise. TAA: Enable antialiasing (Recommended). Sharp TAA: A subtle sharpening effect is used on the TAA. (Low-Medium perfomance cost)
//#define FXAA // Enables FXAA, very helpful especially on low resolutions.
//#define MOTION_BLUR // Turn on motion blur (Low perfomance cost)
#define MOTION_BLUR_STRENGTH 0.75 // [0.5 0.75 1.0 1.5 2.0 2.5 3.0 3.5 4.0] Set Motion blur strength. Lower framerate -> Lower strength and vice versa is recommended.
#define MOTION_BLUR_SAMPLES 4.0 // [2.0 3.0 4.0 5.0 6.0 7.0 8.0] Motion blur samples 
#define SUN_REFLECTION 2 // [0 1 2] Enable sun (or moon) reflection on water and glass (Very low perfomance cost)

// Feature switches used by the render graph and profiles. Keep every public
// option defined in this single configuration source so Iris can discover it.
#define SHADOW_ENTITIES // Allow entities to participate in the shadow pass.
#define CLOUD_REFLECTION // Reflect the volumetric cloud layer on water.
#define AURORA_REFLECTIONS // Reflect the sky aurora / northern lights on water and puddles.
#define END_CLOUDS // Render Aurora's cloud layer in the End.
#define BLOOM // Glow around bright scene energy.
#define BLOOM_SAMPLES 4.0 // [2.0 3.0 4.0 5.0 6.0 7.0 8.0 10.0 12.0 16.0] Bloom sample pairs.
#define BLOOM_STRENGTH 1.2 // [0.5 0.7 0.9 1.0 1.2 1.5 2.0] Bloom intensity.
//#define DOF // Enable depth of field; DOF_STRENGTH controls its radius.
#define DOF_STRENGTH 0 // [0 5 10 15 20 25 30] Depth-of-field radius; zero disables the pass.
#define VOL_LIGHT 2 // [0 1 2] Off, depth-based godrays, or shadow-aware volumetric light.
#define EMMISIVE_ORE // Let mapped ores emit light-colored material response.
#define EMMISIVE_MATERIAL // Let mapped luminous materials emit light.

#define SHADOW_TYPE 1 // [0 1] Sets the shadow type
#define SHADOW_BLUR 2.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.5 5.0]  Shadow blur intensity
#define SHADOW_SAMPLES 4 // [4 8 12 16] Rotated disk samples for soft and colored shadows.
#define COLORED_SHADOW // Attempts to tint the shadow of translucent objects.
#define WATER_ABSORPTION 0.035 // [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50] Sets how much light the water absorbs. Low levels make the water more transparent. High levels make it more opaque.
#define WATER_FOG 3.0 // [0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 10.5 11.0 11.5 12.0 12.5 13.0 13.5 14.0 14.5 15.0 15.5 16.0 16.5 17.0 17.5 18.0 18.5 19.0 19.5 20.0 20.5 21.0 21.5 22.0 22.5 23.0 23.5 24.0 24.5 25.0 25.5 26.0 26.5 27.0 27.5 28.0 28.5 29.0 29.5 30.0 30.5 31.0 31.5 32.0 32.5 33.0 33.5 34.0 34.5 35.0 35.5 36.0 36.5 37.0 37.5 38.0 38.5 39.0 39.5 40.0]
#define COLOR_SCHEME 8 // [0 1 2 3 4 5 6 7 8 9 10 11 12 99] Ethereal: Old default theme. New shoka: Reinterpretation of a classic. Shoka: The classic. Legacy: Very old default. Captain: A cold preset of stylish colors. Psycodelic: Remaster of old vivid scheme. Cocoa: Warm theme. Realistic+: Realistic sky colors. Realistic (pol): Realistic but simulates pollution. Vanilla: Vanilla colors. Aurora Legacy: Aurora 1.0 colors. Custom: Choose your colors in effects.
#define USE_WATER_TEXTURE -1 // [-1 0 1] Enable or disable resource pack water texture. It does not work properly in 1.12. In that case the default value is recommended.
#define CAUSTICS // Optional water caustics in the shadow map.
#define CAUSTICS_INTENSITY 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#if USE_WATER_TEXTURE == -1
  #if STYLE == 1
    #define WATER_TEXTURE 0 
  #elif STYLE == 2
    #define WATER_TEXTURE 1
  #endif
#elif USE_WATER_TEXTURE == 0
  #define WATER_TEXTURE 0 
#elif USE_WATER_TEXTURE == 1
  #define WATER_TEXTURE 1 
#endif

#define AVOID_DARK_LEVEL 4.5 // [0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 10.5 11.0 11.5 12.0 12.5 50.0]  Minimal light intensity (Percentage).
#define NIGHT_BRIGHT 0.72 // [0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.72 0.75 0.80 0.82 0.85] Adjusts the brightness of the night light in exteriors.
#define NIGHT_BRIGHT_RANGE 0.60 // [0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20] Difference between min and max values.
#define NIGHT_NEUTRAL_FILL 0.016 // [0.0 0.004 0.008 0.012 0.016 0.020 0.024] Neutral outdoor night fill that raises visibility without tinting block colours.
#define V_CLOUDS 2 // [-1 0 1 2] Volumetric static: The clouds move, but they keep their shape. Volumetric dynamic: Clouds change shape over time, a different cloud landscape every time (medium performance hit). Vanilla: Original vanilla clouds.
#define CIRRUS // Adds a 2nd layer of cirrus clouds in the sky.
#define USE_CLOUD_VOL_STYLE -1 // [-1 0 1] Set the volumetric cloud style.
#define CLOUD_DENSITY 1.0 // [0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8]

#if USE_CLOUD_VOL_STYLE == -1
  #if STYLE == 1
    #define CLOUD_VOL_STYLE 0
  #elif STYLE == 2
    #define CLOUD_VOL_STYLE 1
  #endif
#elif USE_CLOUD_VOL_STYLE == 0
  #define CLOUD_VOL_STYLE 0
#elif USE_CLOUD_VOL_STYLE == 1
  #define CLOUD_VOL_STYLE 1
#endif

#define USE_WATER_TURBULENCE 2 // [0 1 2 3] Flat, gentle, natural, or strong waves.

#if USE_WATER_TURBULENCE == 0
  #define WATER_TURBULENCE 32.0
#elif USE_WATER_TURBULENCE == 1
  #define WATER_TURBULENCE 1.75
#elif USE_WATER_TURBULENCE == 2
  #define WATER_TURBULENCE 0.9
#elif USE_WATER_TURBULENCE == 3
  #define WATER_TURBULENCE 0.5
#endif

#define FOG_ADJUST 2.0 // [10.0 8.0 4.0 2.0 1.5 1.0]  Sets the fog strength

// #define DEBUG_MODE // Set debug mode.
#define BLOCKLIGHT_TEMP 1 // [-1 0 1 2 3 4 5] Set blocklight temperature

// Aurora Fantasy Options
#define FANTASY_LIFE_SYSTEM // Master switch for fireflies, illuminated flora, canopy lights, and player interaction.
#define FANTASY_LIFE_QUALITY 3 // [1 2 3 4] Profile-controlled detail level for the enchanted life system.
#define FANTASY_FIREFLIES 2 // [0 1 2 3 4] Volumetric firefly detail (0: Off, 1: Low, 2: Medium, 3: High, 4: Extreme).
#define FANTASY_NIGHT_FLORA // Subtle world-space flower and foliage bioluminescence at night.
#define MATERIAL_GLOSS // A effect that adds some ability to reflect direct light on some blocks. It is most noticeable on metals and luminous objects. (Low-Medium perfomance cost)
// #define SIMPLE_AUTOEXP // Turns off automatic exposure.
#define DYN_HAND_LIGHT // Toggle the fake dynamic light

// Rain Puddles & Wet Surfaces
#define RAIN_PUDDLES // One UI master switch: rain puddles, wet-ground film, waves, rain rings, environment reflection and puddle SSR. Off removes the entire rainy-ground system.
#define SSR_MAX_STEPS 16 // [4 8 10 12 16 24 32 64] Number of ray-march steps for SSR.
#define SSR_STEP_SIZE 1.2 // [0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0] Step size multiplier for SSR ray-march.
#define SSR_BINARY_STEPS 4 // [2 4 6 8 10] Binary refinement steps for SSR hit precision.
#define SSR_STRENGTH 10 // [1 2 3 4 5 6 7 8 9 10] Overall SSR reflection intensity.

// Weather (Rain particles)
#define WEATHER_OPACITY 0.35 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0] Rain drop opacity.

// Water Edge Foam
#define WATER_FOAM // Enable white foam at water edges where water meets solid blocks.
#define FOAM_WIDTH 2.0 // [0.5 1.0 1.5 2.0 2.5 3.0 4.0 5.0] Width of foam shoreline band.
#define FOAM_BRIGHTNESS 1.0 // [0.2 0.4 0.6 0.8 1.0 1.2 1.5 2.0] Brightness intensity of foam.

// Biome Colors & Sandstorms
#define BIOME_SKY // Dynamically blend sky colors based on biome temperature and rainfall.
#define BIOME_FOG // Adapt fog density and color according to current biome.
#define SANDSTORM // Procedural dust & sand particles in desert biomes.

// Stars
#define STAR_SLIDER 2 // [0 1 2] 0: Off, 1: Vanilla stars, 2: High density fantasy stars
#define STARS_BRIGHTNESS 1.2 // [0.2 0.4 0.6 0.8 1.0 1.2 1.5 2.0] Star brightness
#define STARS_COVERAGE 1.0 // [0.2 0.5 0.8 1.0 1.2 1.5 2.0] Star density/coverage
#define END_STARS // Draw custom stars in the End dimension

// Night Vision & Darkness Effect
#define NIGHT_VISION_BOOST 1.0 // [0.0 0.5 1.0 1.5 2.0] Intensity of vanilla Night Vision potion effect
#define DARKNESS_EFFECT // Support MC 1.19+ Warden darkness effect

// Performance & Quality
#define WAVING_SPEED 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0] Speed of waving foliage
#define WIND_FORCE 1.0 // [0.0 0.5 0.75 1.0 1.25 1.5 2.0] Wind force strength
#define SHARP_FORCE 0.95 // [0.0 0.5 0.75 0.8 0.95 1.0 1.2 1.5] Sharpening strength
#define CHROMA_ABER_STRENGTH 1.0 // Chromatic aberration strength

// Camera & Tonemapping Defaults
#define TONEMAPPING 1 // [0 1 2 3]
#define SATURATION 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define CONTRAST 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define BRIGHTNESS 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define GAMMA 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define VIBRANCE 1.0 // [0.0 0.5 0.75 1.0 1.25 1.5]
#define EXPOSURE 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]

// Custom Color Defaults
#define LIGHT_DAY_COLOR_R 0.90 // [0.0 0.25 0.5 0.75 0.90 1.0 1.25 1.5]
#define LIGHT_DAY_COLOR_G 0.84 // [0.0 0.25 0.5 0.75 0.84 1.0 1.25 1.5]
#define LIGHT_DAY_COLOR_B 0.79 // [0.0 0.25 0.5 0.75 0.79 1.0 1.25 1.5]
#define ZENITH_DAY_COLOR_R 0.08 // [0.0 0.04 0.08 0.12 0.2 0.3 0.5 0.75 1.0]
#define ZENITH_DAY_COLOR_G 0.24 // [0.0 0.08 0.16 0.24 0.32 0.5 0.75 1.0]
#define ZENITH_DAY_COLOR_B 0.55 // [0.0 0.25 0.4 0.55 0.7 0.85 1.0 1.25 1.5]
#define HORIZON_DAY_COLOR_R 0.65 // [0.0 0.25 0.5 0.65 0.75 1.0 1.25 1.5]
#define HORIZON_DAY_COLOR_G 0.91 // [0.0 0.25 0.5 0.75 0.91 1.0 1.25 1.5]
#define HORIZON_DAY_COLOR_B 1.30 // [0.0 0.5 0.75 1.0 1.15 1.30 1.5 2.0]

#define LIGHT_SUNSET_COLOR_R 0.88 // [0.0 0.25 0.5 0.75 0.88 1.0 1.25 1.5]
#define LIGHT_SUNSET_COLOR_G 0.44 // [0.0 0.2 0.3 0.44 0.6 0.8 1.0 1.25]
#define LIGHT_SUNSET_COLOR_B 0.30 // [0.0 0.1 0.2 0.30 0.4 0.6 0.8 1.0]
#define ZENITH_SUNSET_COLOR_R 0.26 // [0.0 0.1 0.2 0.26 0.4 0.6 0.8 1.0]
#define ZENITH_SUNSET_COLOR_G 0.33 // [0.0 0.1 0.2 0.33 0.5 0.7 0.85 1.0]
#define ZENITH_SUNSET_COLOR_B 0.52 // [0.0 0.25 0.4 0.52 0.7 0.85 1.0 1.25]
#define HORIZON_SUNSET_COLOR_R 1.00 // [0.0 0.25 0.5 0.75 1.00 1.25 1.5 2.0]
#define HORIZON_SUNSET_COLOR_G 0.60 // [0.0 0.2 0.4 0.60 0.8 1.0 1.25 1.5]
#define HORIZON_SUNSET_COLOR_B 0.39 // [0.0 0.1 0.2 0.39 0.5 0.7 0.85 1.0]

#define LIGHT_NIGHT_COLOR_R 0.03 // [0.0 0.01 0.02 0.03 0.04 0.06 0.08 0.1]
#define LIGHT_NIGHT_COLOR_G 0.04 // [0.0 0.01 0.02 0.03 0.04 0.06 0.08 0.1]
#define LIGHT_NIGHT_COLOR_B 0.06 // [0.0 0.01 0.02 0.04 0.06 0.08 0.1 0.15]
#define ZENITH_NIGHT_COLOR_R 0.01 // [0.0 0.005 0.01 0.02 0.03 0.04 0.06 0.08]
#define ZENITH_NIGHT_COLOR_G 0.02 // [0.0 0.005 0.01 0.02 0.03 0.04 0.06 0.08]
#define ZENITH_NIGHT_COLOR_B 0.03 // [0.0 0.01 0.02 0.03 0.04 0.06 0.08 0.1]
#define HORIZON_NIGHT_COLOR_R 0.025 // [0.0 0.01 0.02 0.025 0.04 0.06 0.08 0.1]
#define HORIZON_NIGHT_COLOR_G 0.037 // [0.0 0.01 0.02 0.037 0.05 0.07 0.1 0.15]
#define HORIZON_NIGHT_COLOR_B 0.052 // [0.0 0.01 0.03 0.052 0.07 0.1 0.15 0.2]

#define WATER_COLOR_R 0.05 // [0.0 0.025 0.05 0.075 0.1 0.15 0.2 0.3]
#define WATER_COLOR_G 0.10 // [0.0 0.05 0.10 0.15 0.2 0.3 0.4 0.5]
#define WATER_COLOR_B 0.11 // [0.0 0.05 0.08 0.11 0.15 0.2 0.3 0.5]

#define RED 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define GREEN 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define BLUE 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define OMNI_TINT_CUSTOM 0.4

// Night Vision Potion Tint Defaults
#define NV_COLOR_R 0.0
#define NV_COLOR_G 0.6
#define NV_COLOR_B 0.2

// Underwater
#define UNDERWATER_DISTORTION 1.0 // [0.0 0.25 0.5 0.75 1.0 1.5 2.0] Distortion strength when eye is in water

// World Time & Sun position
#define DYN_WORLD_TIME // Automatic sky transition based on world time

// Iris discovers boolean pack options from direct preprocessor guards. These
// guards are option bindings (not runtime compatibility branches); the actual
// feature code remains in the render stage that owns each effect.
#ifdef DISTANT_RENDER_COMPAT
#endif
#ifdef SHADOW_ENTITIES
#endif
#ifdef CLOUD_REFLECTION
#endif
#ifdef END_CLOUDS
#endif
#ifdef BLOOM
#endif
#ifdef DOF
#endif
#ifdef EMMISIVE_ORE
#endif
#ifdef EMMISIVE_MATERIAL
#endif
#ifdef FANTASY_LIFE_SYSTEM
#endif
#ifdef FANTASY_NIGHT_FLORA
#endif
#ifdef BIOME_FOG
#endif
#ifdef END_STARS
#endif

#if defined DISTANT_HORIZONS || defined DISTANT_RENDER_COMPAT
  #define DISTANT_RENDER_MOD
#endif

// Shader internal definitions
#ifdef GBUFFER_TERRAIN
  #define TERRAIN_PASS
#endif

#ifdef GBUFFER_WATER
  #define WATER_PASS
#endif

#ifdef GBUFFER_ENTITIES
  #define ENTITY_PASS
#endif

#ifdef GBUFFER_BLOCK
  #define BLOCK_PASS
#endif

#ifdef DEFERRED_SHADER
  #define DEFERRED_PASS
#endif

#ifdef COMPOSITE_SHADER
  #define COMPOSITE_PASS
#endif

#ifdef FINAL_SHADER
  #define FINAL_PASS
#endif

// Performance optimization flags
#define FRAGMENT_CULLING // Cull off-screen fragments early

#ifndef RENDER_SCALE
  #define RENDER_SCALE 1.0
#endif

// Standard OptiFine/Iris Uniforms & Screen Size
#include "/lib/standard_uniforms.glsl"

// Compatibility defines
#ifdef RAIN_PUDDLES
  #define PUDDLES_ACTIVE
#endif

// Nether visibility distance used by the fog and deferred AO passes.
#if NETHER_FOG_DISTANCE == 1
  #define NETHER_SIGHT min(far * 0.5, 96.0)
#else
  #define NETHER_SIGHT far
#endif

// Cloud parameters
#if CLOUD_VOL_STYLE == 1  // Boxy
  #ifdef THE_END
    #define CLOUD_PLANE_SUP 250.0
    #define CLOUD_PLANE_CENTER 235.0
    #define CLOUD_PLANE 219.0
  #else
    #define CLOUD_PLANE_SUP 330.0
    #define CLOUD_PLANE 270.0
    #define CLOUD_PLANE_CENTER (CLOUD_PLANE_SUP + CLOUD_PLANE) / 2
  #endif
#else  // Volumetric
  #ifdef THE_END
    #define CLOUD_PLANE_SUP 450.0
    #define CLOUD_PLANE_CENTER 305.0
    #define CLOUD_PLANE 219.0
  #else
    #define CLOUD_PLANE_SUP 590.0
    #define CLOUD_PLANE_CENTER 375.0
    #define CLOUD_PLANE 319.0
  #endif
#endif

#define CLOUD_STEPS_AVG 12 // [3 4 5 6 8 10 12 16] Samples per pixel (High perfomance cost).
#define CIRRUS_STEPS_AVG 8 // [3 4 5 6 8 10 12] Samples per pixel for cirrus. (Medium perfomance cost).
#define CLOUD_SPEED 0 // [0 1 2] Change the speed of clouds for demo purposes.

#if CLOUD_VOL_STYLE == 1
  #if CLOUD_SPEED == 0
    #define CLOUD_HI_FACTOR 0.001388888888888889
    #define CLOUD_LOW_FACTOR 0.0002777777777777778
  #elif CLOUD_SPEED == 1
    #define CLOUD_HI_FACTOR 0.01388888888888889
    #define CLOUD_LOW_FACTOR 0.002777777777777778
  #elif CLOUD_SPEED == 2
    #define CLOUD_HI_FACTOR 0.1388888888888889
    #define CLOUD_LOW_FACTOR 0.02777777777777778
  #endif
#else
  #if CLOUD_SPEED == 0
    #define CLOUD_HI_FACTOR 0.0016666666666666666
    #define CLOUD_LOW_FACTOR 0.0002777777777777778
  #elif CLOUD_SPEED == 1
    #define CLOUD_HI_FACTOR 0.016666666666666666
    #define CLOUD_LOW_FACTOR 0.002777777777777778
  #elif CLOUD_SPEED == 2
    #define CLOUD_HI_FACTOR 0.16666666666666666
    #define CLOUD_LOW_FACTOR 0.02777777777777778
  #endif
#endif

// Godrays
#define GODRAY_STEPS 4 // [2 3 4 5 6 7]
#define CHEAP_GODRAY_SAMPLES clamp((GODRAY_STEPS / 1.5), 2.0, 7.0)

// Color blindness
#define COLOR_BLIND_MODE 0  // [0 1 2]  Set color blindness type
#define CB_STRENGTH 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0] Set color blindness strength

// Sun rotation angle
const float sunPathRotation = -40.0; // [-80.0 -75.0 -70.0 -65.0 -60.0 -55.0 -50.0 -45.0 -40.0 -35.0 -30.0 -25.0 -22.5 -20.0 -15.0 -10.0 -5.0 0.0 5.0 10.0 15.0 20.0 22.5 25.0 30.0 35.0 40.0 45.0 50.0 55.0 60.0 65.0 70.0 75.0 80.0]

#define SHADOW_DISTANCE_SLIDER 4 // [1 2 3 4 5 6 7 8]
#define SHADOW_QTY_SLIDER 3 // [1 2 3 4 5 6 7 8]

#define SHADOW_CASTING // Enable or disable shadows. Configure quality in advanced options. (Very low - Very High perfomance cost)
#define OMNI_MUL 0.35 // [0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95]

#define SUN_MUL 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define MOON_MUL 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define ASTRO_POWER 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#ifdef SHADOW_CASTING
  const float shadowIntervalSize = 3.0;

  const bool shadowtex0Mipmap = false;
  const bool shadowtex1Mipmap = false;
  const bool shadowColor0Mipmap = false;
  const bool shadowColor1Mipmap = false;

  const bool shadowtex0Clear = false;
  const bool shadowtex1Clear = false;
  const bool shadowcolor0Clear = false;
  const bool shadowcolor1Clear = false;

  #ifndef NO_SHADOWS
  #if SHADOW_DISTANCE_SLIDER == 1
      const float shadowDistance = 64.0;
      #define SHADOW_LIMIT 64.0
  #elif SHADOW_DISTANCE_SLIDER == 2
      const float shadowDistance = 80.0;
      #define SHADOW_LIMIT 80.0
  #elif SHADOW_DISTANCE_SLIDER == 3
      const float shadowDistance = 96.0;
      #define SHADOW_LIMIT 96.0
  #elif SHADOW_DISTANCE_SLIDER == 4
      const float shadowDistance = 128.0;
      #define SHADOW_LIMIT 128.0
  #elif SHADOW_DISTANCE_SLIDER == 5
      const float shadowDistance = 160.0;
      #define SHADOW_LIMIT 160.0
  #elif SHADOW_DISTANCE_SLIDER == 6
      const float shadowDistance = 192.0;
      #define SHADOW_LIMIT 192.0
  #elif SHADOW_DISTANCE_SLIDER == 7
      const float shadowDistance = 224.0;
      #define SHADOW_LIMIT 224.0
  #elif SHADOW_DISTANCE_SLIDER == 8
      const float shadowDistance = 256.0;
      #define SHADOW_LIMIT 256.0
  #else
      const float shadowDistance = 128.0;
      #define SHADOW_LIMIT 128.0
  #endif

  #if SHADOW_QTY_SLIDER == 1
    const int shadowMapResolution = 512;
    #define SHADOW_FIX_FACTOR 0.3
    #define SHADOW_DIST 0.75
  #elif SHADOW_QTY_SLIDER == 2
    const int shadowMapResolution = 1024;
    #define SHADOW_FIX_FACTOR 0.25
    #define SHADOW_DIST 0.8
  #elif SHADOW_QTY_SLIDER == 3
    const int shadowMapResolution = 1536;
    #define SHADOW_FIX_FACTOR 0.2
    #define SHADOW_DIST 0.85
  #elif SHADOW_QTY_SLIDER == 4
    const int shadowMapResolution = 2048;
    #define SHADOW_FIX_FACTOR 0.15
    #define SHADOW_DIST 0.865
  #elif SHADOW_QTY_SLIDER == 5
    const int shadowMapResolution = 3072;
    #define SHADOW_FIX_FACTOR 0.10
    #define SHADOW_DIST 0.88
  #elif SHADOW_QTY_SLIDER == 6
    const int shadowMapResolution = 4096;
    #define SHADOW_FIX_FACTOR 0.05
    #define SHADOW_DIST 0.9
  #elif SHADOW_QTY_SLIDER == 7
    const int shadowMapResolution = 6144;
    #define SHADOW_FIX_FACTOR 0.03
    #define SHADOW_DIST 0.92
  #elif SHADOW_QTY_SLIDER == 8
    const int shadowMapResolution = 8192;
    #define SHADOW_FIX_FACTOR 0.02
    #define SHADOW_DIST 0.94
  #else
    const int shadowMapResolution = 2048;
    #define SHADOW_FIX_FACTOR 0.15
    #define SHADOW_DIST 0.865
  #endif
  
  const float shadowDistanceRenderMul = 1.0;
  const bool shadowHardwareFiltering = true;
  const bool shadowtex1Nearest = false;
  #endif
#else
  #define SHADOW_DIST 0.0
  #define SHADOW_RES 0
  const int shadowMapResolution = 10;
  const float shadowDistance = 6.0;
#endif

#if VANILLA_AO == 1
  uniform float ambientOcclusionLevel = AO_STRENGTH;
#else
  const float ambientOcclusionLevel = 0.0;
#endif

const float eyeBrightnessHalflife = 6.0;
const float wetnessHalflife = 00.0;
const float centerDepthHalflife = 0.66;

#if BLOCKLIGHT_TEMP == -1
    #define CANDLE_BASELIGHT vec3(0.4, 0.15, 0.08)
#elif BLOCKLIGHT_TEMP == 0
    #define CANDLE_BASELIGHT vec3(0.0039, 0.0039, 0.0039)
#elif BLOCKLIGHT_TEMP == 1
    #define CANDLE_BASELIGHT vec3(0.2745, 0.16, 0.14)
#elif BLOCKLIGHT_TEMP == 2
    #define CANDLE_BASELIGHT vec3(0.24975, 0.19392353, 0.0999)
#elif BLOCKLIGHT_TEMP == 3
    #define CANDLE_BASELIGHT vec3(0.22, 0.19, 0.14)
#elif BLOCKLIGHT_TEMP == 4
    #define CANDLE_BASELIGHT vec3(0.19, 0.19, 0.19)
#elif BLOCKLIGHT_TEMP == 5
    #define CANDLE_BASELIGHT vec3(0.19, 0.19, 0.29)
#endif

#define TRANSITION_DH_SUP 0.05
#define TRANSITION_DH_INF 0.75
