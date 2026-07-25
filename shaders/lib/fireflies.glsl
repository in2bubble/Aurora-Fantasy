/* Aurora Fantasy - world-space nocturnal life

   Each light belongs to a stable three-dimensional world cell. Motion is
   bounded around that cell, so turning the camera never drags the swarm.
   Nearby specimens resolve into a luminous body and two independently
   flapping wing lobes; distant specimens naturally collapse to soft motes.
*/

#ifndef FIREFLIES_GLSL
#define FIREFLIES_GLSL

#include "/lib/fantasy_life.glsl"

#if FANTASY_FIREFLIES == 1
    #define FANTASY_FIREFLY_STEPS 5
    #define FANTASY_FIREFLY_RANGE 20.0
    #define FANTASY_FIREFLY_THRESHOLD 0.92
#elif FANTASY_FIREFLIES == 2
    #define FANTASY_FIREFLY_STEPS 8
    #define FANTASY_FIREFLY_RANGE 30.0
    #define FANTASY_FIREFLY_THRESHOLD 0.86
#elif FANTASY_FIREFLIES == 3
    #define FANTASY_FIREFLY_STEPS 10
    #define FANTASY_FIREFLY_RANGE 36.0
    #define FANTASY_FIREFLY_THRESHOLD 0.78
#elif FANTASY_FIREFLIES >= 4
    #define FANTASY_FIREFLY_STEPS 12
    #define FANTASY_FIREFLY_RANGE 42.0
    #define FANTASY_FIREFLY_THRESHOLD 0.70
#endif

float fantasy_firefly_hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

