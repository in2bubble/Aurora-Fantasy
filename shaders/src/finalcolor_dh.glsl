#if defined DH_WATER
    if(isEyeInWater == 0) {
        vec3 fog_texture = texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb;
        float fog_valid = (max(max(fog_texture.r, fog_texture.g), fog_texture.b) > 0.002 || light_mix < 0.05) ? 1.0 : 0.0;
        fog_texture = mix(fogColor, fog_texture, fog_valid);
        block_color.rgb = mix(block_color.rgb, fog_texture, fog_adj);
    }
#elif defined NETHER
    #if NETHER_FOG_DISTANCE == 1
        block_color.rgb = mix(fogColor * 0.1, vec3(1.0), 0.04);
    #else
        block_color.rgb = mix(block_color.rgb, mix(fogColor * 0.1, vec3(1.0), 0.04), fog_adj);
    #endif
#elif defined THE_END
    block_color.rgb = mix(block_color.rgb, texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb * 1.1 * vec3(1.2, 1.3, 1.2), fog_adj);
#else
    vec3 fog_texture = texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb;
    float fog_valid = (max(max(fog_texture.r, fog_texture.g), fog_texture.b) > 0.002 || light_mix < 0.05) ? 1.0 : 0.0;
    fog_texture = mix(fogColor, fog_texture, fog_valid);
    block_color.rgb = mix(block_color.rgb, fog_texture, fog_adj);
#endif
