float fog_correction;
#if V_CLOUDS > 0
    fog_correction = mix(1.0, 1.35, final_sun_factor);
    #if VOL_LIGHT > 0
        fog_correction /= mix(1.0, 1.35, final_sun_factor);
    #endif
#elif VOL_LIGHT > 0
    fog_correction = mix(1.0, 1.275, final_sun_factor);
#else
    fog_correction = 1.0;
#endif


float fog_adj2 = mix(fog_adj, clamp(fog_adj * 1.75, 0.0, 2.0 - final_sun_factor), final_sun_factor);


#if defined THE_END
    #ifdef FOG_ACTIVE
        if(isEyeInWater == 0 && FOG_ADJUST < 15.0) {  // In the air
            block_color.rgb = mix(block_color.rgb, ZENITH_DAY_COLOR * 1.1 * vec3(1.2, 1.3, 1.2), fog_adj);
        }
    #endif
#elif defined NETHER
    #ifdef FOG_ACTIVE
        if(isEyeInWater == 0 && FOG_ADJUST < 15.0) {  // In the air
            block_color.rgb = mix(block_color.rgb, mix(fogColor * 0.25, vec3(0.5), 0.025), fog_adj);
        }
    #endif
#else
    #ifdef FOG_ACTIVE  // Fog active
        vec3 gaux4_fog_sample = texture2D(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y)).rgb;
        float gaux4_fog_valid = (max(max(gaux4_fog_sample.r, gaux4_fog_sample.g), gaux4_fog_sample.b) > 0.002 || day_mixer < 0.05) ? 1.0 : 0.0;
        vec3 safe_fog_color = mix(skyColor, gaux4_fog_sample, gaux4_fog_valid) * fog_correction;
        // The fog lookup is HDR and can become pure white around bright clouds.
        // Compress only the fog colour so distant terrain remains a tinted haze.
        safe_fog_color /= 1.0 + safe_fog_color * 0.45;
        // Cool, desaturated storm air prevents rain fog from becoming a white
        // overlay. The wider cap is used only during substantial rainfall.
        float cinematic_rain_haze = smoothstep(0.08, 0.92, rainStrength);
        float rainy_night = smoothstep(0.18, 0.90,
            day_blend_float(0.0, 0.0, 1.0));
        vec3 rain_haze_tint = mix(vec3(0.37, 0.46, 0.52),
            vec3(0.018, 0.042, 0.085), rainy_night);
        safe_fog_color = mix(safe_fog_color,
            mix(safe_fog_color, rain_haze_tint, 0.32),
            cinematic_rain_haze);
        // At night, prevent bright cloud/sky samples in gaux4 from bleaching
        // the scene. Keep the haze deep blue while retaining its depth.
        safe_fog_color = mix(safe_fog_color,
            mix(safe_fog_color, rain_haze_tint, 0.72),
            cinematic_rain_haze * rainy_night);
        float fog_blend = min(
            fog_adj * mix(1.0, mix(1.18, 0.82, rainy_night), cinematic_rain_haze),
            mix(0.72, mix(0.86, 0.64, rainy_night), cinematic_rain_haze));

        #if MC_VERSION >= 11900
            vec3 fog_texture;
            if(darknessFactor > .01) {
                fog_texture = vec3(0.0);
            } else {
                fog_texture = safe_fog_color;
            }
        #else
            vec3 fog_texture = safe_fog_color;
        #endif
        #if defined GBUFFER_ENTITIES
            if(isEyeInWater == 0 && entityId != 10101 && FOG_ADJUST < 15.0) {  // In the air
                block_color.rgb = mix(block_color.rgb, fog_texture, fog_blend);
            }
        #else
            if(isEyeInWater == 0) {  // In the air
                block_color.rgb = mix(block_color.rgb, fog_texture, fog_blend);
            }
        #endif
    #endif
#endif

#if MC_VERSION >= 11900
    if(blindness > .01 || darknessFactor > .01) {
        block_color.rgb = mix(block_color.rgb, vec3(0.0), max(blindness, darknessLightFactor) * gl_FogFragCoord * 0.2);
    }
#else
    if(blindness > .01) {
        block_color.rgb = mix(block_color.rgb, vec3(0.0), blindness * gl_FogFragCoord * 0.2);
    }
#endif
