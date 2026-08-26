/* Aurora Fantasy - Fantasy Rain Puddles
 * A clean-room puddle material built for Aurora's world-space pipeline.
 * Pool boundaries never animate. The surface combines Aurora's real water
 * noisetex flow with analytic capillary waves and physical raindrop rings.
 */
#ifndef AURORA_FANTASY_PUDDLES
#define AURORA_FANTASY_PUDDLES

#include "/lib/water_waves.glsl"
#include "/lib/water_palette.glsl"

vec2 fantasyHash22(vec2 p) {
    vec2 q = vec2(dot(p, vec2(127.1, 311.7)),
                  dot(p, vec2(269.5, 183.3)));
    return fract(sin(q) * 43758.5453);
}

float fantasyHash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float fantasyValueNoise(vec2 p) {
    vec2 cell = floor(p);
    vec2 local = fract(p);
    vec2 curve = local * local * (3.0 - 2.0 * local);
    float a = fantasyHash12(cell);
    float b = fantasyHash12(cell + vec2(1.0, 0.0));
    float c = fantasyHash12(cell + vec2(0.0, 1.0));
    float d = fantasyHash12(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, curve.x), mix(c, d, curve.x), curve.y);
}

float fantasyBoundaryNoise(vec2 p) {
    float value = fantasyValueNoise(p);
    value += fantasyValueNoise(p * 2.07 + vec2(7.3, 2.1)) * 0.50;
    value += fantasyValueNoise(p * 4.13 + vec2(1.7, 9.2)) * 0.25;
    return value * 0.5714286;
}

// Slowly advected multi-scale noise gives shallow water an organic surface.
// The coordinates are world anchored, so turning the camera never changes the
// wave pattern; only time moves the two crossing flows.
float fantasyAnimatedWaterNoise(vec2 worldXZ, float time) {
    vec2 flowA = vec2(0.043, -0.026) * time;
    vec2 flowB = vec2(-0.021, 0.037) * time;
    float broad = fantasyValueNoise(worldXZ * 0.34 + flowA);
    float medium = fantasyValueNoise(
        worldXZ * 0.73 + flowB + vec2(17.2, 5.8));
    float fine = fantasyValueNoise(
        worldXZ * 1.47 - flowA * 1.31 + vec2(3.6, 29.1));
    return broad * 0.52 + medium * 0.32 + fine * 0.16;
}

vec2 fantasyAnimatedWaterSlope(vec2 worldXZ, float time) {
    const float epsilon = 0.075;
    float center = fantasyAnimatedWaterNoise(worldXZ, time);
    float offsetX = fantasyAnimatedWaterNoise(
        worldXZ + vec2(epsilon, 0.0), time);
    float offsetY = fantasyAnimatedWaterNoise(
        worldXZ + vec2(0.0, epsilon), time);
    return vec2(offsetX - center, offsetY - center) / epsilon;
}

// Sparse, irregular world-space islands decide where expensive SSR is allowed.
// Most of each puddle remains a stable animated water material instead of a
// full-screen mirror. Deeper centres receive slightly more reflection.
float getFantasyPuddleSSRMask(vec3 worldPos, float puddleDepth) {
    float broad = fantasyBoundaryNoise(
        worldPos.xz * 0.115 + vec2(31.7, 8.4));
    float breakup = fantasyValueNoise(
        worldPos.xz * 0.41 + vec2(6.2, 47.9));
    float patchField = broad * 0.76 + breakup * 0.24;
    // Roughly one third of a mature pool participates, with only the centres
    // of those islands reaching full SSR strength.
    float islands = smoothstep(0.61, 0.77, patchField);
    float depthGate = smoothstep(0.18, 0.72, puddleDepth);
    return islands * mix(0.42, 1.0, depthGate);
}

float fantasyCapsuleDistance(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float projection = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001),
                             0.0, 1.0);
    return length(pa - ba * projection);
}

