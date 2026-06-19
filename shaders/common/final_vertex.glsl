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

uniform sampler2D gaux3;

/* Ins / Outs */

varying vec2 texcoord;
varying float exposure;

#include "/lib/luma.glsl"
#include "/lib/fullscreen_vertex.glsl"

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    gl_Position = fullscreen_position(texcoord);

    exposure = texture2D(gaux3, vec2(0.5)).r;
}
