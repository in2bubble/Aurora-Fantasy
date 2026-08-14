/* Aurora Fantasy 5.4.1 - standard_uniforms.glsl
   Global standard OptiFine/Iris uniforms and version compatibility.
*/

#ifndef AURORA_STANDARD_UNIFORMS_GLSL
#define AURORA_STANDARD_UNIFORMS_GLSL

// View & Frame Dimensions (Centralized to prevent undefined variable errors)
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
uniform float frameTime;

// World-backed animation clock: stable across F3+R and shader reloads.
// Minecraft advances at 20 ticks per second.
uniform float persistentWorldTicks;
#define persistentTimeSeconds (persistentWorldTicks * 0.05)

// Minecraft 1.19+ Darkness Effect Uniforms
#if MC_VERSION >= 11900
    uniform float darknessFactor;
    uniform float darknessLightFactor;
#else
    #define darknessFactor 0.0
    #define darknessLightFactor 0.0
#endif

// Screen size & render scale macros
#include "/lib/screen_size.glsl"

#endif // AURORA_STANDARD_UNIFORMS_GLSL
