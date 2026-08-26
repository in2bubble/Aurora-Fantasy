#version 120
/* Aurora Fantasy - gbuffers_weather.fsh
Render: Weather (Overworld)

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#include "/lib/config.glsl"
#include "/lib/fantasy_rain.glsl"

uniform int worldTime;
uniform float rainStrength;
uniform vec3 fogColor;
uniform vec3 skyColor;

varying vec2 texUV;
varying vec4 color;
varying float viewDistance;
varying vec2 weatherWorldXZ;

void main() {
    float wt = mod(float(worldTime), 24000.0);
    float nightRainAmount = smoothstep(12500.0, 14500.0, wt)
                          * (1.0 - smoothstep(22000.0, 24000.0, wt));
    float rainMask;
    float innerCore;
    float edgeHighlight;
    getFantasyRain(texUV, weatherWorldXZ, nightRainAmount,
        viewDistance, rainMask, innerCore, edgeHighlight);

    // Use the atmosphere which is actually being rendered instead of a fixed
    // clock palette. Fog represents the horizon and skyColor the cloud/zenith
    // environment, so sunrise, overcast daylight and night inherit the right
    // hue automatically.
    vec3 environment = clamp(mix(fogColor, skyColor, 0.58),
                             vec3(0.012), vec3(1.0));
    float environmentLuma = dot(environment,
        vec3(0.2126, 0.7152, 0.0722));
    vec3 environmentTint = mix(vec3(environmentLuma), environment, 0.62);

    // A transparent cylindrical drop has a refracted core and a brighter
    // Fresnel rim. Swap the useful contrast according to scene luminance:
    // dark core over bright clouds, silver-blue core over the night sky.
    float brightBackdrop = smoothstep(0.30, 0.62, environmentLuma);
    vec3 darkRefracted = environmentTint * 0.40 + vec3(0.025, 0.032, 0.040);
    vec3 nightRefracted = mix(environmentTint,
                              vec3(0.34, 0.42, 0.52), 0.72);
    vec3 refractedCore = mix(nightRefracted, darkRefracted, brightBackdrop);

    vec3 dayReflection = mix(environmentTint,
                             vec3(0.68, 0.74, 0.80), 0.52);
    vec3 nightReflection = mix(environmentTint,
                               vec3(0.40, 0.49, 0.59), 0.62);
    vec3 reflectedEdge = mix(nightReflection, dayReflection,
        smoothstep(0.14, 0.54, environmentLuma));

    // Retain a trace of Minecraft's local weather tint without allowing the
    // vertex colour to darken the drop a second time.
    float vertexPeak = max(max(color.r, color.g), max(color.b, 0.001));
    vec3 vertexHue = color.rgb / vertexPeak;
    refractedCore *= mix(vec3(1.0), vertexHue, 0.08);
    reflectedEdge *= mix(vec3(1.0), vertexHue, 0.12);

    float rimResponse = clamp(edgeHighlight * 0.66, 0.0, 1.0);
    vec3 rainColor = mix(refractedCore, reflectedEdge, rimResponse);
    rainColor *= mix(0.94, 1.035, innerCore)
               * mix(1.0, 1.055, nightRainAmount);

    // Only a modest coverage increase over the original rain. Quantity still
    // reads clearly, while overlapping weather volumes no longer form a dense
    // white curtain.
    float opticalCoverage = 0.30 + innerCore * 0.115
                          + edgeHighlight * 0.075;
    float stormPresence = mix(0.84, 0.96,
        smoothstep(0.08, 0.80, rainStrength));
    // color.a is Minecraft's per-weather-card spatial fade. Restoring it is
    // what keeps rain inside the world instead of reading as a screen texture.
    float rainAlpha = rainMask * opticalCoverage * WEATHER_OPACITY
                    * stormPresence * mix(1.0, 1.06, nightRainAmount)
                    * color.a;
    if (rainAlpha <= 0.003) discard;

    /* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(rainColor, rainAlpha);
}
