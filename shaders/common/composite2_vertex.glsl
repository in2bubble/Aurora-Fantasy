#include "/lib/config.glsl"
#include "/lib/fullscreen_vertex.glsl"

/* Ins / Outs */

varying vec2 texcoord;

// MAIN FUNCTION ------------------

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    gl_Position = fullscreen_position(texcoord);
}
