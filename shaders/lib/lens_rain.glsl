/* Aurora Fantasy - Camera-lens rain
 * Windshield-inspired beads, merged drops and sparse flowing rivulets.
 * Every event receives a new path, size and shape on its next pass.
 */
#ifndef AURORA_LENS_RAIN
#define AURORA_LENS_RAIN

float lensRainHash(vec2 value) {
    return fract(sin(dot(value, vec2(41.37, 289.11))) * 45758.5453);
}

float lensRainEllipse(vec2 point, vec2 radius) {
    return length(point / max(radius, vec2(0.0001)));
}

/* Condensation beads nucleate in place, remain attached to the glass, then
 * slowly creep down once enough water has accumulated. Long, overlapping
 * fade windows prevent the pop-in/pop-out visible in the previous system.
 */
void lensRainSurfaceLayer(vec2 uv, vec2 grid, float seed,
                          float lifeSpeed, float presenceThreshold,
                          out float bodyMask, out float rimMask,
                          out vec2 surfaceNormal) {
    vec2 scaledUV = uv * grid;
    vec2 cell = floor(scaledUV);
    vec2 localUV = fract(scaledUV);

    float fixedRandom = lensRainHash(cell + vec2(seed, seed * 1.93));
    float travel = persistentTimeSeconds * lifeSpeed
                 * mix(0.78, 1.18,
                    lensRainHash(cell.yx + vec2(7.1, seed * 2.7)))
                 + fixedRandom * 19.0;
    float cycle = floor(travel);
    float age = fract(travel);
    vec2 cycleKey = cell + vec2(cycle * 0.91 + seed,
                                cycle * 1.51 - seed * 0.63);

    float xRandom = lensRainHash(cycleKey + vec2(13.1, 47.7));
    float yRandom = lensRainHash(cycleKey.yx + vec2(29.3, 5.4));
    float sizeRandom = lensRainHash(cycleKey + vec2(71.2, 18.6));
    float shapeRandom = lensRainHash(cycleKey.yx + vec2(9.8, 83.1));
    float eventRandom = lensRainHash(cycleKey + vec2(37.5, 61.4));
    float mobility = lensRainHash(cycleKey.yx + vec2(54.2, 26.7));

    float eventPresence = smoothstep(presenceThreshold,
                                     presenceThreshold + 0.055,
                                     eventRandom);
    float appear = smoothstep(0.015, 0.22, age);
    float disappear = 1.0 - smoothstep(0.74, 0.995, age);
    float visibility = appear * disappear * eventPresence;

    float creep = smoothstep(0.48, 0.94, age);
    creep *= creep * smoothstep(0.38, 0.82, mobility);
    vec2 center = vec2(mix(0.14, 0.86, xRandom),
                       mix(0.16, 0.84, yRandom)
                       - creep * mix(0.025, 0.15, mobility));

    vec2 local = localUV - center;
    float cellAspect = (viewWidth / max(viewHeight, 1.0))
                     * (grid.y / grid.x);
    vec2 metricLocal = vec2(local.x * cellAspect, local.y);
    float radius = mix(0.045, 0.105, sizeRandom);

    // Asymmetric glass-contact shape: skew, taper, and a secondary merged lobe.
    vec2 shapedLocal = metricLocal;
    shapedLocal.x += shapedLocal.y * mix(-0.16, 0.18, shapeRandom);
    shapedLocal.x *= mix(0.92, 1.38,
        smoothstep(-radius * 0.20, radius * 1.20, shapedLocal.y));
    float angle = atan(shapedLocal.y, shapedLocal.x);
    float contour = 1.0
        + sin(angle * 3.0 + shapeRandom * 8.7) * 0.060
        + sin(angle * 6.0 - shapeRandom * 4.1) * 0.025;
    vec2 beadRadius = vec2(radius * mix(0.76, 0.96, shapeRandom),
                           radius * mix(0.88, 1.28, mobility));
    float beadDistance = lensRainEllipse(shapedLocal, beadRadius)
                       * contour;
    float bead = 1.0 - smoothstep(0.62, 1.05, beadDistance);
    float beadRim = smoothstep(0.49, 0.74, beadDistance)
                  * (1.0 - smoothstep(0.74, 1.10, beadDistance));

    vec2 lobeOffset = vec2(radius * mix(-0.50, 0.48, mobility),
                           radius * mix(0.16, 0.58, shapeRandom));
    float lobeDistance = lensRainEllipse(
        metricLocal - lobeOffset, beadRadius * vec2(0.52, 0.48));
    float lobeAmount = smoothstep(0.40, 0.74, shapeRandom);
    float lobe = (1.0 - smoothstep(0.62, 1.06, lobeDistance))
               * lobeAmount;
    float lobeRim = smoothstep(0.49, 0.74, lobeDistance)
                  * (1.0 - smoothstep(0.74, 1.10, lobeDistance))
                  * lobeAmount;

    // Only mature mobile beads leave a short soft trace.
    float trailWidth = radius * mix(0.12, 0.22, mobility);
    float trail = 1.0 - smoothstep(trailWidth,
                                   trailWidth * 2.35,
                                   abs(metricLocal.x));
    trail *= smoothstep(radius * 0.35, radius * 0.85, local.y)
           * (1.0 - smoothstep(radius * 1.8,
                                radius * 3.8, local.y))
           * creep;

    float combinedBead = max(bead, lobe * 0.82);
    bodyMask = clamp(combinedBead + trail * 0.22,
                     0.0, 1.0) * visibility;
    rimMask = clamp(max(beadRim, lobeRim * 0.84) + trail * 0.07,
                    0.0, 1.0) * visibility;

    vec2 radial = shapedLocal / max(length(shapedLocal), 0.001);
    radial.x /= max(cellAspect, 0.001);
    surfaceNormal = (radial * combinedBead
                   + vec2(sign(metricLocal.x), 0.10) * trail * 0.15)
                  * visibility;
}

