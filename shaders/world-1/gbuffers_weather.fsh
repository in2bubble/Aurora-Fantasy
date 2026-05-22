#version 120
/* Aurora Fantasy - gbuffers_weather.fsh
Render: Weather (Nether)

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#include "/lib/config.glsl"

uniform sampler2D gtexture;

varying vec2 texUV;
varying vec4 color;

void main() {
    vec4 vanillaTex = texture2D(gtexture, texUV) * color;
    if (vanillaTex.a <= 0.03) discard;

    /* DRAWBUFFERS:1 */
    gl_FragData[0] = vanillaTex;
}