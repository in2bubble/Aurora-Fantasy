/* Aurora Fantasy - Clean Puddle SSR
 * Deterministic screen-space ray tracing with no random roughness jitter.
 */
#ifndef AURORA_FANTASY_REFLECTIONS
#define AURORA_FANTASY_REFLECTIONS

vec3 fantasyHomogeneous(vec4 p) {
    return p.xyz / p.w;
}

vec3 fantasyScreenToNdc(vec3 p) {
    return p * 2.0 - 1.0;
}

vec3 fantasyNdcToScreen(vec3 p) {
    return p * 0.5 + 0.5;
}

vec3 fantasyScreenToView(vec2 uv, float depth) {
    return fantasyHomogeneous(gbufferProjectionInverse
        * vec4(fantasyScreenToNdc(vec3(uv, depth)), 1.0));
}

vec3 fantasyViewToScreenPosition(vec3 viewPos) {
    vec3 ndc = fantasyHomogeneous(gbufferProjection * vec4(viewPos, 1.0));
    return fantasyNdcToScreen(ndc);
}

vec2 fantasyViewToScreen(vec3 viewPos) {
    return fantasyViewToScreenPosition(viewPos).xy;
}

float fantasyReflectionEdgeFade(vec2 uv) {
    vec2 edge = smoothstep(vec2(0.0), vec2(0.075), uv)
              * smoothstep(vec2(0.0), vec2(0.075), vec2(1.0) - uv);
    return edge.x * edge.y;
}

float fantasyReflectionDepth(vec2 uv, sampler2D fullDepth,
                             sampler2D handlessDepth,
                             bool excludeFirstPersonHand) {
    // depthtex0 contains every visible surface, including the local player in
    // third person. depthtex2 deliberately omits translucent and hand geometry.
    // Use the latter only while a first-person hand can actually be present.
    return excludeFirstPersonHand
        ? texture2D(handlessDepth, uv).r
        : texture2D(fullDepth, uv).r;
}

vec4 traceFantasyReflection(vec3 viewPos, vec3 viewNormal,
                            sampler2D sceneColor, sampler2D fullDepth,
                            sampler2D handlessDepth,
                            bool excludeFirstPersonHand) {
    vec3 viewDirection = normalize(viewPos);
    vec3 rayDirection = normalize(reflect(viewDirection, viewNormal));

    // Match Aurora's proven real-water traversal: exponential exploration finds
    // nearby and tall geometry within the same budget, then the remaining steps
    // halve the interval around the first depth crossing. The former linear
    // puddle trace regularly stepped over buildings at shallow camera angles.
    vec3 currentMarch = viewPos;
    vec3 previousMarch = viewPos;
    vec3 marchIncrement = rayDirection * 0.10;
    vec3 marchScreen = fantasyViewToScreenPosition(viewPos);
    vec3 previousMarchScreen = marchScreen;
    float previousSceneDepth = marchScreen.z;
    float sceneDepth = 1.0;
    float depthDifference = 1.0;
    float maximumTravel = min(128.0, max(24.0, -viewPos.z * 1.85));
    float maximumExponent = log2(maximumTravel + 1.0);
    bool refinement = false;
    bool hiddenSurface = false;
    bool crossedHiddenSurface = false;
    bool validHit = false;

    for (int i = 0; i < SSR_MAX_STEPS; i++) {
        previousMarchScreen = marchScreen;
        if (refinement) {
            marchIncrement *= 0.5;
            currentMarch += marchIncrement * sign(depthDifference);
        } else {
            previousMarch = currentMarch;
            float marchExponent = (float(i) + 0.32)
                * (maximumExponent / float(SSR_MAX_STEPS - 1));
            currentMarch = viewPos + rayDirection
                * (exp2(marchExponent) - 1.0);
            marchIncrement = currentMarch - previousMarch;
        }

        marchScreen = fantasyViewToScreenPosition(currentMarch);
        if (any(lessThanEqual(marchScreen.xy, vec2(0.001)))
                || any(greaterThanEqual(marchScreen.xy, vec2(0.999)))
                || marchScreen.z <= 0.0 || marchScreen.z >= 0.99995) {
            break;
        }

        sceneDepth = fantasyReflectionDepth(
            marchScreen.xy, fullDepth, handlessDepth,
            excludeFirstPersonHand);
        depthDifference = sceneDepth - marchScreen.z;

        if (depthDifference < 0.0
                && abs(sceneDepth - previousSceneDepth)
                    > abs(marchScreen.z - previousMarchScreen.z)) {
            hiddenSurface = true;
            crossedHiddenSurface = true;
        } else if (depthDifference > 0.0) {
            hiddenSurface = false;
        }

        if (!refinement && depthDifference < 0.0 && !hiddenSurface) {
            refinement = true;
            validHit = true;
        }
        previousSceneDepth = sceneDepth;
    }

    if (!validHit || sceneDepth >= 0.99995) return vec4(0.0);
    vec2 hitUV = clamp(marchScreen.xy, vec2(0.001), vec2(0.999));
    float edgeFade = fantasyReflectionEdgeFade(hitUV);
    float travelledDistance = length(currentMarch - viewPos);
    float distanceFade = 1.0 - smoothstep(
        maximumTravel * 0.58, maximumTravel, travelledDistance);
    float visibilityConfidence = crossedHiddenSurface ? 0.72 : 1.0;
    vec3 reflectedScene = texture2D(sceneColor, hitUV).rgb;
    float luminance = dot(reflectedScene, vec3(0.2126, 0.7152, 0.0722));
    // Preserve the reflected world's real palette. A tiny cool bias binds it
    // to Aurora's storm lighting without the former cartoon-blue cast.
    reflectedScene = mix(vec3(luminance), reflectedScene, 1.04);
    reflectedScene *= vec3(0.985, 1.0, 1.02);
    return vec4(
        reflectedScene,
        edgeFade * distanceFade * visibilityConfidence);
}

#endif
