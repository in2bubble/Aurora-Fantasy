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
    for (int i = 0; i < 3; i++) {
        f += w * aurora_noise(p);
        p *= 2.0;
        w *= 0.5;
    }
    return f;
}

// Aurora - Wavy Curtain Style

// Aurora - Cloudy/Nebula Style (Restored & Refined)

// Aurora - Fluid/Flowing Nebula Style

// Aurora - Roaming Nebula (Living Sky)

// Aurora - Artistic Scatter (Start-Fixed & Permanent)

vec3 getAurora(vec3 viewDir, vec3 sunPos) {
    // 1. Night Check
    float nightFactor = day_blend_float(0.0, 0.0, 1.0);
    if (nightFactor < 0.01) return vec3(0.0);

    // 2. Coordinate System
    #ifdef DISTANT_RENDER_MOD
        // Smooth transition near horizon: original projection above, gradually
        // slows down the coordinate expansion below, so the aurora pattern
        // continues naturally downward without stretching or hard cutoff
        float raw_denom = viewDir.y + 0.15;
        float denom = 0.2 + raw_denom * raw_denom / (raw_denom + 0.2);
        vec2 p = viewDir.xz / denom; 
    #else
        vec2 p = viewDir.xz / (viewDir.y + 0.15); 
    #endif
    
    vec3 finalColor = vec3(0.0);
    // Increased speed (0.02 -> 0.05) for better visibility
    // Added a constant large offset (1000.0) to avoid "Time=0" sync issues
    float time = (frameTimeCounter * 0.05) + 1000.0; 

    // GLOBAL SCROLL (User Request: "Move across the sky")
    // We shift the entire coordinate system horizontally
    // CRITICAL FIX: Do NOT Shift Y, or the aurora drifts away from the view area and vanishes!
    p.x += time * 0.1;

    // 3. Loop: 4 Distinct Ribbons
    for (float i = 1.0; i <= 4.0; i++) { 
        
        float seed = i * 17.0; // Prime number
        
        // --- INSTANT SCATTER ---
        // Large offset per layer
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
        
        // --- LIFECYCLE (Fix Disappearing) ---
        // Range -1 to +1
        float cycle = sin(time * 0.2 + seed);
        
        // Map to 0.3 to 1.0 (NEVER go below 0.3)
        // This solves "Disappears forever/Reduces"
        float life = 0.3 + 0.7 * (cycle * 0.5 + 0.5); 
        
        float alpha = smoothstep(0.0, 1.0, life); 

        // --- COLOR ---
        vec3 colA, colB;
        if (i == 1.0)      { colA = vec3(0.0, 1.0, 0.7); colB = vec3(0.0, 0.2, 1.0); } 
        else if (i == 2.0) { colA = vec3(0.8, 0.0, 1.0); colB = vec3(1.0, 0.5, 0.0); } 
        else if (i == 3.0) { colA = vec3(0.0, 0.8, 0.2); colB = vec3(0.0, 0.5, 0.8); } 
        else               { colA = vec3(1.0, 0.2, 0.4); colB = vec3(0.6, 0.0, 0.8); } 
        
        // Color mix
        vec3 layerColor = mix(colA, colB, 0.5 + 0.5 * sin(p.x * 0.2 + drift));
        
        // --- ACCUMULATE ---
        // Soft additive blending
        finalColor += layerColor * glow * alpha * 0.6; 
    }
    
    // 4. Horizon Fade
    #ifdef DISTANT_RENDER_MOD
        // Extended far below horizon so start/end points are hidden behind terrain
        // even with extended render distance mods like Distant Horizons
        float horizonFade = smoothstep(-0.15, 0.01, viewDir.y);
    #else
        float horizonFade = smoothstep(0.0, 0.1, viewDir.y);
    #endif
    
    // Brightness
    float brightness = 0.6; 
    
    return finalColor * horizonFade * nightFactor * brightness; 
}
