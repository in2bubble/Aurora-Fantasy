#ifdef UNKNOWN_DIM
    vec3 low_sky_color_rgb = fogColor;
    low_sky_color = rgb_to_xyz(low_sky_color_rgb);
#else
    #if COLOR_SCHEME == 8
    vec3 low_sky_color_rgb = day_blend(
            HORIZON_SUNSET_COLOR * day_blend(vec3(1.0), vec3(1.0, 1.5, 1.0), vec3(1.75)),
            HORIZON_DAY_COLOR,
            saturate(HORIZON_NIGHT_COLOR, 0.25)
        );

        low_sky_color_rgb = mix(
            low_sky_color_rgb,
            HORIZON_SKY_RAIN_COLOR * luma(low_sky_color_rgb),
            (rainStrength - 0.05)
        );

        low_sky_color = rgb_to_xyz(low_sky_color_rgb);
    #else
    vec3 low_sky_color_rgb = day_blend(
            HORIZON_SUNSET_COLOR,
            HORIZON_DAY_COLOR,
            HORIZON_NIGHT_COLOR
        );

        #if COLOR_SCHEME == 11
            low_sky_color_rgb = mix(
                low_sky_color_rgb,
                HORIZON_SKY_RAIN_COLOR * luma(low_sky_color_rgb) * 3.333,
                rainStrength
            );
        #else
            low_sky_color_rgb = mix(
                low_sky_color_rgb,
                HORIZON_SKY_RAIN_COLOR * luma(low_sky_color_rgb),
                rainStrength
            );
        #endif

    #endif

    // Keep a restrained remnant of the sunset hue beneath storm clouds. It is
    // luminance-preserving, so dusk gains colour without regaining daylight
    // exposure.
    float rainy_twilight_low = rainStrength
        * smoothstep(0.49, 0.545, day_moment)
        * (1.0 - smoothstep(0.64, 0.72, day_moment));
    float rainy_twilight_low_luma = max(luma(low_sky_color_rgb), 0.001);
    vec3 rainy_twilight_low_hue = HORIZON_SUNSET_COLOR
        / max(luma(HORIZON_SUNSET_COLOR), 0.001);
    low_sky_color_rgb = mix(
        low_sky_color_rgb,
        rainy_twilight_low_hue * rainy_twilight_low_luma,
        rainy_twilight_low * 0.28);

    float rainy_night_low = rainStrength * day_blend_float(0.0, 0.0, 1.0);
    // The horizon must not be brighter than the mid sky at midnight; the old
    // ascending floor created the detached green-screen halo around terrain.
    vec3 rainy_night_low_floor = vec3(0.012, 0.019, 0.030);
    low_sky_color_rgb = mix(
        low_sky_color_rgb,
        max(low_sky_color_rgb, rainy_night_low_floor),
        rainy_night_low * 0.62
    );
    low_sky_color = rgb_to_xyz(low_sky_color_rgb);
#endif

vec3 pure_low_sky_color_rgb = day_blend(
        HORIZON_SUNSET_COLOR,
        HORIZON_DAY_COLOR,
        HORIZON_NIGHT_COLOR
    );

    pure_low_sky_color_rgb = mix(
        pure_low_sky_color_rgb,
        HORIZON_SKY_RAIN_COLOR * luma(pure_low_sky_color_rgb) * day_blend_float(1.0, 1.0, 1.5),
        (rainStrength - 0.05)
    );

    float pure_rainy_night_low = rainStrength * day_blend_float(0.0, 0.0, 1.0);
    pure_low_sky_color_rgb = mix(
        pure_low_sky_color_rgb,
        max(pure_low_sky_color_rgb, vec3(0.012, 0.019, 0.030)),
        pure_rainy_night_low * 0.62
    );

    pure_low_sky_color = rgb_to_xyz(pure_low_sky_color_rgb);
