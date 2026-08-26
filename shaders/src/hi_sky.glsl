#ifdef UNKNOWN_DIM
    vec3 hi_sky_color_rgb = skyColor;
    hi_sky_color = rgb_to_xyz(hi_sky_color_rgb);
#else
    #if COLOR_SCHEME == 8
    vec3 hi_sky_color_rgb = day_blend(
            saturate(ZENITH_SUNSET_COLOR, day_blend_float_lgcy(1.0, 1.0, 1.5)) * day_blend(vec3(1.0), vec3(1.0), vec3(1.6, 1.1, 1.0) * 0.5),
            ZENITH_DAY_COLOR,
            saturate(ZENITH_NIGHT_COLOR, 0.25) * day_blend_float_lgcy(1.0, 1.0, 1.25)
        );

        hi_sky_color_rgb = mix(
            hi_sky_color_rgb,
            ZENITH_SKY_RAIN_COLOR * luma(hi_sky_color_rgb) * day_blend_float(1.0, 1.0, 0.75),
            rainStrength
        );

        hi_sky_color = rgb_to_xyz(hi_sky_color_rgb);
    #else
        vec3 hi_sky_color_rgb = day_blend(
            ZENITH_SUNSET_COLOR,
            ZENITH_DAY_COLOR,
            ZENITH_NIGHT_COLOR
        );

        #if COLOR_SCHEME == 11
            hi_sky_color_rgb = mix(
                hi_sky_color_rgb,
                ZENITH_SKY_RAIN_COLOR * luma(hi_sky_color_rgb) * 0.333,
                rainStrength
            );
        #else
            hi_sky_color_rgb = mix(
                hi_sky_color_rgb,
                ZENITH_SKY_RAIN_COLOR * luma(hi_sky_color_rgb),
                rainStrength
            );
        #endif

    #endif

    // Overcast moonlight floor: applied only when night and rain overlap.
    // It lifts crushed blacks without turning the sky grey or affecting caves.
    float rainy_night_hi = rainStrength * day_blend_float(0.0, 0.0, 1.0);
    vec3 rainy_night_hi_floor = vec3(0.012, 0.019, 0.031);
    hi_sky_color_rgb = mix(
        hi_sky_color_rgb,
        max(hi_sky_color_rgb, rainy_night_hi_floor),
        rainy_night_hi * 0.62
    );
    hi_sky_color = rgb_to_xyz(hi_sky_color_rgb);
#endif

vec3 pure_hi_sky_color_rgb = day_blend(
        ZENITH_SUNSET_COLOR,
        ZENITH_DAY_COLOR,
        saturate(ZENITH_NIGHT_COLOR, 0.5)
    );

    pure_hi_sky_color_rgb = mix(
        pure_hi_sky_color_rgb,
        ZENITH_SKY_RAIN_COLOR * luma(pure_hi_sky_color_rgb),
        rainStrength
    );

    float pure_rainy_night_hi = rainStrength * day_blend_float(0.0, 0.0, 1.0);
    pure_hi_sky_color_rgb = mix(
        pure_hi_sky_color_rgb,
        max(pure_hi_sky_color_rgb, vec3(0.012, 0.019, 0.031)),
        pure_rainy_night_hi * 0.62
    );

    pure_hi_sky_color = rgb_to_xyz(pure_hi_sky_color_rgb);
