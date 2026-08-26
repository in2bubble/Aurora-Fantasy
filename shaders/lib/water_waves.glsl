/* Aurora Fantasy - shared normal-water wave field.
 * Both real water and rain puddles use this exact five-band noisetex flow so
 * their motion, scale hierarchy, and weather response belong to one material
 * family.  The caller supplies time/weather/sky exposure to keep this library
 * usable in both the translucent-water and solid-terrain programs.
 */
#ifndef AURORA_SHARED_WATER_WAVES
#define AURORA_SHARED_WATER_WAVES

vec3 auroraWaterNormalWaves(vec3 pos, float waveTime,
                            float waveRainStrength,
                            float waveVisibleSky) {
    float angle1 = 0.698;
    float s1 = sin(angle1);
    float c1 = cos(angle1);
    mat2 rot1 = mat2(c1, -s1, s1, c1);

    float angle2 = 1.047;
    float s2 = sin(angle2);
    float c2 = cos(angle2);
    mat2 rot2 = mat2(c2, -s2, s2, c2);

    vec2 baseCoord = pos.xy - pos.z * 0.2;

    vec2 swellCoord = baseCoord * 0.06
        + vec2(waveTime * 0.025, waveTime * 0.018);
    vec2 wave1 = (texture2D(noisetex, swellCoord).rg - 0.5) * 0.8;

    vec2 crossCoord = rot1 * baseCoord * 0.09
        - vec2(waveTime * 0.03, waveTime * 0.012);
    vec2 wave2 = (texture2D(noisetex, crossCoord).rg - 0.5) * 0.65;

    vec2 rippleCoord = rot2 * baseCoord * 0.18
        + vec2(waveTime * 0.05, -waveTime * 0.035);
    vec2 wave3 = (texture2D(noisetex, rippleCoord).rg - 0.5) * 0.5;

    vec2 microCoord = baseCoord * 0.35
        + vec2(-waveTime * 0.07, waveTime * 0.04);
    vec2 wave4 = (texture2D(noisetex, microCoord).rg - 0.5) * 0.3;

    vec2 flowCoord = rot1 * baseCoord * 0.04
        + vec2(waveTime * 0.015, waveTime * 0.01);
    vec2 wave5 = (texture2D(noisetex, flowCoord).rg - 0.5) * 0.45;

    float rainRippleBoost = 1.0 + waveRainStrength * 1.5;
    float rainSwellDampen = 1.0
        - waveRainStrength * 0.3 * waveVisibleSky;
    vec2 partialWave = (wave1 + wave5) * rainSwellDampen
        + wave2 + (wave3 + wave4) * rainRippleBoost;

    return normalize(vec3(
        partialWave,
        WATER_TURBULENCE
            - waveRainStrength * 0.4 * WATER_TURBULENCE * waveVisibleSky));
}

#endif
