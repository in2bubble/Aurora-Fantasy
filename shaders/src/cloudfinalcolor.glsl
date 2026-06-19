
#if MC_VERSION < 12106
    vec3 fog_sky_sample = texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb;
    float fog_sky_valid = (max(max(fog_sky_sample.r, fog_sky_sample.g), fog_sky_sample.b) > 0.002 || day_mixer < 0.05) ? 1.0 : 0.0;
    fog_sky_sample = mix(skyColor, fog_sky_sample, fog_sky_valid);
    block_color.rgb =
        mix(
            block_color.rgb,
            fog_sky_sample,
            clamp(pow(gl_FogFragCoord / (far * 4), 1.5), 0.0, 1.0)
        );
#else
    vec3 fog_sky_sample = texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb;
    float fog_sky_valid = (max(max(fog_sky_sample.r, fog_sky_sample.g), fog_sky_sample.b) > 0.002 || day_mixer < 0.05) ? 1.0 : 0.0;
    fog_sky_sample = mix(skyColor, fog_sky_sample, fog_sky_valid);
    block_color.rgb =
        mix(
            block_color.rgb,
            fog_sky_sample,
            clamp(pow(gl_FogFragCoord / (2000.0), 1.5), 0.0, 1.0)
        );
#endif
