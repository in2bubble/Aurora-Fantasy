#version 120
/* Aurora Fantasy - gbuffers_weather.fsh
   Render: Procedural Rain & Weather System
   Clean-room implementation designed natively for Aurora Fantasy.

   in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#include "/lib/config.glsl"
#include "/lib/color_utils.glsl"
#include "/lib/fantasy_rain.glsl"

uniform float rainStrength;

varying vec2 texUV;
varying vec4 color;
varying float viewDistance;
varying vec2 weatherWorldXZ;

void main() {
    // Aurora Fantasy native time-of-day color blending
    vec3 dayCore = vec3(0.38, 0.42, 0.46);
    vec3 sunsetCore = vec3(0.42, 0.38, 0.36);
    vec3 nightCore = vec3(0.24, 0.28, 0.34);
    vec3 rainCore = day_blend_color(dayCore, sunsetCore, nightCore);

    vec3 dayEdge = vec3(0.68, 0.72, 0.76);
    vec3 sunsetEdge = vec3(0.64, 0.58, 0.52);
    vec3 nightEdge = vec3(0.48, 0.52, 0.58);
    vec3 rainEdge = day_blend_color(dayEdge, sunsetEdge, nightEdge);

    float nightAmount = day_blend_float(0.0, 0.0, 1.0);
    float rainMask;
    float innerCore;
    float edgeHighlight;

    getFantasyRain(texUV, weatherWorldXZ, nightAmount,
        viewDistance, rainMask, innerCore, edgeHighlight);

    float vertexRainLuma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 neutralVertexTint = mix(vec3(vertexRainLuma), color.rgb, 0.20);
    vec3 rainColor = mix(rainCore, rainEdge, edgeHighlight * 0.30)
                   * mix(0.92, 1.08, innerCore)
                   * neutralVertexTint * 1.15;

    float rainAlpha = rainMask * (0.26 + innerCore * 0.12)
                    * WEATHER_OPACITY * mix(1.0, 1.10, nightAmount)
                    * color.a;

    if (rainAlpha <= 0.003) discard;

    /* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(rainColor, rainAlpha);
}
