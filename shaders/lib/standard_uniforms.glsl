/* Aurora Fantasy 5.4 - standard_uniforms.glsl
   Global standard OptiFine/Iris uniforms and version compatibility.
*/

#ifndef AURORA_STANDARD_UNIFORMS_GLSL
#define AURORA_STANDARD_UNIFORMS_GLSL

// View & Frame Dimensions (Centralized to prevent undefined variable errors)
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
uniform float frameTime;
uniform float frameTimeCounter;

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
