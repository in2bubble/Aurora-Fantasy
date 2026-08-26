#version 120
/* Aurora Fantasy - gbuffers_weather.vsh
Render: Weather (Overworld)

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#include "/lib/config.glsl"

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

varying vec2 texUV;
varying vec4 color;
varying float viewDistance;
varying vec2 weatherWorldXZ;

void main() {
    vec4 viewVertex = gl_ModelViewMatrix * gl_Vertex;

    // Recover camera-relative world height before applying wind. Using the
    // view-space Y coordinate made the shear vanish when the camera looked
    // upward, leaving perfectly radial/straight weather cards.
    vec3 relativeWorld = mat3(gbufferModelViewInverse) * viewVertex.xyz;
    float heightFromCamera = relativeWorld.y;

    float slowVeer = sin(persistentTimeSeconds * 0.071) * 0.18
                   + sin(persistentTimeSeconds * 0.029 + 1.7) * 0.09;
    vec3 worldWind = normalize(vec3(0.82 + slowVeer, 0.0,
                                    0.57 - slowVeer * 0.72));
    vec3 viewWind = normalize(mat3(gl_ModelViewMatrix) * worldWind);
    float localGust = sin(persistentTimeSeconds * 0.61
        + gl_Vertex.x * 0.041 + gl_Vertex.z * 0.033) * 0.5 + 0.5;
    float windEvent = smoothstep(0.28, 0.86,
        sin(persistentTimeSeconds * 0.117 + 0.9) * 0.5 + 0.5);
    float shearStrength = mix(0.115, 0.185, windEvent)
                        * mix(0.78, 1.16, localGust);
    viewVertex.xyz += viewWind * heightFromCamera * shearStrength;

    gl_Position = gl_ProjectionMatrix * viewVertex;
    color = gl_Color;
    texUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    viewDistance = length(viewVertex.xyz);
    weatherWorldXZ = relativeWorld.xz + cameraPosition.xz;
}