vec3 fantasy_firefly_hash33(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

float fantasy_distance_to_ray(
    vec3 rayOrigin,
    vec3 rayDirection,
    vec3 pointPosition,
    out float distanceAlongRay
) {
    vec3 toPoint = pointPosition - rayOrigin;
    distanceAlongRay = dot(toPoint, rayDirection);
    vec3 closestPoint = rayOrigin + rayDirection * distanceAlongRay;
    return length(pointPosition - closestPoint);
}

vec3 render_fantasy_fireflies(
    vec3 rayOrigin,
    vec3 rayDirection,
    float sceneDistance,
    float nightAmount,
    float skyLight,
    float rainAmount,
    float habitatAmount,
    float releaseAmount,
    float groundReferenceY,
    float groundVisibility,
    float time,
    out float reactiveMask
) {
    reactiveMask = 0.0;

    #if FANTASY_FIREFLIES <= 0
        return vec3(0.0);
    #else
        if (nightAmount < 0.01) {
            return vec3(0.0);
        }

        // Denser horizontal cells provide an actual free-flying population;
        // the separate plant-perch system remains responsible for grass lights.
        const vec3 cellSize = vec3(9.20, 4.60, 9.20);
        float traceDistance = min(
            max(sceneDistance - 0.18, 0.0), FANTASY_FIREFLY_RANGE);
        float surfaceTraceStart = max(
            sceneDistance - 0.18 - traceDistance,
            0.0);
        float cameraGroundY = rayOrigin.y - 1.62;
        float cameraSurfaceSeparation = abs(
            cameraGroundY - groundReferenceY);
        float surfaceAnchoring = smoothstep(
            0.65, 3.25, cameraSurfaceSeparation);
        float traceStart = mix(
            0.0,
            surfaceTraceStart,
            surfaceAnchoring);
        float traceEnd = traceStart + traceDistance;
        float traceStep = traceDistance / float(FANTASY_FIREFLY_STEPS);

        float accumulatedGlow = 0.0;
        vec3 accumulatedColor = vec3(0.0);
        float habitatAttraction = smoothstep(
            0.34, 0.88, habitatAmount);
        float sourceRelease = clamp(releaseAmount, 0.0, 1.0);

        for (int i = 0; i < FANTASY_FIREFLY_STEPS; i++) {
            float probeDistance = traceStart
                + (float(i) + 0.5) * traceStep;
            vec3 probePosition = rayOrigin + rayDirection * probeDistance;
            vec3 cell = floor(probePosition / cellSize);
            vec3 randomValue = fantasy_firefly_hash33(cell);
            vec3 anchor = (cell + 0.18 + randomValue * 0.64) * cellSize;
            float playerDisturbance =
                fantasy_player_disturbance(anchor, rayOrigin);
            float fleeAmount = max(
                playerDisturbance, sourceRelease);
            float ambientSparsity =
                (1.0 - habitatAttraction) * 0.03;
            float localThreshold = FANTASY_FIREFLY_THRESHOLD
                + ambientSparsity
                - habitatAttraction * 0.20;
            if (randomValue.x < localThreshold) {
                continue;
            }

            float phase = fantasy_firefly_hash13(cell + 17.0) * 6.2831853;

            // Smooth fade factor & breathing pulse
            float pulsePersonality = fantasy_firefly_hash13(cell + 53.71);
            float pulseSpeed = mix(0.55, 1.15, randomValue.y);
            float pulsePhase = time * pulseSpeed + phase;
            float rawCycle = sin(pulsePhase);
            float fadeFactor = smoothstep(-0.65, 0.85, rawCycle);

            // Dynamic flight trajectory away as firefly fades out (never vanishes static in place)
            vec3 flightDir = normalize(vec3(
                cos(phase * 2.1 + randomValue.x * 3.14),
                0.35 + 0.35 * sin(phase * 1.7),
                sin(phase * 2.1 + randomValue.y * 3.14)
            ));
            float fadeDriftDistance = (1.0 - fadeFactor) * mix(1.6, 3.4, randomValue.z);

            // Two incommensurate curves create an organic hovering path.
            vec3 movement = vec3(
                sin(time * 0.73 + phase)
                    + 0.34 * sin(time * 1.31 + phase * 1.7),
                sin(time * 0.47 + phase * 1.3)
                    + 0.28 * cos(time * 1.09 + phase * 0.8),
                cos(time * 0.61 + phase * 0.7)
                    + 0.31 * sin(time * 1.17 + phase * 1.9)
            ) * vec3(0.32, 0.24, 0.32);

            movement += flightDir * fadeDriftDistance;

            float grassWindPhase = dot(anchor.xz, vec2(0.19, 0.13))
                + time * (0.43 + float(WIND_FORCE) * 0.16);
            vec2 grassWind = vec2(
                sin(grassWindPhase), cos(grassWindPhase * 0.83))
                * (0.065 + float(WIND_FORCE) * 0.022);
            movement.xz += grassWind;

            vec3 fleeDirection = anchor - rayOrigin;
            fleeDirection.y = abs(fleeDirection.y) * 0.25 + 0.35;
            fleeDirection = normalize(
                fleeDirection + vec3(0.0001, 0.0, 0.0001));
            float releaseAge = fract(
                time * (0.19 + randomValue.y * 0.08)
                + phase * 0.15915);
            float escapeDistance = mix(
                0.78, 2.35, smoothstep(0.0, 0.82, releaseAge));
            movement += fleeDirection * fleeAmount
                * escapeDistance * (0.84 + randomValue.z * 0.48);
            movement.y += fleeAmount
                * (0.30 + releaseAge * (0.78 + randomValue.y * 0.42));

            float orbitPhase = time * (0.31 + randomValue.y * 0.19)
                + phase * 1.73;
            movement.xz += vec2(cos(orbitPhase), sin(orbitPhase))
                * habitatAttraction * (0.11 + randomValue.z * 0.10);
            movement.y += sin(
                orbitPhase * 1.37 + randomValue.x * 4.0)
                * habitatAttraction * 0.08;
            vec3 bodyPosition = anchor + movement;

            float bodyAlong;
            float bodyDistance = fantasy_distance_to_ray(
                rayOrigin, rayDirection, bodyPosition, bodyAlong);

            float wingCycle = sin(time * (5.2 + randomValue.z * 2.4)
                + phase * 2.0);
            float wingSpread = 0.035 + 0.065 * abs(wingCycle);
            vec3 wingAxis = normalize(vec3(
                cos(phase * 1.7), 0.16 * wingCycle, sin(phase * 1.7)));
            vec3 leftWing = bodyPosition + wingAxis * wingSpread;
            vec3 rightWing = bodyPosition - wingAxis * wingSpread;

            float leftAlong;
            float rightAlong;
            float leftDistance = fantasy_distance_to_ray(
                rayOrigin, rayDirection, leftWing, leftAlong);
            float rightDistance = fantasy_distance_to_ray(
                rayOrigin, rayDirection, rightWing, rightAlong);

            float validDistance = step(
                max(0.35, traceStart), bodyAlong)
                * step(bodyAlong, traceEnd);
            // Anchor the swarm to the locally reconstructed terrain height.
            // The layer reaches roughly a medium/large tree canopy, but its
            // density is intentionally strongest in the first few blocks.
            float activeGroundY = mix(
                cameraGroundY,
                groundReferenceY,
                surfaceAnchoring);
            float heightAboveGround = bodyPosition.y - activeGroundY;
            float groundLayer = smoothstep(-1.5, 0.2, heightAboveGround)
                * (1.0 - smoothstep(14.0, 20.0, heightAboveGround));
            float distanceFromSurface = max(
                sceneDistance - bodyAlong,
                0.0);
            float rangeFade = 1.0 - smoothstep(
                FANTASY_FIREFLY_RANGE * 0.62,
                FANTASY_FIREFLY_RANGE,
                distanceFromSurface);
            float nearFade = smoothstep(0.35, 1.0, bodyAlong);

            // Dynamic individual size scale per firefly (small delicate motes to medium lights)
            float individualScale = mix(0.40, 1.00, randomValue.x * randomValue.y);
            float bodySharpness = mix(750.0, 260.0, individualScale);

            float body = exp(-bodyDistance * bodyDistance * bodySharpness) * individualScale * 1.35;
            float wingVisibility = 1.0 - smoothstep(7.0, 16.0, bodyAlong);
            float wings = (
                exp(-leftDistance * leftDistance * (bodySharpness * 1.6))
                + exp(-rightDistance * rightDistance * (bodySharpness * 1.6))
            ) * (0.18 + 0.26 * abs(wingCycle)) * wingVisibility * individualScale;
            float halo = exp(-bodyDistance * bodyDistance * (bodySharpness * 0.08)) * 0.15 * individualScale;

            float blinkFloor = mix(0.22, 0.38, pulsePersonality);
            float localLife = fantasy_firefly_visit(bodyPosition, time);
            float livingPulse = mix(blinkFloor, 1.0, fadeFactor)
                * mix(0.75, 1.15, localLife)
                * mix(1.0, 1.25, habitatAttraction);

            // Fleeing changes bodyPosition above, never light output.
            float rawGlow = (body + wings + halo)
                * validDistance * groundLayer * groundVisibility
                * rangeFade * nearFade * livingPulse;
            float glow = 1.0 - exp(-rawGlow * 1.50);

            vec3 creatureColor = mix(
                vec3(1.0, 0.62, 0.18),
                vec3(0.27, 1.0, 0.62),
                smoothstep(0.84, 0.97, randomValue.y));
            creatureColor = mix(
                creatureColor,
                vec3(0.55, 0.40, 1.0),
                smoothstep(0.986, 0.998, randomValue.z) * 0.42);
            creatureColor = mix(
                creatureColor,
                fantasy_firefly_life_color(bodyPosition),
                0.18 * localLife);

            accumulatedColor += creatureColor * glow;
            accumulatedGlow += glow;
        }

        float weatherVisibility = 1.0 - smoothstep(0.18, 0.92, rainAmount);
        float outdoorVisibility = mix(0.50, 1.0, skyLight);
        float habitatVisibility = mix(0.75, 1.0, smoothstep(0.05, 0.50, habitatAmount));
        vec3 swarmColor = accumulatedColor / max(accumulatedGlow, 0.0001);
        float swarmGlow = 1.0 - exp(-accumulatedGlow * 0.85);
        float visibleSwarm = swarmGlow * nightAmount
            * weatherVisibility * outdoorVisibility
            * habitatVisibility;

        // TAA receives this current-frame confidence separately from color.
        // It preserves small moving emitters without disabling antialiasing
        // for the scene or making their halos larger.
        reactiveMask = clamp(visibleSwarm * 1.35, 0.0, 1.0);
        return swarmColor * visibleSwarm * 1.30;
    #endif
}

#endif