void lensRainBeadLayer(vec2 uv, vec2 grid, float seed, float fallSpeed,
                       float presenceThreshold, out float bodyMask,
                       out float rimMask, out vec2 surfaceNormal) {
    vec2 scaledUV = uv * grid;
    vec2 cell = floor(scaledUV);
    vec2 localUV = fract(scaledUV);

    float fixedRandom = lensRainHash(cell + vec2(seed, seed * 1.71));
    float speedRandom = lensRainHash(cell.yx + vec2(seed * 2.31, 7.19));
    float travel = persistentTimeSeconds * fallSpeed
                 * mix(0.76, 1.24, speedRandom) + fixedRandom * 11.0;
    float cycle = floor(travel);
    float age = fract(travel);

    vec2 cycleKey = cell + vec2(cycle * 0.73 + seed,
                                cycle * 1.37 - seed * 0.41);
    float xRandom = lensRainHash(cycleKey + vec2(11.7, 3.1));
    float sizeRandom = lensRainHash(cycleKey.yx + vec2(5.9, 23.4));
    float eventRandom = lensRainHash(cycleKey + vec2(37.1, 17.8));
    float driftRandom = lensRainHash(cycleKey.yx + vec2(19.2, 51.6));
    float shapeRandom = lensRainHash(cycleKey + vec2(73.4, 9.6));

    float eventPresence = smoothstep(presenceThreshold,
                                     presenceThreshold + 0.06,
                                     eventRandom);
    float lifeFade = smoothstep(0.02, 0.13, age)
                   * (1.0 - smoothstep(0.80, 0.98, age));

    vec2 center;
    center.x = mix(0.16, 0.84, xRandom)
             + (age - 0.5) * mix(-0.060, 0.082, driftRandom);
    center.y = 1.17 - age * mix(1.39, 1.53, speedRandom);

    vec2 local = localUV - center;
    float cellAspect = (viewWidth / max(viewHeight, 1.0))
                     * (grid.y / grid.x);
    vec2 metricLocal = vec2(local.x * cellAspect, local.y);

    float radius = mix(0.050, 0.086, sizeRandom);
    vec2 mainRadius = vec2(radius * mix(0.76, 0.94, shapeRandom),
                           radius * mix(1.08, 1.55, shapeRandom));
    // A tapered, slightly warped silhouette produces a hanging glass bead,
    // not a repeated circle. The upper side narrows where it feeds the trail.
    vec2 shapedLocal = metricLocal;
    float upperTaper = smoothstep(-radius * 0.16,
                                   radius * 1.42,
                                   metricLocal.y);
    shapedLocal.x *= mix(0.91, 1.52, upperTaper);
    shapedLocal.x += sin(metricLocal.y / max(radius, 0.001) * 2.7
                         + shapeRandom * 8.0) * radius * 0.045;
    float contourAngle = atan(shapedLocal.y, shapedLocal.x);
    float contourWarp = 1.0
        + sin(contourAngle * 3.0 + shapeRandom * 9.1) * 0.052
        + sin(contourAngle * 5.0 - shapeRandom * 5.7) * 0.026;
    float mainDistance = lensRainEllipse(shapedLocal, mainRadius)
                       * contourWarp;
    float mainBead = 1.0 - smoothstep(0.66, 1.04, mainDistance);
    float mainRim = smoothstep(0.48, 0.73, mainDistance)
                  * (1.0 - smoothstep(0.73, 1.10, mainDistance));

    // Irregular drops grow a second lobe rather than remaining perfect ovals.
    float mergeAmount = smoothstep(0.28, 0.78, shapeRandom);
    vec2 lobeOffset = vec2(radius * mix(-0.48, 0.52, driftRandom),
                           radius * mix(0.42, 0.76, sizeRandom));
    float lobeDistance = lensRainEllipse(metricLocal - lobeOffset,
                                          mainRadius * vec2(0.68, 0.61));
    float secondLobe = (1.0 - smoothstep(0.65, 1.05, lobeDistance))
                     * mergeAmount;
    float secondRim = smoothstep(0.48, 0.74, lobeDistance)
                    * (1.0 - smoothstep(0.74, 1.10, lobeDistance))
                    * mergeAmount;

    // A curved wet trace above the falling bead visually joins nearby drops.
    float trailLength = mix(0.16, 0.35, shapeRandom);
    float trailCurve = sin(local.y * 10.0 + shapeRandom * 6.28318)
                     * radius * 0.13;
    float trailX = abs(metricLocal.x - trailCurve);
    float trailWidth = radius * mix(0.18, 0.31, sizeRandom);
    float trail = 1.0 - smoothstep(trailWidth,
                                   trailWidth * 2.25,
                                   trailX);
    trail *= smoothstep(0.012, 0.055, local.y)
           * (1.0 - smoothstep(trailLength * 0.74,
                                trailLength, local.y));

    float visibility = lifeFade * eventPresence;
    float beadBody = max(mainBead, secondLobe * 0.82);
    bodyMask = clamp(beadBody + trail * 0.32, 0.0, 1.0)
             * visibility;
    rimMask = clamp(max(mainRim, secondRim * 0.88)
                  + trail * 0.11, 0.0, 1.0) * visibility;

    vec2 radial = metricLocal / max(length(metricLocal), 0.001);
    radial.x /= max(cellAspect, 0.001);
    surfaceNormal = (radial * beadBody
                   + vec2(sign(metricLocal.x - trailCurve), 0.12)
                     * trail * 0.23) * visibility;
}

