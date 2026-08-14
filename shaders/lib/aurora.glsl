#ifndef AURORA_GLSL
#define AURORA_GLSL

/* Aurora Fantasy - aurora.glsl
Simple noise-based aurora effect.
*/

float aurora_hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float aurora_noise(in vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);
    f = f*f*(3.0-2.0*f);
    float res = mix(mix( aurora_hash12(p), aurora_hash12(p + vec2(1.0, 0.0)), f.x),
                    mix( aurora_hash12(p + vec2(0.0, 1.0)), aurora_hash12(p + vec2(1.0, 1.0)), f.x), f.y);
    return res;
}

float aurora_fbm(vec2 p) {
    float f = 0.0;
    float w = 0.5;
    #if PROFILE_QUALITY == 1
        const int auroraNoiseOctaves = 3;
    #else
        const int auroraNoiseOctaves = 4;
    #endif
    for (int i = 0; i < auroraNoiseOctaves; i++) {
        f += w * aurora_noise(p);
        p *= 2.0;
        w *= 0.5;
    }
    return f;
}

vec3 getAurora(vec3 viewDir, vec3 sunPos) {
    // 1. Night Check
    float nightFactor = day_blend_float(0.0, 0.0, 1.0);
    if (nightFactor < 0.01) return vec3(0.0);

    // Rain clouds veil almost all aurora energy.  Keep a tiny residual glow so
    // transitions into and out of rain remain natural instead of popping.
    float rainVeil = smoothstep(0.05, 0.85, rainStrength);
    float weatherVisibility = mix(1.0, 0.055, rainVeil);

    // 2. Coordinate System
    // Bounded horizon projection preserves a continuous pattern without a
    // divide-by-zero angle. Extended-distance rendering uses a wider floor to
    // keep the pattern calm across the enlarged horizon.
    float raw_denom = viewDir.y + 0.15;
    #ifdef DISTANT_RENDER_MOD
        const float horizon_floor = 0.2;
    #else
        const float horizon_floor = 0.05;
    #endif
    float denom = horizon_floor
        + raw_denom * raw_denom / (abs(raw_denom) + horizon_floor);
    vec2 p = viewDir.xz / denom;
    
    vec3 weightedColor = vec3(0.0);
    float totalEnergy = 0.0;
    float time = persistentTimeSeconds * 0.05;

    // Horizontal advection keeps ribbon altitude stable.
    p.x += time * 0.1;

    // Balanced renders 4 smooth ribbons; Extreme renders 5 multi-chromatic ribbons with 4 noise octaves.
    #if PROFILE_QUALITY == 1
        const float auroraRibbonCount = 4.0;
    #else
        const float auroraRibbonCount = 5.0;
    #endif
    for (float i = 1.0; i <= auroraRibbonCount; i++) {
        
        float seed = i * 17.0; // Prime number
        
        // A distinct deterministic phase keeps the ribbons decorrelated.
        float initial_scatter = seed * 437.0; 
        
        // Motion
        // Added 'i * 0.2' to make layers move at different speeds (Parallax)
        float drift = initial_scatter + time * (0.2 + 0.1 * i); 
        
        // --- WAVE GEOMETRY ---
        // Slower wave frequency for majesty
        float wave_center = sin(p.x * 0.3 + drift) * 1.5; 
        wave_center += sin(p.x * 1.2 - drift * 0.5) * 0.3;
        
        float d = abs(p.y - wave_center);
        
        // --- VISUALS ---
        float width = 1.0 + 0.4 * cos(seed + time * 0.5);
        // A defined ribbon core plus a broad low-energy veil lets the gradients
        // wash naturally across the sky without becoming a flat luminous slab.
        float ribbonCore = exp(-d * 2.25 / width);
        float ribbonVeil = exp(-d * 0.62 / width);
        float noise = aurora_fbm(p * 0.5 + vec2(drift, i));
        float ribbonTexture = smoothstep(0.0, 1.0, noise + 0.4);
        float glow = (ribbonCore * 0.76 + ribbonVeil * 0.07)
            * mix(0.62, 1.0, ribbonTexture);
        
        // Keep every ribbon present while its intensity evolves independently.
        float cycle = sin(time * 0.2 + seed);
        
        // Map the cycle to a nonzero energy range.
        float life = 0.3 + 0.7 * (cycle * 0.5 + 0.5); 
        
        float alpha = smoothstep(0.0, 1.0, life); 

        // --- COLOR ---
        // Each ribbon owns three carefully related palettes. Two independent,
        // slow cycles keep the selected endpoints evolving without making all
        // ribbons refresh at the same moment or return as one repeated pattern.
        vec3 colA0, colB0, colA1, colB1, colA2, colB2;
        if (i == 1.0) {
            colA0 = vec3(0.08, 0.95, 0.62); colB0 = vec3(0.04, 0.62, 0.98);
            colA1 = vec3(0.05, 0.88, 0.84); colB1 = vec3(0.12, 0.45, 0.98);
            colA2 = vec3(0.20, 1.00, 0.72); colB2 = vec3(0.32, 0.40, 1.00);
        } else if (i == 2.0) {
            colA0 = vec3(0.10, 0.55, 1.00); colB0 = vec3(0.55, 0.22, 1.00);
            colA1 = vec3(0.04, 0.78, 1.00); colB1 = vec3(0.86, 0.24, 0.96);
            colA2 = vec3(0.30, 0.32, 1.00); colB2 = vec3(0.95, 0.28, 0.78);
        } else if (i == 3.0) {
            colA0 = vec3(0.06, 0.92, 0.45); colB0 = vec3(0.04, 0.84, 0.86);
            colA1 = vec3(0.18, 1.00, 0.68); colB1 = vec3(0.10, 0.58, 1.00);
            colA2 = vec3(0.02, 0.72, 0.68); colB2 = vec3(0.16, 0.38, 0.96);
        } else if (i == 4.0) {
            colA0 = vec3(0.58, 0.18, 1.00); colB0 = vec3(0.96, 0.24, 0.68);
            colA1 = vec3(0.38, 0.24, 0.95); colB1 = vec3(0.88, 0.18, 0.92);
            colA2 = vec3(0.70, 0.36, 1.00); colB2 = vec3(0.98, 0.34, 0.58);
        } else {
            colA0 = vec3(0.02, 0.90, 0.92); colB0 = vec3(0.72, 0.34, 1.00);
            colA1 = vec3(0.10, 0.52, 1.00); colB1 = vec3(0.94, 0.28, 0.74);
            colA2 = vec3(0.14, 0.96, 0.72); colB2 = vec3(0.56, 0.24, 0.96);
        }

        float paletteCycle = 0.5 - 0.5 * cos(time * 0.33 + seed * 0.17);
        float paletteDrift = 0.5 - 0.5 * cos(
            time * 0.21 - seed * 0.11 + sin(time * 0.13 + seed) * 0.65
        );
        vec3 colA = mix(mix(colA0, colA1, paletteCycle), colA2,
            paletteDrift * 0.46);
        vec3 colB = mix(mix(colB0, colB1, paletteDrift), colB2,
            paletteCycle * 0.42);
        
        // A slow cosine-eased phase bends gently along the ribbon. The FBM term
        // adds organic color movement without creating hard palette seams.
        float colorSignal = p.x * 0.15 + p.y * 0.085
            + wave_center * 0.12 + drift * 0.55 + noise * 1.10
            + time * (0.055 + i * 0.009);
        float colorPhase = 0.5 - 0.5 * cos(colorSignal);
        vec3 layerColor = mix(colA, colB, colorPhase);
        
        // --- ACCUMULATE ---
        // Accumulate premultiplied color and energy separately. Normalizing
        // the hue before restoring luminance gives overlapping ribbons one
        // continuous blend instead of stacking visible color contours.
        float layerEnergy = glow * alpha;
        weightedColor += layerColor * layerEnergy;
        totalEnergy += layerEnergy;
    }
    
    // 4. Horizon Fade
    #ifdef DISTANT_RENDER_MOD
        // Extended far below horizon so start/end points are hidden behind terrain
        // even with extended render distance mods like Distant Horizons
        float horizonFade = smoothstep(-0.15, 0.01, viewDir.y);
    #else
        float horizonFade = smoothstep(0.0, 0.1, viewDir.y);
    #endif
    
    // Preserve the original soft-additive response at low intensity while
    // rolling off overlaps smoothly before they clip in the post-process.
    vec3 blendedColor = weightedColor / max(totalEnergy, 0.0001);
    float softEnergy = 1.0 - exp(-totalEnergy * 0.52);

    // Brightness tuned per quality profile for vividness & bloom
    #if PROFILE_QUALITY == 1
        float brightness = 0.58;
    #else
        float brightness = 0.70;
    #endif
    
    return blendedColor * softEnergy * horizonFade * nightFactor
        * brightness * weatherVisibility;
}

#endif // AURORA_GLSL
