#version 120
/* Aurora Fantasy - gbuffers_weather.vsh
Render: Weather (The End)

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#include "/lib/config.glsl"

varying vec2 texUV;
varying vec4 color;

void main() {
    gl_Position = ftransform();
    color = gl_Color;
    texUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
}