// A multi-lobed, domain-warped basin per world-space cell. Each basin combines
// ellipses, satellite lobes and a short joining channel, producing silhouettes
// that range from narrow runoff patches to broad asymmetric pools.
vec2 fantasyPoolLayer(vec2 worldXZ, float cellSize, vec2 offset, float radiusScale) {
    vec2 grid = worldXZ / cellSize + offset;
    vec2 cell = floor(grid);
    vec2 local = fract(grid) - 0.5;
    vec2 seed = fantasyHash22(cell + offset * 17.0);
    vec2 seedB = fantasyHash22(cell + vec2(19.7, 43.1));

    vec2 center = (seed - 0.5) * 0.14;
    float angle = (seedB.x - 0.5) * 2.2;
    float cs = cos(angle);
    float sn = sin(angle);
    vec2 p = mat2(cs, -sn, sn, cs) * (local - center);

    vec2 seedC = fantasyHash22(cell + vec2(71.3, 11.9));
    vec2 seedD = fantasyHash22(cell + vec2(5.7, 83.4));
    float aspect = mix(0.55, 1.65, seed.y);
    float radius = mix(0.22, 0.34, seedB.y) * radiusScale;
    float mainShape = length(vec2(p.x / aspect, p.y * aspect)) - radius;

    vec2 lobeDirectionA = seedB - 0.48;
    lobeDirectionA /= max(length(lobeDirectionA), 0.05);
    vec2 lobeOffsetA = lobeDirectionA * mix(0.10, 0.25, seedC.x);
    vec2 lobeA = p - lobeOffsetA;
    float lobeAShape = length(vec2(
        lobeA.x / mix(0.62, 1.35, seedC.y),
        lobeA.y * mix(0.72, 1.42, seedD.x)))
        - radius * mix(0.42, 0.72, seedC.x);

    vec2 lobeDirectionB = seedC - 0.46;
    lobeDirectionB /= max(length(lobeDirectionB), 0.05);
    vec2 lobeOffsetB = -lobeDirectionB * mix(0.12, 0.29, seedD.y);
    vec2 lobeB = p - lobeOffsetB;
    float lobeBShape = length(vec2(
        lobeB.x / mix(0.70, 1.48, seedD.x),
        lobeB.y * mix(0.64, 1.36, seedC.y)))
        - radius * mix(0.34, 0.61, seedD.y);

    float channel = fantasyCapsuleDistance(
        p, lobeOffsetA * 0.18, lobeOffsetB * 0.82)
        - radius * mix(0.25, 0.43, seed.x);

    float shape = min(min(mainShape, lobeAShape), min(lobeBShape, channel));

    // Stable world-space domain noise carves coves and small protrusions into
    // the silhouette without making the boundary crawl over time.
    float boundaryNoise = fantasyBoundaryNoise(
        worldXZ * mix(0.34, 0.52, seedC.x) + seedD * 13.7) - 0.5;
    float contour = boundaryNoise * 0.072
                  + sin(p.x * 23.0 + seed.x * 6.2831)
                  * sin(p.y * 17.0 - seed.y * 6.2831) * 0.018;
    float distanceToPool = shape + contour;

    // Broad continuous transition: wet soil -> shallow film -> deeper pool.
    // Returning depth instead of a bright rim prevents a raised mirror edge.
    float body = 1.0 - smoothstep(-0.035, 0.070, distanceToPool);
    float depth = 1.0 - smoothstep(-0.155, -0.020, distanceToPool);
    return vec2(body, depth);
}

