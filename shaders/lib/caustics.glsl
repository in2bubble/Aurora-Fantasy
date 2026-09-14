vec3 normal_waves(vec3 pos) {
    float speed = frameTimeCounter;

    // Rotation for natural wave flow
    float angle1 = 0.698;
    float s1 = sin(angle1);
    float c1 = cos(angle1);
    mat2 rot1 = mat2(c1, -s1, s1, c1);

    float angle2 = 1.047;
    float s2 = sin(angle2);
    float c2 = cos(angle2);
    mat2 rot2 = mat2(c2, -s2, s2, c2);

    vec2 base_coord = pos.xy - pos.z * 0.2;

    // Layer 1: Primary ocean swell
    vec2 swell_coord = base_coord * 0.06 + vec2(speed * 0.025, speed * 0.018);
    vec2 wave_1 = texture2D(noisetex, swell_coord).rg - 0.5;
    wave_1 *= 0.8;

    // Layer 2: Cross current
    vec2 cross_coord = rot1 * base_coord * 0.09 - vec2(speed * 0.03, speed * 0.012);
    vec2 wave_2 = texture2D(noisetex, cross_coord).rg - 0.5;
    wave_2 *= 0.65;

    // Layer 3: Surface ripples
    vec2 ripple_coord = rot2 * base_coord * 0.18 + vec2(speed * 0.05, -speed * 0.035);
    vec2 wave_3 = texture2D(noisetex, ripple_coord).rg - 0.5;
    wave_3 *= 0.5;

    // Layer 4: Micro shimmer
    vec2 micro_coord = base_coord * 0.35 + vec2(-speed * 0.07, speed * 0.04);
    vec2 wave_4 = texture2D(noisetex, micro_coord).rg - 0.5;
    wave_4 *= 0.3;

    // Layer 5: Flow distortion
    vec2 flow_coord = rot1 * base_coord * 0.04 + vec2(speed * 0.015, speed * 0.01);
    vec2 wave_5 = texture2D(noisetex, flow_coord).rg - 0.5;
    wave_5 *= 0.45;

    // Rain interaction
    float rain_ripple_boost = 1.0 + rainStrength * 1.5;
    float rain_swell_dampen = 1.0 - rainStrength * 0.3 * visible_sky;

    vec2 partial_wave = (wave_1 * rain_swell_dampen + wave_5 * rain_swell_dampen)
                      + (wave_2 + wave_3 * rain_ripple_boost + wave_4 * rain_ripple_boost);

    vec3 final_wave = vec3(
        partial_wave,
        WATER_TURBULENCE - (rainStrength * 0.4 * WATER_TURBULENCE * visible_sky)
    );

    return normalize(final_wave);
}