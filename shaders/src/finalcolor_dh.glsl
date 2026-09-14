#if defined THE_END
    // The End prepare pass writes its full-resolution background directly to
    // colortex1. Use the same deterministic End color for all DH geometry,
    // including DH water, without requiring the dimension's absent fogColor.
    block_color.rgb = mix(
        block_color.rgb,
        vec3(0.08, 0.06, 0.12) * 1.1 * vec3(1.2, 1.3, 1.2),
        fog_adj
    );
#elif defined DH_WATER
    if(isEyeInWater == 0) {
        vec3 fog_texture = texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb;
        float fog_valid = (max(max(fog_texture.r, fog_texture.g), fog_texture.b) > 0.002 || light_mix < 0.05) ? 1.0 : 0.0;
        fog_texture = mix(fogColor, fog_texture, fog_valid);
        // Keep bright cloud samples from bleaching Distant Horizons terrain.
        fog_texture /= 1.0 + fog_texture * 0.45;
        float cinematic_rain_haze = smoothstep(0.08, 0.92, rainStrength);
        // DH terrain's minimal fragment path has no world-time helpers; its
        // light mix is the reliable day/night signal (near zero at night).
        float rainy_night = 1.0 - smoothstep(0.10, 0.55, light_mix);
        vec3 rain_haze_tint = mix(vec3(0.37, 0.46, 0.52),
            vec3(0.018, 0.042, 0.085), rainy_night);
        fog_texture = mix(fog_texture,
            mix(fog_texture, rain_haze_tint, 0.32),
            cinematic_rain_haze);
        fog_texture = mix(fog_texture,
            mix(fog_texture, rain_haze_tint, 0.72),
            cinematic_rain_haze * rainy_night);
        block_color.rgb = mix(block_color.rgb, fog_texture,
            min(fog_adj * mix(1.0, mix(1.18, 0.82, rainy_night), cinematic_rain_haze),
                mix(0.72, mix(0.86, 0.64, rainy_night), cinematic_rain_haze)));
    }
#elif defined NETHER
    #if NETHER_FOG_DISTANCE == 1
        block_color.rgb = mix(fogColor * 0.1, vec3(1.0), 0.04);
    #else
        block_color.rgb = mix(block_color.rgb, mix(fogColor * 0.1, vec3(1.0), 0.04), fog_adj);
    #endif
#else
    vec3 fog_texture = texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb;
    float fog_valid = (max(max(fog_texture.r, fog_texture.g), fog_texture.b) > 0.002 || light_mix < 0.05) ? 1.0 : 0.0;
    fog_texture = mix(fogColor, fog_texture, fog_valid);
    // Match the regular terrain fog: soft, sky-tinted, and never opaque white.
    fog_texture /= 1.0 + fog_texture * 0.45;
    float cinematic_rain_haze = smoothstep(0.08, 0.92, rainStrength);
    // See the DH water branch above: derive the night amount from light_mix
    // so this file also compiles in the pared-down DH terrain program.
    float rainy_night = 1.0 - smoothstep(0.10, 0.55, light_mix);
    vec3 rain_haze_tint = mix(vec3(0.37, 0.46, 0.52),
        vec3(0.018, 0.042, 0.085), rainy_night);
    fog_texture = mix(fog_texture,
        mix(fog_texture, rain_haze_tint, 0.32),
        cinematic_rain_haze);
    fog_texture = mix(fog_texture,
        mix(fog_texture, rain_haze_tint, 0.72),
        cinematic_rain_haze * rainy_night);
    block_color.rgb = mix(block_color.rgb, fog_texture,
        min(fog_adj * mix(1.0, mix(1.18, 0.82, rainy_night), cinematic_rain_haze),
            mix(0.72, mix(0.86, 0.64, rainy_night), cinematic_rain_haze)));
#endif
