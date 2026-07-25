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

vec2 fantasyViewToScreen(vec3 viewPos) {
    vec3 ndc = fantasyHomogeneous(gbufferProjection * vec4(viewPos, 1.0));
    return fantasyNdcToScreen(ndc).xy;
}

float fantasyReflectionEdgeFade(vec2 uv) {
    vec2 edge = smoothstep(vec2(0.0), vec2(0.075), uv)
              * smoothstep(vec2(0.0), vec2(0.075), vec2(1.0) - uv);
    return edge.x * edge.y;
}

vec4 traceFantasyReflection(vec3 viewPos, vec3 viewNormal,
                            sampler2D sceneColor, sampler2D sceneDepth) {
    vec3 viewDirection = normalize(viewPos);
    vec3 rayDirection = normalize(reflect(viewDirection, viewNormal));
    if (rayDirection.z >= -0.015) return vec4(0.0);

    float travel = 0.35;
    float previousTravel = travel;
    float maxTravel = min(96.0, max(18.0, -viewPos.z * 1.35));
    vec2 hitUV = vec2(0.0);
    bool hit = false;

    for (int i = 0; i < SSR_MAX_STEPS; i++) {
        vec3 rayPosition = viewPos + rayDirection * travel;
        vec2 uv = fantasyViewToScreen(rayPosition);
        if (any(lessThanEqual(uv, vec2(0.001))) || any(greaterThanEqual(uv, vec2(0.999)))) break;

        float sampledDepth = texture2D(sceneDepth, uv).r;
        if (sampledDepth < 0.99995) {
            vec3 sampledPosition = fantasyScreenToView(uv, sampledDepth);
            float separation = rayPosition.z - sampledPosition.z;
            float thickness = mix(0.12, 0.80, clamp((-rayPosition.z) / far, 0.0, 1.0));

            if (separation <= 0.0 && separation > -thickness * 5.0) {
                float low = previousTravel;
                float high = travel;
                for (int j = 0; j < SSR_BINARY_STEPS; j++) {
                    float middle = (low + high) * 0.5;
                    vec3 middlePosition = viewPos + rayDirection * middle;
                    vec2 middleUV = fantasyViewToScreen(middlePosition);
                    float middleDepth = texture2D(sceneDepth, middleUV).r;
                    vec3 scenePosition = fantasyScreenToView(middleUV, middleDepth);
                    if (middlePosition.z > scenePosition.z) low = middle;
                    else high = middle;
                    hitUV = middleUV;
                }
                hit = true;
                travel = high;
                break;
            }
        }

        previousTravel = travel;
        float adaptiveStep = mix(0.42, SSR_STEP_SIZE, clamp(travel / maxTravel, 0.0, 1.0));
        travel += adaptiveStep;
        if (travel > maxTravel) break;
    }

    if (!hit) return vec4(0.0);
    float edgeFade = fantasyReflectionEdgeFade(hitUV);
    float distanceFade = 1.0 - smoothstep(maxTravel * 0.48, maxTravel, travel);
    vec3 reflectedScene = texture2D(sceneColor, hitUV).rgb;
    float luminance = dot(reflectedScene, vec3(0.2126, 0.7152, 0.0722));
    // Preserve the reflected world's real palette. A tiny cool bias binds it
    // to Aurora's storm lighting without the former cartoon-blue cast.
    reflectedScene = mix(vec3(luminance), reflectedScene, 1.04);
    reflectedScene *= vec3(0.985, 1.0, 1.02);
    return vec4(reflectedScene, edgeFade * distanceFade);
}

#endif
