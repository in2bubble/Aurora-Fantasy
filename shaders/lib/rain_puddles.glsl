/* Aurora Fantasy - rain_puddles.glsl
Rain puddles, wet surface effects, and rain ripple animations.
*/

// --- Noise functions for puddle shape generation ---

float puddle_hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float puddle_noise(vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float a = puddle_hash(p);
    float b = puddle_hash(p + vec2(1.0, 0.0));
    float c = puddle_hash(p + vec2(0.0, 1.0));
    float d = puddle_hash(p + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float puddle_fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * puddle_noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// --- Puddle mask generation ---
// Returns 0.0 = no puddle, 1.0 = full puddle
float get_puddle_mask(vec3 worldPos, float upDot, float wetness, float rainStrength) {
    // Only form puddles on surfaces facing up
    float upFacing = smoothstep(0.7, 0.95, upDot);

    // Noise-based puddle shape
    vec2 puddleCoord = worldPos.xz * 0.15;
    float noise1 = puddle_fbm(puddleCoord);
    float noise2 = puddle_fbm(puddleCoord * 2.5 + vec2(43.0, 17.0));
    float puddleNoise = mix(noise1, noise2, 0.3);

    // Threshold based on coverage and rain intensity
    float rainFactor = max(wetness, rainStrength * 0.5);
    float threshold = 1.0 - (PUDDLE_COVERAGE * rainFactor);
    float puddle = smoothstep(threshold, threshold + 0.15, puddleNoise);

    // Edge softening for natural look
    float edge = smoothstep(threshold - 0.05, threshold + 0.25, puddleNoise);

    return puddle * upFacing * rainFactor;
}

// --- Wetness calculation ---
// Returns surface wetness factor (0.0 = dry, 1.0 = fully wet)
float get_surface_wetness(float upDot, float wetness, float rainStrength) {
    float upFacing = smoothstep(0.3, 0.9, upDot);
    float rainFactor = max(wetness * 0.8, rainStrength * 0.6);
    return upFacing * rainFactor;
}

// --- Rain ripple effect ---
// Creates animated concentric ripple circles on puddle surfaces
#ifdef RAIN_RIPPLES
vec2 get_rain_ripples(vec3 worldPos, float time) {
    vec2 rippleNormal = vec2(0.0);

    // Multiple ripple sources at different scales
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 coord = worldPos.xz * (1.5 + fi * 0.7);

        // Random ripple center positions (tiled)
        vec2 cell = floor(coord);
        vec2 frac_coord = fract(coord);

        // Hash for random timing offset per cell
        float cellHash = puddle_hash(cell + fi * 73.0);
        float rippleTime = time * (2.5 + fi * 0.5) + cellHash * 6.283;

        // Ripple animation cycle
        float ripplePhase = fract(rippleTime * 0.3);
        float rippleRadius = ripplePhase * 0.5;
        float rippleFade = 1.0 - ripplePhase;
        rippleFade *= rippleFade;

        // Distance from cell center
        vec2 center = vec2(puddle_hash(cell + vec2(fi, 0.0)), puddle_hash(cell + vec2(0.0, fi))) * 0.8 + 0.1;
        vec2 delta = frac_coord - center;
        float dist = length(delta);

        // Concentric ring shape
        float ring = sin((dist - rippleRadius) * 25.0) * exp(-dist * 6.0) * rippleFade;

        // Derivative for normal
        if (dist > 0.001) {
            rippleNormal += (delta / dist) * ring * (0.04 / (1.0 + fi * 0.5));
        }
    }

    return rippleNormal;
}
#endif

// --- Apply wet surface effect to block color ---
// Darkens the surface and increases specular appearance
vec3 apply_wetness(vec3 color, float wetnessFactor) {
    // Wet surfaces are darker (light absorption by water film)
    float darken = 1.0 - (WET_SURFACE_DARKEN * wetnessFactor);
    color *= darken;

    // Slightly increase saturation of wet surfaces
    float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(lum), color, 1.0 + wetnessFactor * 0.15);

    return color;
}

// --- Puddle reflection color (simplified sky reflection) ---
vec3 get_puddle_reflection(vec3 skyColor, vec3 lightColor, float puddle, float fresnel) {
    vec3 reflectColor = skyColor * 0.5 + lightColor * 0.1;
    return reflectColor * puddle * fresnel * PUDDLE_REFLECTIVITY;
}
