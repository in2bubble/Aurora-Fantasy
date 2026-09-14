#include "/lib/config.glsl"

/* Uniforms */

uniform sampler2D tex;
uniform sampler2D noisetex;
varying vec3 worldPos;
uniform vec3 cameraPosition;
uniform float rainStrength;

/* Ins / Outs */

varying vec2 texcoord;
varying float is_noshadow;
varying float visible_sky;

varying float is_water;
varying float is_stained_glass;
varying vec4 shadow_tint;

#include "/lib/caustics.glsl"
#include "/lib/luma.glsl"

#define FRAGMENT
#include "/lib/downscale.glsl"

// MAIN FUNCTION ------------------

void main() {
  
    #ifndef CAUSTICS
        if (is_water > 0.98) {
            discard;
        }
    #endif

    if (is_noshadow > 0.98) {
        discard;
    }

    vec4 block_color;

    #ifdef CAUSTICS
        if (is_water > 0.98) {
            #if WATER_TEXTURE == 0
                vec3 wave_normal = normal_waves(worldPos + cameraPosition.xyz);
                vec3 amplified_normal = wave_normal * 4.0 * CAUSTICS_INTENSITY;
                block_color.rgb = clamp(v3_luma(amplified_normal), vec3(0.0), vec3(1.0)); 

                block_color.a = texture2D(tex, texcoord).a * 0.05 * clamp(amplified_normal.z, 0.0, 1.0) * (CAUSTICS_INTENSITY * 0.5 + 0.5);
            #else
                block_color = texture2D(tex, texcoord);
                block_color.rgb *= pow(block_color.rgb, vec3(3.0));
                if (block_color.r < 0.325) {
                    block_color.a *= 0.6;
                }
                block_color.a *= 0.66;
            #endif
            
        } else {
            block_color = texture2D(tex, texcoord);
        }
    #else
        block_color = texture2D(tex, texcoord);
    #endif

    #if defined COLORED_SHADOW && defined STAINED_GLASS_LIGHT
        if (is_stained_glass > 0.5) {
            // The shadow pass does not receive the translucent render-layer
            // blend state reliably on Minecraft 26.2. Write a deliberate
            // coloured transmission sample for stained glass instead.
            vec3 glassTint = max(block_color.rgb * shadow_tint.rgb, vec3(0.0));
            float strongestChannel = max(max(glassTint.r, glassTint.g), glassTint.b);
            glassTint /= max(strongestChannel, 0.001);
            block_color.rgb = mix(vec3(1.0), sqrt(glassTint), 0.92);
            block_color.a = 0.42;
        }
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = block_color;
}
