#version 120
/* Aurora Fantasy - gbuffers_weather.fsh
Render: Weather (Overworld)

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#include "/lib/config.glsl"

uniform sampler2D gtexture;
uniform int worldTime;

varying vec2 texUV;
varying vec4 color;

void main() {
    vec4 vanillaTex = texture2D(gtexture, texUV) * color;
    if (vanillaTex.a <= 0.03) discard;

    float wt = float(worldTime);
    float dayFactor       = smoothstep(12500.0, 10000.0, wt) * smoothstep(0.0, 2000.0, wt);
    float sunsetFactor    = smoothstep(10000.0, 11500.0, wt) * smoothstep(13500.0, 12000.0, wt);
    float nightFactor     = smoothstep(12500.0, 14500.0, wt) * smoothstep(23500.0, 22000.0, wt);
    float deepNightFactor = smoothstep(16000.0, 18000.0, wt) * smoothstep(22000.0, 20000.0, wt);

    vec3 dayCore   = vec3(0.48, 0.64, 0.90);
    vec3 dayEdge   = vec3(0.88, 0.93, 1.00);
    vec3 sunsetCore = vec3(0.60, 0.45, 0.35);
    vec3 sunsetEdge = vec3(0.90, 0.70, 0.55);
    vec3 nightCore  = vec3(0.18, 0.24, 0.42);
    vec3 nightEdge  = vec3(0.28, 0.35, 0.58);
    vec3 deepNightCore = vec3(0.08, 0.10, 0.20);
    vec3 deepNightEdge = vec3(0.14, 0.18, 0.32);

    vec3 blendCore = dayCore * dayFactor + sunsetCore * sunsetFactor + nightCore * nightFactor + deepNightCore * deepNightFactor;
    vec3 blendEdge = dayEdge * dayFactor + sunsetEdge * sunsetFactor + nightEdge * nightFactor + deepNightEdge * deepNightFactor;
    float totalFactor = max(dayFactor + sunsetFactor + nightFactor + deepNightFactor, 0.001);
    blendCore /= totalFactor;
    blendEdge /= totalFactor;

    vec2 localUV = fract(texUV * 4.0) - 0.5;
    float edgeFresnel = 1.0 - smoothstep(0.0, 0.25, abs(localUV.x));
    vec3 rainColor = mix(blendCore, blendEdge, edgeFresnel) * color.rgb * 1.8;

    float rainAlpha = vanillaTex.a * 0.45 * WEATHER_OPACITY;
    if (rainAlpha <= 0.005) discard;

    /* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(rainColor, rainAlpha);
}