#version 120
/* Aurora Fantasy - gbuffers_weather.vsh
Render: Weather (Overworld)

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#include "/lib/config.glsl"

varying vec2 texUV;
varying vec4 color;
varying float viewDistance;
varying vec2 weatherWorldXZ;

void main() {
    vec4 viewVertex = gl_ModelViewMatrix * gl_Vertex;
    vec3 viewWind = normalize(mat3(gl_ModelViewMatrix)
        * normalize(vec3(0.82, 0.0, 0.57)));
    float gust = 0.86 + 0.14 * sin(
        persistentTimeSeconds * 0.72 + gl_Vertex.x * 0.041 + gl_Vertex.z * 0.033);
    viewVertex.xyz += viewWind * viewVertex.y * 0.115 * gust;

    gl_Position = gl_ProjectionMatrix * viewVertex;
    color = gl_Color;
    texUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    viewDistance = length(viewVertex.xyz);
    weatherWorldXZ = gl_Vertex.xz;
}
