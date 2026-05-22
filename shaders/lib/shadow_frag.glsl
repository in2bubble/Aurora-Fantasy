vec3 get_shadow(vec3 the_shadow_pos, float dither) {
    float shadow_sample = 1.0;

    #if SHADOW_TYPE == 0 // Pixelated
        shadow_sample = shadow2D(shadowtex1, the_shadow_pos).r;
    #elif SHADOW_TYPE == 1 // Soft (Distance-based PCSS-like softness)
        float current_radius = dither;
        float dither_angle = dither * 6.283185307179586;

        // Distance-based shadow blur: farther = softer shadows
        float shadow_dist = length(the_shadow_pos.xy - 0.5) * 2.0;
        float adaptive_blur = SHADOW_BLUR * (1.0 + shadow_dist * 1.5);
        
        vec2 offset = (vec2(cos(dither_angle), sin(dither_angle)) * current_radius * adaptive_blur) / shadowMapResolution;
        float z_bias = dither_angle * 0.00002;

        // 4-tap rotated sampling for smoother shadows
        float sample1 = shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset, the_shadow_pos.z - z_bias)).r;
        float sample2 = shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset, the_shadow_pos.z - z_bias)).r;
        
        vec2 offset_perp = vec2(-offset.y, offset.x) * 0.7;
        float sample3 = shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset_perp, the_shadow_pos.z - z_bias)).r;
        float sample4 = shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset_perp, the_shadow_pos.z - z_bias)).r;

        shadow_sample = (sample1 + sample2 + sample3 + sample4) * 0.25;
    #endif

    return vec3(shadow_sample);
}

#if defined COLORED_SHADOW

    vec3 get_colored_shadow(vec3 the_shadow_pos, float dither) {
        #if SHADOW_TYPE == 0 // Pixelated
            float shadow_detector = shadow2D(shadowtex0, the_shadow_pos).r;
            float shadow_black = shadow2D(shadowtex1, the_shadow_pos).r;
            
            vec3 final_color = vec3(1.0);
            if (shadow_detector < 1.0) {
                if (shadow_black != shadow_detector) {
                    vec4 colored_tex = texture2D(shadowcolor0, the_shadow_pos.xy);
                    float alpha_complement = 1.0 - colored_tex.a;
                    colored_tex.rgb = mix(colored_tex.rgb, vec3(1.0), alpha_complement) * alpha_complement;
                    final_color = colored_tex.rgb;
                }
            }

            final_color = mix(final_color, vec3(0.0), 1.0 - shadow_black);
            final_color = saturate(final_color, 1.5);
            final_color = clamp(final_color * (1.0 - shadow_detector) + shadow_detector, vec3(0.0), vec3(1.0));
            
            return final_color;

        #elif SHADOW_TYPE == 1 // Soft (Distance-based with 4-tap)
            float current_radius = dither;
            float dither_angle = dither * 6.283185307179586;
            
            // Adaptive blur based on shadow map distance
            float shadow_dist = length(the_shadow_pos.xy - 0.5) * 2.0;
            float adaptive_blur = SHADOW_BLUR * (1.0 + shadow_dist * 1.5);
            
            vec2 offset = (vec2(cos(dither_angle), sin(dither_angle)) * current_radius * adaptive_blur) / shadowMapResolution;
            float z_bias = dither_angle * 0.00002;
            vec2 offset_perp = vec2(-offset.y, offset.x) * 0.7;

            vec3 final_color = vec3(0.0);

            // 4-tap sampling
            vec2 offsets[4];
            offsets[0] = offset;
            offsets[1] = -offset;
            offsets[2] = offset_perp;
            offsets[3] = -offset_perp;

            for (int i = 0; i < 4; i++) {
                float detector = shadow2D(shadowtex0, vec3(the_shadow_pos.xy + offsets[i], the_shadow_pos.z - z_bias)).r;
                float black = shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offsets[i], the_shadow_pos.z - z_bias)).r;
                vec4 color_sample = texture2D(shadowcolor0, the_shadow_pos.xy + offsets[i]);

                vec3 processed = vec3(1.0);
                if (detector < 1.0 && black != detector) {
                    float alpha_complement = 1.0 - color_sample.a;
                    processed = mix(color_sample.rgb, vec3(1.0), alpha_complement) * alpha_complement;
                }
                processed = mix(processed, vec3(0.0), 1.0 - black);
                processed = clamp(mix(processed, vec3(1.0), detector), vec3(0.0), vec3(1.0));
                final_color += processed;
            }

            final_color *= 0.25;
            final_color = saturate(final_color, 1.5);
            
            return final_color;
        #endif
    }
#endif