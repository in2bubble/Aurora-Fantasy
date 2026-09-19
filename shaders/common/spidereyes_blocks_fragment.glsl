#include "/lib/config.glsl"

/* Uniforms */

uniform sampler2D gtexture;

/* Ins / Outs */

varying vec2 texcoord;

// MAIN FUNCTION ------------------

void main() {
    // Toma el color puro del bloque
    vec4 block_color = texture2D(gtexture, texcoord);

    #include "/src/writebuffers.glsl"
}