// Three scales and rain-dependent filling produce a varied distribution. Heavy
// rain reveals secondary runoff basins instead of merely brightening circles.
vec2 getFantasyPuddleField(vec3 worldPos, float upDot, float rainAmount) {
    // Keep clearly separate basins instead of coating most of the terrain with
    // the deep-water material. The surrounding area is handled by wet film.
    vec2 runoffPools = fantasyPoolLayer(
        worldPos.xz, 9.5, vec2(0.17, 0.41), 0.72);
    vec2 broadPools = fantasyPoolLayer(
        worldPos.xz, 15.5, vec2(0.63, 0.08), 1.00);
    vec2 rarePools = fantasyPoolLayer(
        worldPos.xz, 27.0, vec2(0.31, 0.76), 0.88);

    float runoffFill = smoothstep(0.28, 0.82, rainAmount);
    float rareFill = smoothstep(0.50, 0.96, rainAmount);
    float body = max(broadPools.x,
        max(runoffPools.x * runoffFill, rarePools.x * rareFill));
    float depth = max(broadPools.y,
        max(runoffPools.y * runoffFill * 0.82, rarePools.y * rareFill));
    float horizontal = smoothstep(0.82, 0.96, upDot);
    float filled = smoothstep(0.12, 0.72, rainAmount);
    return vec2(body, depth) * horizontal * filled;
}

vec2 fantasyWaveSlope(vec2 direction, float wavelength, float amplitude,
                      vec2 position, float time) {
    direction = normalize(direction);
    float k = 6.28318530718 / wavelength;
    float speed = sqrt(9.8 / k);
    float phase = mod(k * dot(direction, position) - speed * time, 6.28318530718);
    return direction * (k * amplitude * cos(phase));
}

// Expanding circular wave caused by an actual raindrop event. Hashing selects
// a fixed impact point and time only; the animation itself is a radial wave.
vec2 fantasyRainRing(vec2 worldXZ, float time, float scale, vec2 offset,
                     out float ringLight, out float bubbleLight) {
    vec2 grid = worldXZ * scale + offset;
    vec2 cell = floor(grid);
    vec2 local = fract(grid);
    vec2 seed = fantasyHash22(cell + offset * 31.0);
    vec2 eventSeed = fantasyHash22(
        cell + offset * 13.0 + vec2(41.7, 9.2));
    vec2 impact = mix(vec2(0.18), vec2(0.82), seed);
    vec2 delta = local - impact;
    float distanceToImpact = length(delta);

    float age = fract(time * mix(0.62, 0.92, seed.x) + seed.y);
    float eventSize = mix(0.68, 1.38, eventSeed.x);
    float eventOpacity = mix(0.32, 0.86, eventSeed.y);
    float radius = age * 0.42 * eventSize;
    float bandSharpness = mix(44.0, 72.0, seed.y) / eventSize;
    // At a shallow camera angle a world-space ring can become thinner than a
    // screen pixel and disappear.  Keep its analytic width when close, but
    // widen it only enough to cover the current pixel footprint at distance.
    float screenFootprint = clamp(fwidth(distanceToImpact), 0.0, 0.038);
    float bandHalfWidth = max(1.0 / bandSharpness,
                              screenFootprint * 0.82);
    float band = exp(-pow(
        (distanceToImpact - radius) / bandHalfWidth, 2.0));
    float fade = (1.0 - age) * (1.0 - age);
    // A short fade-in removes the single bright white pixel that otherwise
    // appears on the exact birth frame of every impact.
    float birthFade = smoothstep(0.0, 0.045, age);
    float ring = band * fade * birthFade * eventOpacity;

    // A short-lived bright crown at the impact point reads as the tiny bubble
    // and upward splash produced when the drop hits a wet surface.
    float impactCrown = exp(-distanceToImpact * distanceToImpact
                      * (360.0 / eventSize))
                      * birthFade
                      * (1.0 - smoothstep(0.035, 0.18, age))
                      * eventOpacity * 0.52;
    float microBubbleRadius = age * mix(0.075, 0.17, eventSeed.x);
    float microBubbleSharpness = mix(68.0, 108.0, seed.x) / eventSize;
    float microBubbleHalfWidth = max(1.0 / microBubbleSharpness,
                                     screenFootprint * 0.68);
    float microBubble = exp(-pow(
        (distanceToImpact - microBubbleRadius) / microBubbleHalfWidth, 2.0))
        * birthFade
        * (1.0 - smoothstep(0.05, 0.46, age))
        * eventOpacity;
    ringLight = clamp(ring + impactCrown * 0.58 + microBubble * 0.48,
                      0.0, 1.0);
    bubbleLight = clamp(
        impactCrown * 0.62 + microBubble * 0.74,
        0.0, 1.0);

    vec2 radial = distanceToImpact > 0.001 ? delta / distanceToImpact : vec2(0.0);
    return radial * (ring * 0.028 + microBubble * 0.012
                   + impactCrown * 0.008);
}

