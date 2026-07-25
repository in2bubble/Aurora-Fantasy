/* Aurora Fantasy - Procedural Rain Streaks
 * Dense, softly tapered rain independent of vanilla texture coverage.
 */
#ifndef AURORA_FANTASY_RAIN
#define AURORA_FANTASY_RAIN

float fantasyRainStreak(vec2 uv, float columns, float rows, float phase,
                        float width, out float core, out float edge) {
    float columnId = floor(uv.x * columns);
    float variation = fract(sin((columnId + phase * 19.17) * 12.9898)
                            * 43758.5453);

    // The geometry supplies the broad wind angle; this smaller local shear
    // keeps individual drops from sharing one perfectly straight trajectory.
    float localX = fract(uv.x * columns
                       + uv.y * mix(0.10, 0.22, variation) + phase) - 0.5;
    float localY = fract(uv.y * rows + columnId * 0.381966 + phase * 1.73);

    float capIn = smoothstep(0.025, 0.16, localY);
    float capOutStart = mix(0.38, 0.58, variation);
    float capOut = 1.0 - smoothstep(capOutStart, capOutStart + 0.25, localY);
    float longitudinal = capIn * capOut;

    float variedWidth = width * mix(0.72, 1.15, variation);
    float taper = mix(variedWidth * 0.38, variedWidth,
                      smoothstep(0.02, 0.50, localY));
    float lateral = abs(localX);
    float body = 1.0 - smoothstep(taper * 0.38, taper, lateral);

    core = (1.0 - smoothstep(0.0, taper * 0.31, lateral)) * longitudinal;
    edge = smoothstep(taper * 0.26, taper * 0.68, lateral)
         * (1.0 - smoothstep(taper * 0.68, taper, lateral))
         * longitudinal;
    return body * longitudinal * mix(0.68, 1.0, variation);
}

void getFantasyRain(vec2 texUV, vec2 worldXZ, float nightAmount,
                    float viewDistance,
                    float sourceAlpha, out float rainMask,
                    out float coreMask, out float edgeMask) {
    // World phase breaks the identical texture repetition between Minecraft's
    // many weather columns while remaining stable as the camera moves.
    float worldPhase = fract(dot(worldXZ, vec2(0.0317, 0.0473)));

    float coreA;
    float edgeA;
    float primary = fantasyRainStreak(
        texUV + vec2(worldPhase, worldPhase * 0.21),
        2.0, 1.55, 0.13, 0.074, coreA, edgeA);

    float coreB;
    float edgeB;
    float secondary = fantasyRainStreak(
        texUV + vec2(0.37 - worldPhase * 0.43, 0.19),
        2.0, 2.35, 0.57, 0.058,
        coreB, edgeB);

    // The source texture guarantees a visible but softly feathered base
    // rainfall. Procedural streaks add shape variation instead of acting as a
    // second mandatory mask (which previously erased almost every drop).
    float sourceBody = smoothstep(0.008, 0.30, sourceAlpha);
    sourceBody *= mix(0.62, 0.90, clamp(sourceAlpha * 2.0, 0.0, 1.0));
    float secondaryWeight = mix(0.40, 0.46, nightAmount);

    // Four varied streaks per weather volume are dense enough to read as real
    // rainfall, but far below the former 33-line curtain. Neither procedural
    // layer depends on the vanilla alpha, so the rain cannot disappear again.
    float shapedRain = primary * 0.78 + secondary * secondaryWeight;
    rainMask = clamp(max(sourceBody * 0.52, shapedRain), 0.0, 1.0);
    coreMask = clamp(max(sourceBody * 0.22,
        coreA * 0.72 + coreB * secondaryWeight), 0.0, 1.0);
    edgeMask = clamp(edgeA * 0.62 + edgeB * secondaryWeight * 0.72,
                     0.0, 1.0);

    // Nearby drops carry reflective definition; distant drops dissolve softly
    // into the rainy haze without vanishing.
    float distanceFade = mix(1.0, 0.68,
        smoothstep(12.0, 58.0, viewDistance));
    rainMask *= distanceFade;
    coreMask *= distanceFade;
    edgeMask *= distanceFade;
}

#endif