void lensRainRivulet(vec2 uv, float seed, out float bodyMask,
                     out float rimMask, out vec2 surfaceNormal) {
    const float columnCount = 5.0;
    float columnCoordinate = uv.x * columnCount;
    float column = floor(columnCoordinate);
    float localX = fract(columnCoordinate);

    float fixedRandom = lensRainHash(vec2(column, seed));
    float speedRandom = lensRainHash(vec2(seed * 2.7, column + 8.3));
    float travel = persistentTimeSeconds * 0.080
                 * mix(0.72, 1.24, speedRandom) + fixedRandom * 13.0;
    float cycle = floor(travel);
    float age = fract(travel);
    vec2 cycleKey = vec2(column + cycle * 0.81 + seed,
                         cycle * 1.43 - seed);

    float eventRandom = lensRainHash(cycleKey + vec2(4.7, 31.2));
    float xRandom = lensRainHash(cycleKey.yx + vec2(18.5, 7.2));
    float widthRandom = lensRainHash(cycleKey + vec2(52.1, 13.4));
    float phaseRandom = lensRainHash(cycleKey.yx + vec2(27.3, 69.1));
    float targetRandom = lensRainHash(cycleKey + vec2(81.7, 43.9));

    float eventPresence = smoothstep(0.63, 0.71, eventRandom);
    float lifeFade = smoothstep(0.025, 0.15, age)
                   * (1.0 - smoothstep(0.80, 0.98, age));
    float headY = 1.15 - age * 1.40;
    float trailLength = mix(0.27, 0.48, phaseRandom);
    float targetY = mix(0.18, 0.78, targetRandom);
    float targetSeparation = headY - targetY;
    float capturedTarget = 1.0 - smoothstep(-0.035, 0.055,
                                             targetSeparation);
    float targetAlive = smoothstep(-0.060, 0.025,
                                    targetSeparation);
    float mergeApproach = 1.0 - smoothstep(0.025, 0.16,
                                           abs(targetSeparation));

    float pathWave = sin(uv.y * 9.0 + phaseRandom * 6.28318
                         + persistentTimeSeconds * 0.13) * 0.030
                   + sin(uv.y * 19.0 + phaseRandom * 11.7) * 0.012;
    float pathCenter = mix(0.22, 0.78, xRandom) + pathWave;
    float aspect = viewWidth / max(viewHeight, 1.0);
    float pathDistance = abs(localX - pathCenter)
                       * aspect / columnCount;
    float verticalTrail = uv.y - headY;
    float lineWidth = mix(0.0014, 0.0025, widthRandom);
    float line = 1.0 - smoothstep(lineWidth,
                                  lineWidth * 2.45,
                                  pathDistance);
    line *= smoothstep(0.008, 0.040, verticalTrail)
          * (1.0 - smoothstep(trailLength * 0.84,
                               trailLength, verticalTrail));

    float globalPathX = (column + pathCenter) / columnCount;
    vec2 headLocal = vec2((uv.x - globalPathX) * aspect,
                          uv.y - headY);
    // The moving head gains volume after collecting the stationary bead.
    float headRadius = mix(0.0080, 0.0140, widthRandom)
                     * (1.0 + capturedTarget * 0.34);
    float headDistance = lensRainEllipse(
        headLocal, vec2(headRadius, headRadius * 1.42));
    float head = 1.0 - smoothstep(0.64, 1.05, headDistance);
    float headRim = smoothstep(0.47, 0.73, headDistance)
                  * (1.0 - smoothstep(0.73, 1.10, headDistance));

    // A stationary bead waits on the wet path. As the moving head reaches it,
    // a short neck forms, the bead is absorbed, and the head grows.
    float upperBeadY = targetY;
    float upperWave = sin(upperBeadY * 9.0 + phaseRandom * 6.28318
                          + persistentTimeSeconds * 0.13) * 0.030
                    + sin(upperBeadY * 19.0 + phaseRandom * 11.7) * 0.012;
    float upperPathX = (column + mix(0.22, 0.78, xRandom)
                      + upperWave) / columnCount;
    vec2 upperLocal = vec2((uv.x - upperPathX) * aspect,
                           uv.y - upperBeadY);
    float upperDistance = lensRainEllipse(
        upperLocal, vec2(headRadius * 0.70, headRadius * 0.86));
    float upperBead = (1.0 - smoothstep(0.64, 1.06, upperDistance))
                    * targetAlive;
    float upperRim = smoothstep(0.48, 0.73, upperDistance)
                   * (1.0 - smoothstep(0.73, 1.10, upperDistance))
                   * targetAlive;

    float connectorBottom = min(headY, targetY);
    float connectorTop = max(headY, targetY);
    float connectorVertical = smoothstep(connectorBottom - 0.012,
                                          connectorBottom + 0.022,
                                          uv.y)
                            * (1.0 - smoothstep(connectorTop - 0.022,
                                                connectorTop + 0.012,
                                                uv.y));
    float connector = (1.0 - smoothstep(lineWidth * 1.20,
                                         lineWidth * 2.85,
                                         pathDistance))
                    * connectorVertical * mergeApproach;

    float visibility = eventPresence * lifeFade;
    bodyMask = clamp(max(head, upperBead * 0.82)
                   + line * 0.46 + connector * 0.62,
                     0.0, 1.0) * visibility;
    rimMask = clamp(max(headRim, upperRim * 0.86)
                  + line * 0.13 + connector * 0.16,
                    0.0, 1.0) * visibility;

    vec2 headNormal = headLocal / max(length(headLocal), 0.001);
    vec2 lineNormal = vec2(sign(localX - pathCenter), 0.10);
    surfaceNormal = (headNormal * head
                   + lineNormal * (line * 0.34 + connector * 0.42))
                  * visibility;
}

