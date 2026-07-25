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

    float rainy_night_low = rainStrength * day_blend_float(0.0, 0.0, 1.0);
    vec3 rainy_night_low_floor = vec3(0.052, 0.074, 0.108);
    low_sky_color_rgb = mix(
        low_sky_color_rgb,
        max(low_sky_color_rgb, rainy_night_low_floor),
        rainy_night_low * 0.88
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
        max(pure_low_sky_color_rgb, vec3(0.052, 0.074, 0.108)),
        pure_rainy_night_low * 0.88
    );

    pure_low_sky_color = rgb_to_xyz(pure_low_sky_color_rgb);
