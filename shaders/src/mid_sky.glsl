#if COLOR_SCHEME == 8
vec3 mid_sky_color_rgb = day_blend(
        saturate(MID_SUNSET_COLOR, day_blend_float_lgcy(1.0, 1.0, 0.333)) * day_blend(vec3(1.0), vec3(1.0), vec3(1.6, 1.6, 1.5) * 1.25),
        MID_DAY_COLOR,
        saturate(MID_NIGHT_COLOR, day_blend_float(1.0, 1.0, 0.0)) * day_blend_float(1.0, 1.0, 1.25)
    );

    mid_sky_color_rgb = mix(
        mid_sky_color_rgb,
        HORIZON_SKY_RAIN_COLOR * luma(mid_sky_color_rgb * day_blend_float(1.0, 1.0, 0.75)),
        rainStrength
    );

    mid_sky_color = rgb_to_xyz(mid_sky_color_rgb);
#else
vec3 mid_sky_color_rgb = day_blend(
        MID_SUNSET_COLOR,
        MID_DAY_COLOR,
        MID_NIGHT_COLOR
    );

    mid_sky_color_rgb = mix(
        mid_sky_color_rgb,
        HORIZON_SKY_RAIN_COLOR * luma(mid_sky_color_rgb * 1.25),
        rainStrength
    );

#endif

float rainy_twilight_mid = rainStrength
    * smoothstep(0.49, 0.545, day_moment)
    * (1.0 - smoothstep(0.64, 0.72, day_moment));
float rainy_twilight_mid_luma = max(luma(mid_sky_color_rgb), 0.001);
vec3 rainy_twilight_mid_hue = MID_SUNSET_COLOR
    / max(luma(MID_SUNSET_COLOR), 0.001);
mid_sky_color_rgb = mix(
    mid_sky_color_rgb,
    rainy_twilight_mid_hue * rainy_twilight_mid_luma,
    rainy_twilight_mid * 0.16);

float rainy_night_mid = rainStrength * day_blend_float(0.0, 0.0, 1.0);
vec3 rainy_night_mid_floor = vec3(0.014, 0.022, 0.035);
mid_sky_color_rgb = mix(
    mid_sky_color_rgb,
    max(mid_sky_color_rgb, rainy_night_mid_floor),
    rainy_night_mid * 0.62
);
mid_sky_color = rgb_to_xyz(mid_sky_color_rgb);

vec3 pure_mid_sky_color_rgb = day_blend(
        saturate(MID_SUNSET_COLOR, 0.5),
        MID_DAY_COLOR,
        MID_NIGHT_COLOR
    );

    pure_mid_sky_color_rgb = mix(
        pure_mid_sky_color_rgb,
        HORIZON_SKY_RAIN_COLOR * luma(pure_mid_sky_color_rgb * 1.25) * day_blend_float(1.0, 1.0, 2.0),
        (rainStrength - 0.05)
    );

    float pure_rainy_night_mid = rainStrength * day_blend_float(0.0, 0.0, 1.0);
    pure_mid_sky_color_rgb = mix(
        pure_mid_sky_color_rgb,
        max(pure_mid_sky_color_rgb, vec3(0.014, 0.022, 0.035)),
        pure_rainy_night_mid * 0.62
    );

    pure_mid_sky_color = rgb_to_xyz(pure_mid_sky_color_rgb);