// Thin wet-film normal for exposed terrain. Two low-amplitude capillary waves
// and one physical impact layer animate the clear coat without moving textures.
vec3 getFantasyWetFilmNormal(vec3 worldPos, float time, float viewDistance,
                             out float rippleLight) {
    float detailFade = 1.0 - smoothstep(18.0, 52.0, viewDistance);
    float t = time * 0.58;
    vec2 slope = vec2(0.0);
    slope += fantasyWaveSlope(vec2(1.0, 0.35), 2.8, 0.007,
        worldPos.xz, t) * detailFade;
    slope += fantasyWaveSlope(vec2(-0.45, 1.0), 1.65, 0.0045,
        worldPos.xz, t * 1.27) * detailFade;

    float ringA;
    float ringB;
    float bubbleA;
    float bubbleB;
    slope += fantasyRainRing(worldPos.xz, time, 2.25,
        vec2(5.4, 11.8), ringA, bubbleA) * detailFade * 0.55;
    slope += fantasyRainRing(worldPos.xz, time * 1.11, 3.10,
        vec2(13.2, 4.6), ringB, bubbleB) * detailFade * 0.34;
    rippleLight = clamp(
        ringA + ringB * 0.72 + bubbleA * 0.28 + bubbleB * 0.18,
        0.0, 1.0) * detailFade;
    return normalize(vec3(-slope.x, 1.0, -slope.y));
}

vec3 getFantasyPuddleNormal(vec3 worldPos, float time, float viewDistance,
                            float skyVisibility,
                            out float rippleLight, out float bubbleLight) {
    float mediumDetail = 1.0 - smoothstep(28.0, 78.0, viewDistance);
    // Rings remain readable on the foreshortened ground ahead of the camera.
    // Pixel-footprint antialiasing above prevents this longer range from
    // turning into unstable single-pixel sparkles.
    float fineDetail = 1.0 - smoothstep(18.0, 62.0, viewDistance);
    // Start with the shader's real water material: the same five noisetex
    // bands, current directions, rain boost, and turbulence response used by
    // ordinary water. Puddles then add only their local impact disturbance.
    vec3 shaderWaterTangent = auroraWaterNormalWaves(
        worldPos.xzy, time, rainStrength, skyVisibility);
    vec3 shaderWaterWorld = normalize(vec3(
        shaderWaterTangent.x,
        max(shaderWaterTangent.z, 0.08),
        shaderWaterTangent.y));

    vec2 slope = vec2(0.0);

    float ringA;
    float ringB;
    float ringC;
    float bubbleA;
    float bubbleB;
    float bubbleC;
    slope += fantasyRainRing(worldPos.xz, time, 1.15,
        vec2(3.1, 7.7), ringA, bubbleA) * fineDetail;
    slope += fantasyRainRing(worldPos.xz, time, 1.72,
        vec2(9.3, 2.4), ringB, bubbleB) * fineDetail;
    slope += fantasyRainRing(worldPos.xz, time * 1.07, 2.48,
        vec2(14.7, 6.1), ringC, bubbleC) * fineDetail * 0.62;
    rippleLight = clamp(ringA + ringB + ringC * 0.78,
                        0.0, 1.0) * fineDetail;
    bubbleLight = clamp(
        bubbleA + bubbleB * 0.86 + bubbleC * 0.72,
        0.0, 1.0) * fineDetail;

    vec3 impactNormal = normalize(vec3(-slope.x, 1.0, -slope.y));
    float fullWaterWeight = mix(0.46, 0.72, mediumDetail);
    return normalize(mix(impactNormal, shaderWaterWorld, fullWaterWeight));
}

#endif
