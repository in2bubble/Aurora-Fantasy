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
    float time = frameTimeCounter * 0.05;

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
        float glow = exp(-d * 2.0 / width); 
        
        float noise = aurora_fbm(p * 0.5 + vec2(drift, i));
        glow *= smoothstep(0.0, 1.0, noise + 0.4); 
        
        // Keep every ribbon present while its intensity evolves independently.
        float cycle = sin(time * 0.2 + seed);
        
        // Map the cycle to a nonzero energy range.
        float life = 0.3 + 0.7 * (cycle * 0.5 + 0.5); 
        
        float alpha = smoothstep(0.0, 1.0, life); 

        // --- COLOR ---
        vec3 colA, colB;
        if (i == 1.0)      { colA = vec3(0.0, 1.0, 0.7); colB = vec3(0.0, 0.2, 1.0); } 
        else if (i == 2.0) { colA = vec3(0.8, 0.0, 1.0); colB = vec3(1.0, 0.5, 0.0); } 
        else if (i == 3.0) { colA = vec3(0.0, 0.8, 0.2); colB = vec3(0.0, 0.5, 0.8); } 
        else if (i == 4.0) { colA = vec3(1.0, 0.2, 0.4); colB = vec3(0.6, 0.0, 0.8); }
        else               { colA = vec3(0.0, 1.0, 0.9); colB = vec3(1.0, 0.7, 0.2); } 
        
        // A cosine-eased ping-pong has zero slope at both palette endpoints,
        // so neighboring ribbons cannot expose a hard color transition.
        float colorPhase = 0.5 - 0.5 * cos(p.x * 0.2 + drift + 1.5707963268);
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
    float softEnergy = 1.0 - exp(-totalEnergy * 0.6);

    // Brightness tuned per quality profile for vividness & bloom
    #if PROFILE_QUALITY == 1
        float brightness = 0.72; 
    #else
        float brightness = 0.88; 
    #endif
    
    // Desaturating the small remnant avoids vivid green/purple bands bleeding
    // through a quiet overcast night.
    blendedColor = mix(blendedColor, vec3(luma(blendedColor)), rainVeil * 0.72);

    return blendedColor * softEnergy * horizonFade * nightFactor
        * brightness * weatherVisibility;
}

#endif // AURORA_GLSL
