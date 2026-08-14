/* __   ______________
  / /  /  _/_  __/ __/
 / /___/ /  / / / _/  
/____/___/ /_/ /___/  
                      
Aurora Fantasy 5.4.1 - current_sky_color.glsl #include "/src/current_sky_color.glsl"
Sky color calculation. - Cálculo da cor do céu. */

bool check = (lightningBoltPosition.w > 0.001);
float lightning = float(check);

float sun_influence = dot(nfragpos, sunPosition * 0.01);
float final_sun_factor = pow(smoothstep(-1.0, 1.0, sun_influence), day_blend_float_lgcy(1.0, 1.0, 2.0));
float final_sun_factor2 = pow(smoothstep(-1.0, 1.0, sun_influence), day_blend_float(1.5, 0.0, 10.0));

#if COLOR_SCHEME == 11 // Aurora Vanilla
    float final_sun_factor3 = pow(smoothstep(-1.0, 1.0, sun_influence), day_blend_float(1.0, 0.0, 1.75));
    vec3 current_low_sky_color = mix(
        (mid_sky_color * day_blend_float(1.0, 1.0, 0.75)), 
        low_sky_color, 
        final_sun_factor3
    );
    vec3 current_mid_sky_color = mid_sky_color;
    vec3 current_hi_sky_color = hi_sky_color;
#elif COLOR_SCHEME == 8 || COLOR_SCHEME == 12 // LITE Realistic & Cursed
    vec3 current_low_sky_color_base = mix(
        (pure_mid_sky_color * day_blend_float_lgcy(4.5, 1.0, 2.0)) * 0.66 + low_sky_color * day_blend_float(0.05, 0.5, 0.05), 
        low_sky_color * day_blend_float_lgcy(2.0, 1.5, 1.25), 
        final_sun_factor
    );

    vec3 current_mid_sky_color_base = mix(
        (pure_hi_sky_color * 1.0 + pure_mid_sky_color) * day_blend_float_lgcy(0.4, 0.7, 0.35) + (mid_sky_color * lightning), 
        mid_sky_color + (mid_sky_color * 2 * lightning), 
        final_sun_factor2
    );

    vec3 current_hi_sky_color = mix(
        hi_sky_color * day_blend_float(0.8, 1.0, 1.0) + (hi_sky_color * lightning), 
        hi_sky_color + (hi_sky_color * lightning), 
        final_sun_factor
    );

    // The fantasy sunrise intentionally starts from a strong HDR palette, but
    // the old 4.5x horizon branch could exceed the display shoulder before the
    // final tonemap. That clipped all of its peach/magenta detail to white.
    // XYZ.y is luminance, so compressing it here preserves the authored hue and
    // keeps the correction isolated from noon, sunset and night.
    float sunrise_distance = min(
        abs(day_moment - 0.045),
        abs(day_moment - 1.045)
    );
    float sunrise_horizon_control = 1.0
        - smoothstep(0.035, 0.17, sunrise_distance);

    float sunrise_low_luma = max(current_low_sky_color_base.y, 0.0001);
    float sunrise_low_excess = max(sunrise_low_luma - 0.22, 0.0);
    float sunrise_low_shoulder = 0.22
        + sunrise_low_excess
        / (1.0 + sunrise_low_excess / 0.28);
    float sunrise_low_scale = min(
        sunrise_low_shoulder / sunrise_low_luma,
        1.0
    );
    vec3 current_low_sky_color = current_low_sky_color_base * mix(
        1.0,
        sunrise_low_scale,
        sunrise_horizon_control * 0.94
    );

    // A gentler shoulder above the horizon prevents a second pale band while
    // retaining the bright lavender body of the sunrise sky.
    float sunrise_mid_luma = max(current_mid_sky_color_base.y, 0.0001);
    float sunrise_mid_excess = max(sunrise_mid_luma - 0.30, 0.0);
    float sunrise_mid_shoulder = 0.30
        + sunrise_mid_excess
        / (1.0 + sunrise_mid_excess / 0.34);
    float sunrise_mid_scale = min(
        sunrise_mid_shoulder / sunrise_mid_luma,
        1.0
    );
    vec3 current_mid_sky_color = current_mid_sky_color_base * mix(
        1.0,
        sunrise_mid_scale,
        sunrise_horizon_control * 0.62
    );
#else // Others
    vec3 current_low_sky_color = low_sky_color;
    vec3 current_mid_sky_color = low_sky_color;
    vec3 current_hi_sky_color = hi_sky_color;
#endif
