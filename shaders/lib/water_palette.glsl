/* Aurora Fantasy - shared time-aware water palette.
 * Real water and rain puddles must agree on their shallow/deep hue and on the
 * sunset/day/night transition. Lighting and transmission remain pass-specific.
 */
#ifndef AURORA_SHARED_WATER_PALETTE
#define AURORA_SHARED_WATER_PALETTE

vec3 auroraWaterTimeTint() {
    return day_blend(
        vec3(0.12, 0.08, 0.18),
        vec3(0.04, 0.15, 0.25),
        vec3(0.02, 0.06, 0.14));
}

vec3 auroraWaterBodyColor(float waterDepth) {
    vec3 shallowColor = vec3(0.06, 0.18, 0.28);
    vec3 deepColor = vec3(0.05, 0.04, 0.18);
    return mix(shallowColor, deepColor, clamp(waterDepth, 0.0, 1.0))
        + auroraWaterTimeTint() * 0.3;
}

vec3 auroraWaterPaletteHue(float waterDepth) {
    vec3 body = auroraWaterBodyColor(waterDepth);
    float bodyLuma = max(dot(body, vec3(0.2126, 0.7152, 0.0722)), 0.001);
    // Puddles use a restrained form of the real-water hue so shallow films do
    // not become opaque blue paint.
    return mix(vec3(1.0), body / bodyLuma, 0.46);
}

#endif
