// Profile-scaled rotated disk sampling. The per-frame rotation works with TAA
// to smooth the penumbra while SHADOW_SAMPLES controls the actual quality cost.
vec2 aurora_shadow_disk_offset(int sample_index, float dither, float radius) {
    float sample_position = float(sample_index) + 0.5;
    float sample_radius = sqrt(sample_position / float(SHADOW_SAMPLES));
    float sample_angle = sample_position * 2.399963229728653
        + dither * 6.283185307179586;
    return vec2(cos(sample_angle), sin(sample_angle))
        * sample_radius * radius / float(shadowMapResolution);
}

vec3 get_shadow(vec3 the_shadow_pos, float dither) {
    #if SHADOW_TYPE == 0
        return vec3(shadow2D(shadowtex1, the_shadow_pos).r);
    #else
        float shadow_dist = length(the_shadow_pos.xy - 0.5) * 2.0;
        float adaptive_blur = SHADOW_BLUR * (1.0 + shadow_dist * 1.5);
        float z_bias = (0.5 + dither) * 0.00002;
        float shadow_sum = 0.0;

        for (int i = 0; i < SHADOW_SAMPLES; i++) {
            vec2 offset = aurora_shadow_disk_offset(i, dither, adaptive_blur);
            shadow_sum += shadow2D(
                shadowtex1,
                vec3(the_shadow_pos.xy + offset, the_shadow_pos.z - z_bias)
            ).r;
        }

        return vec3(shadow_sum / float(SHADOW_SAMPLES));
    #endif
}

#if defined COLORED_SHADOW
    vec3 get_colored_shadow(vec3 the_shadow_pos, float dither) {
        #if SHADOW_TYPE == 0
            float shadow_detector = shadow2D(shadowtex0, the_shadow_pos).r;
            float shadow_black = shadow2D(shadowtex1, the_shadow_pos).r;

            vec3 final_color = vec3(1.0);
            if (shadow_detector < 1.0
                && abs(shadow_black - shadow_detector) > 0.000001) {
                vec4 colored_tex = texture2D(shadowcolor0, the_shadow_pos.xy);
                float alpha_complement = 1.0 - colored_tex.a;
                final_color = mix(
                    colored_tex.rgb,
                    vec3(1.0),
                    alpha_complement
                ) * alpha_complement;
            }

            final_color = mix(final_color, vec3(0.0), 1.0 - shadow_black);
            final_color = saturate(final_color, 1.5);
            return clamp(
                final_color * (1.0 - shadow_detector) + shadow_detector,
                vec3(0.0),
                vec3(1.0)
            );
        #else
            float shadow_dist = length(the_shadow_pos.xy - 0.5) * 2.0;
            float adaptive_blur = SHADOW_BLUR * (1.0 + shadow_dist * 1.5);
            float z_bias = (0.5 + dither) * 0.00002;
            vec3 final_color = vec3(0.0);

            for (int i = 0; i < SHADOW_SAMPLES; i++) {
                vec2 offset = aurora_shadow_disk_offset(
                    i,
                    dither,
                    adaptive_blur
                );
                vec3 sample_pos = vec3(
                    the_shadow_pos.xy + offset,
                    the_shadow_pos.z - z_bias
                );
                float detector = shadow2D(shadowtex0, sample_pos).r;
                float black = shadow2D(shadowtex1, sample_pos).r;
                vec4 color_sample = texture2D(
                    shadowcolor0,
                    the_shadow_pos.xy + offset
                );

                vec3 processed = vec3(1.0);
                if (detector < 1.0
                    && abs(black - detector) > 0.000001) {
                    float alpha_complement = 1.0 - color_sample.a;
                    processed = mix(
                        color_sample.rgb,
                        vec3(1.0),
                        alpha_complement
                    ) * alpha_complement;
                }

                processed = mix(processed, vec3(0.0), 1.0 - black);
                processed = clamp(
                    mix(processed, vec3(1.0), detector),
                    vec3(0.0),
                    vec3(1.0)
                );
                final_color += processed;
            }

            final_color /= float(SHADOW_SAMPLES);
            return saturate(final_color, 1.5);
        #endif
    }
#endif
