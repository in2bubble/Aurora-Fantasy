/* Aurora Fantasy - Procedural Rain Streaks
 * Dense, softly tapered rain independent of vanilla texture coverage.
 */
#ifndef AURORA_FANTASY_RAIN
#define AURORA_FANTASY_RAIN

float fantasyRainStreak(vec2 uv, float columns, float rows, float phase,
                        float width, out float core, out float edge) {
    columns *= RAIN_DENSITY;
    float columnId = floor(uv.x * columns);
    // Each falling cell owns a stable random seed.  Unlike the old phase-only
    // hash, drops no longer brighten, widen, and repeat in lockstep.
    float rowId = floor(uv.y * rows + phase * 1.73);
    float variation = fract(sin(dot(vec2(columnId, rowId),
        vec2(12.9898, 78.233))) * 43758.5453);

    // The geometry supplies the broad wind angle; this smaller local shear
    // keeps individual drops from sharing one perfectly straight trajectory.
    // Fall is driven primarily along Y.  A small per-drop lateral drift adds
    // wind without making every streak slide sideways in lockstep.
    float localX = fract(uv.x * columns
                       + uv.y * mix(0.10, 0.22, variation)
                       + phase * mix(0.035, 0.115, variation)) - 0.5;
    float localY = fract(uv.y * rows + columnId * 0.381966 + phase * 1.73);

    float capIn = smoothstep(0.025, 0.16, localY);
    float capOutStart = mix(0.38, 0.58, variation);
    float capOut = 1.0 - smoothstep(capOutStart, capOutStart + 0.25, localY);
    float longitudinal = capIn * capOut;

    // Wide optical variance makes a few nearby drops readable while most
    // remain fine. It deliberately avoids a field of identical thread lines.
    // Slightly larger, but still tapered: enough presence at normal gameplay
    // distance without turning the rain into thick screen-space threads.
    float variedWidth = width * mix(0.40, 1.36, variation * variation);
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
                    out float coreMask, out float edgeMask,
                    out float dropOpacityVariation) {
    // World phase breaks the identical texture repetition between Minecraft's
    // many weather columns while remaining stable as the camera moves.
    float worldPhase = fract(dot(worldXZ, vec2(0.0317, 0.0473)));
    // Weather quads are nearly stationary while the player stands still.
    // Use a deliberately brisk shader-time phase so the falling motion remains
    // obvious even with a perfectly still camera.
    // This weather quad's V axis runs upward in screen motion, so a negative
    // phase is the physical top-to-bottom falling direction.
    float rainTime = -frameTimeCounter * 3.40;

    float coreA;
    float edgeA;
    float primary = fantasyRainStreak(
        texUV + vec2(worldPhase, worldPhase * 0.21),
        2.0, 1.35, rainTime * 0.86 + 0.13, 0.058, coreA, edgeA);

    float coreB;
    float edgeB;
    float secondary = fantasyRainStreak(
        texUV + vec2(0.37 - worldPhase * 0.43, 0.19),
        2.65, 2.20, rainTime * 1.12 + 0.57, 0.044,
        coreB, edgeB);

    float coreC;
    float edgeC;
    float tertiary = fantasyRainStreak(
        texUV + vec2(worldPhase * 0.28 + 0.71, 0.63 - worldPhase * 0.37),
        3.45, 3.25, rainTime * 1.57 + 0.31, 0.030,
        coreC, edgeC);

    float coreD;
    float edgeD;
    float fineRain = fantasyRainStreak(
        texUV + vec2(0.16 - worldPhase * 0.67, worldPhase * 0.53 + 0.44),
        4.60, 4.50, rainTime * 1.91 + 0.79, 0.018,
        coreD, edgeD);

    // The texture alpha is used only as a safe boundary for the weather quad.
    // This prevents hidden parts of the quad becoming visible as squares.
    float sourceBody = smoothstep(0.012, 0.18, sourceAlpha);
    float secondaryWeight = mix(0.40, 0.46, nightAmount);

    // Four independent layers combine heavy foreground drops, ordinary rain,
    // thin fast streaks, and a fine distant curtain without tiled animation.
    float shapedRain = primary * 0.82
        + secondary * secondaryWeight
        + tertiary * 0.34
        + fineRain * 0.16;
    // Give each particle a stable character. Variation is continuous, so every
    // direction keeps rain and no large clear sector can form.
    vec2 particleCell = floor(worldXZ * 3.70);
    float particleSeed = fract(sin(dot(particleCell,
        vec2(91.137, 41.719))) * 15731.743);
    float dropSeed = fract(sin(dot(particleCell + vec2(17.0, 53.0),
        vec2(41.371, 289.913))) * 12653.731);

    // Keep the game's weather geometry clipped to its valid silhouette. The
    // shader then changes only the optics per drop, avoiding UV-dependent
    // square artifacts while retaining smooth time-based variation.
    float smoothFallPhase = 0.92 + 0.08 * sin(
        frameTimeCounter * mix(4.8, 7.1, dropSeed)
        + particleSeed * 6.2831853);
    float presenceVariation = mix(0.88, 1.0, particleSeed);
    float shapeWeight = mix(0.90, 1.0, shapedRain);
    rainMask = sourceBody * presenceVariation * shapeWeight;
    coreMask = sourceBody * presenceVariation
             * smoothstep(0.30, 0.88, sourceAlpha);
    edgeMask = sourceBody * presenceVariation
             * (0.20 + 0.46 * edgeA + 0.22 * edgeB + 0.10 * edgeC);

    // Controlled particle-level optical variance: visible, but never a white
    // curtain. The brighter droplets also receive a slightly wider streak.
    dropOpacityVariation = mix(0.48, 0.98, dropSeed * dropSeed)
                         * smoothFallPhase;

    // Nearby drops carry reflective definition; distant drops dissolve softly
    // into the rainy haze without vanishing.
    float distanceFade = mix(1.0, 0.68,
        smoothstep(12.0, 58.0, viewDistance));
    rainMask *= distanceFade;
    coreMask *= distanceFade;
    edgeMask *= distanceFade;
    dropOpacityVariation *= mix(0.78, 1.0,
        1.0 - smoothstep(8.0, 52.0, viewDistance));
}

#endif
