#version 120
/* Aurora Fantasy - gbuffers_weather.fsh
Render: Weather (Overworld)

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#include "/lib/config.glsl"
#include "/lib/fantasy_rain.glsl"

uniform sampler2D gtexture;
uniform int worldTime;
uniform float rainStrength;

varying vec2 texUV;
varying vec4 color;
varying float viewDistance;
varying vec2 weatherWorldXZ;

void main() {
    vec4 vanillaTex = texture2D(gtexture, texUV) * color;

    float wt = float(worldTime);
    float dayFactor       = max(1.0 - smoothstep(10000.0, 12500.0, wt),
                                smoothstep(23000.0, 24000.0, wt));
    float sunsetFactor    = smoothstep(10000.0, 11500.0, wt)
                          * (1.0 - smoothstep(12500.0, 14000.0, wt));
    float nightFactor     = smoothstep(12500.0, 14500.0, wt)
                          * (1.0 - smoothstep(22000.0, 24000.0, wt));
    float deepNightFactor = smoothstep(16000.0, 18000.0, wt)
                          * (1.0 - smoothstep(20000.0, 22000.0, wt));

    vec3 dayCore   = vec3(0.38, 0.40, 0.42);
    vec3 dayEdge   = vec3(0.66, 0.68, 0.70);
    vec3 sunsetCore = vec3(0.40, 0.38, 0.36);
    vec3 sunsetEdge = vec3(0.60, 0.58, 0.55);
    vec3 nightCore  = vec3(0.28, 0.30, 0.34);
    vec3 nightEdge  = vec3(0.52, 0.55, 0.60);
    vec3 deepNightCore = vec3(0.24, 0.26, 0.30);
    vec3 deepNightEdge = vec3(0.45, 0.48, 0.54);

    vec3 blendCore = dayCore * dayFactor + sunsetCore * sunsetFactor + nightCore * nightFactor + deepNightCore * deepNightFactor;
    vec3 blendEdge = dayEdge * dayFactor + sunsetEdge * sunsetFactor + nightEdge * nightFactor + deepNightEdge * deepNightFactor;
    float totalFactor = max(dayFactor + sunsetFactor + nightFactor + deepNightFactor, 0.001);
    blendCore /= totalFactor;
    blendEdge /= totalFactor;

    float nightRainAmount = clamp(nightFactor + deepNightFactor, 0.0, 1.0);
    float rainMask;
    float innerCore;
    float edgeHighlight;
    getFantasyRain(texUV, weatherWorldXZ, nightRainAmount,
        viewDistance, vanillaTex.a,
        rainMask, innerCore, edgeHighlight);

    float vertexRainLuma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 neutralVertexTint = mix(
        vec3(vertexRainLuma), color.rgb, 0.18);
    vec3 rainColor = mix(blendCore, blendEdge, edgeHighlight * 0.28)
                   * mix(0.90, 1.06, innerCore)
                   * neutralVertexTint * 1.12;

    float rainAlpha = rainMask * (0.26 + innerCore * 0.12)
                    * WEATHER_OPACITY * mix(1.0, 1.08, nightRainAmount);
    if (rainAlpha <= 0.003) discard;

    /* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(rainColor, rainAlpha);
}