void getLensRain(vec2 uv, float rainAmount, out float lensMask,
                 out float lensRim, out vec2 lensNormal) {
    float surfaceBody;
    float surfaceRim;
    vec2 surfaceNormal;
    lensRainSurfaceLayer(uv, vec2(10.0, 6.0), 13.7,
                         0.030, 0.74,
                         surfaceBody, surfaceRim, surfaceNormal);

    float microBody;
    float microRim;
    vec2 microNormal;
    lensRainSurfaceLayer(uv + vec2(0.037, 0.061), vec2(16.0, 9.0),
                         47.3, 0.043, 0.86,
                         microBody, microRim, microNormal);

    float movingBody;
    float movingRim;
    vec2 movingNormal;
    lensRainBeadLayer(uv + vec2(0.083, 0.019), vec2(5.0, 3.0),
                      71.5, 0.108, 0.80,
                      movingBody, movingRim, movingNormal);

    float rivuletBody;
    float rivuletRim;
    vec2 rivuletNormal;
    lensRainRivulet(uv, 91.7, rivuletBody,
                    rivuletRim, rivuletNormal);

    float rainFade = smoothstep(0.045, 0.38, rainAmount);
    // Reduce, rather than erase, drops around the crosshair.
    float centerUsability = mix(0.42, 1.0,
        smoothstep(0.055, 0.21, length(uv - vec2(0.5))));

    lensMask = clamp(surfaceBody * 0.72 + microBody * 0.43
                   + movingBody * 0.52 + rivuletBody * 1.00,
                     0.0, 1.0)
             * rainFade * centerUsability;
    lensRim = clamp(surfaceRim * 0.68 + microRim * 0.38
                  + movingRim * 0.48 + rivuletRim * 0.96,
                    0.0, 1.0)
            * rainFade * centerUsability;
    lensNormal = (surfaceNormal * 0.72 + microNormal * 0.42
                + movingNormal * 0.54 + rivuletNormal * 0.98)
               * rainFade * centerUsability;
}

#endif
