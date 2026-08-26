/* Aurora Fantasy - Texture-driven Rain
 *
 * Minecraft already supplies a sparse, animated rain silhouette on real
 * weather geometry. Keep that spatial motion and use procedural noise only
 * to vary showers; generating the silhouette from noise makes it look like a
 * stationary screen overlay.
 */
#ifndef AURORA_FANTASY_RAIN
#define AURORA_FANTASY_RAIN

uniform sampler2D gtexture;

const vec2 FANTASY_RAIN_TEXEL = vec2(1.0 / 64.0, 1.0 / 256.0);

float fantasyRainHash(vec2 value) {
    return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

float fantasyRainNoise(vec2 value) {
    vec2 cell = floor(value);
    vec2 local = fract(value);
    local = local * local * (3.0 - 2.0 * local);
    float a = fantasyRainHash(cell);
    float b = fantasyRainHash(cell + vec2(1.0, 0.0));
    float c = fantasyRainHash(cell + vec2(0.0, 1.0));
    float d = fantasyRainHash(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

/* Filter the real 64x256 rain texture with a sub-pixel horizontal shoulder.
 * The texture's own bilinear filtering keeps thin drops stable under TAA,
 * while lightly weighted vertical samples extend the head and tail without
 * turning a drop into a wide block.
 */
void sampleFantasyRainDrop(vec2 uv, float widthScale,
                           out float body, out float core,
                           out float rim) {
    vec2 offset1 = vec2(FANTASY_RAIN_TEXEL.x * widthScale, 0.0);
    vec2 lengthOffset = vec2(0.0, FANTASY_RAIN_TEXEL.y * 2.35);

    float center = texture2D(gtexture, uv).a;
    float endExtension = max(texture2D(gtexture, uv - lengthOffset).a,
                             texture2D(gtexture, uv + lengthOffset).a);
    float shoulder = max(texture2D(gtexture, uv - offset1).a,
                         texture2D(gtexture, uv + offset1).a);

    float elongated = max(center, endExtension * 0.64);
    float expanded = max(elongated, shoulder * 0.10);
    body = smoothstep(0.095, 0.70, expanded);
    core = smoothstep(0.28, 0.94,
                      max(elongated * 0.92, shoulder * 0.08));
    rim = clamp(body - core * 0.58, 0.0, 1.0);
}

void getFantasyRain(vec2 texUV, vec2 worldXZ, float nightAmount,
                    float viewDistance, out float rainMask,
                    out float coreMask, out float edgeMask) {
    float time = persistentTimeSeconds;

    // Two non-periodic, slowly travelling fields vary only the amount of the
    // secondary shower. The foreground rain remains present at full strength,
    // eliminating the visible breathing/fading cycle.
    float broadShower = fantasyRainNoise(worldXZ * 0.012
        + vec2(time * 0.008, time * 0.005));
    float localShower = fantasyRainNoise(worldXZ * 0.031
        + vec2(-time * 0.014, time * 0.011) + vec2(17.3, 41.7));
    float showerVariation = smoothstep(0.08, 0.92,
        broadShower * 0.74 + localShower * 0.26);
    float steadyStrength = mix(0.97, 1.015, showerVariation);

    // The game already scrolls texUV. These unequal offsets prevent the two
    // layers from sharing a cadence and add modest wind drift in texture
    // space. They do not lock to screen coordinates.
    // Slower vertical UV scaling lengthens each real streak by about 11%
    // without drawing a synthetic straight segment.
    vec2 frontUV = vec2(texUV.x, texUV.y * 0.90);
    frontUV += vec2(time * 0.0094, time * 0.0355);

    vec2 backUV = texUV * vec2(1.13, 0.84) + vec2(0.371, 0.217);
    backUV += vec2(time * 0.0064, time * 0.0550);

    float frontBody;
    float frontCore;
    float frontRim;
    sampleFantasyRainDrop(frontUV, 0.24,
        frontBody, frontCore, frontRim);

    float backBody;
    float backCore;
    float backRim;
    sampleFantasyRainDrop(backUV, 0.20,
        backBody, backCore, backRim);

    // Strong, readable foreground drops plus a restrained secondary shower.
    // The secondary layer fades sooner so it cannot become a fine grey veil.
    float backDistance = 1.0 - smoothstep(22.0, 52.0, viewDistance);
    float backWeight = mix(0.080, 0.115, nightAmount)
                     * mix(0.90, 1.10, showerVariation)
                     * backDistance;

    rainMask = clamp(frontBody * 0.88
                   + backBody * backWeight, 0.0, 1.0);
    coreMask = clamp(frontCore * 0.88
                   + backCore * backWeight * 0.70, 0.0, 1.0);
    edgeMask = clamp(frontRim * 0.72
                   + backRim * backWeight * 0.56, 0.0, 1.0);

    float distanceFade = mix(1.0, 0.68,
        smoothstep(18.0, 62.0, viewDistance));
    rainMask *= distanceFade * steadyStrength;
    coreMask *= distanceFade * steadyStrength;
    edgeMask *= distanceFade * steadyStrength;
}

#endif
