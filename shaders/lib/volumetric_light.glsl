/* Aurora Fantasy - volumetric_clouds.glsl
Volumetric light - MakeUp implementation
*/

#if VOL_LIGHT == 2

    float vol_shadow_sample(sampler2DShadow s, vec3 c) {
        return texture(s, c);
    }

    #define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

    vec3 get_volumetric_pos(vec3 shadow_pos) {
        if(fragment_cull()) return vec3(0.0);
        shadow_pos = mat3(shadowModelView) * shadow_pos + shadowModelView[3].xyz;
        shadow_pos = diagonal3(shadowProjection) * shadow_pos + shadowProjection[3].xyz;
        float distb = length(shadow_pos.xy);
        float distortion = distb * SHADOW_DIST + (1.0 - SHADOW_DIST);

        shadow_pos.xy /= distortion;
        shadow_pos.z *= 0.2;
        
        return shadow_pos * 0.5 + 0.5;
    }

    float get_volumetric_light(float dither, float view_distance, mat4 modeli_times_projectioni) {
        if(fragment_cull()) return 0.0;
        float light = 0.0;

        float current_depth;
        vec3 view_pos;
        vec4 pos;
        vec3 shadow_pos;

        for (int i = 0; i < clamp(GODRAY_STEPS * RENDER_SCALE, 2.0, 10.0); i++) {
            // Exponentialy spaced shadow samples
            current_depth = exp2(i + dither) - 0.6;
            if (current_depth > view_distance) {
                break;
            }

            // Distance to depth
            current_depth = (far * (current_depth - near)) / (current_depth * (far - near));

            view_pos = vec3(texcoord, current_depth);

            // Clip to world
            pos = modeli_times_projectioni * (vec4(view_pos, 1.0) * 2.0 - 1.0);
            view_pos = (pos.xyz /= pos.w).xyz;
            shadow_pos = get_volumetric_pos(view_pos);
            light += vol_shadow_sample(shadowtex1, shadow_pos);
        }

        light /= GODRAY_STEPS;

        return light * light;
    }

    #if defined COLORED_SHADOW

        vec3 get_volumetric_color_light(float dither, float view_distance, mat4 modeli_times_projectioni) {
            if(fragment_cull()) return vec3(0.0);
            float light = 0.0;

            float current_depth;
            vec3 view_pos;
            vec4 pos;
            vec3 shadow_pos;

            float shadow_detector = 1.0;
            float shadow_black = 1.0;
            vec3 light_color = vec3(0.0);
            // Keep stained transmission separate from ordinary white air.
            // Mixing the two diluted coloured shafts as ray quality rose.
            vec3 stained_volume = vec3(0.0);

            float alpha_complement;

            // Stratified world-distance marching.  The old exponential
            // sequence left large unsampled gaps (0, 1, 3, 7, 15 blocks),
            // producing visible screen-space bands as the player moved.
            float volumeSteps = clamp(GODRAY_STEPS * RENDER_SCALE, 2.0, 16.0);
            float marchLimit = min(max(view_distance, near * 1.01), 96.0);
            for (int i = 0; i < 16; i++) {
                if (float(i) >= volumeSteps) break;

                // Reset for every march point. Keeping the colour from a
                // previous glass hit made tint leak into clear air.
                vec4 shadow_color = vec4(1.0);
                current_depth = max(near * 1.01,
                    (float(i) + dither) / volumeSteps * marchLimit);

                // Distance to depth
                current_depth = (far * (current_depth - near)) / (current_depth * (far - near));

                view_pos = vec3(texcoord, current_depth);

                // Clip to world
                pos = modeli_times_projectioni * (vec4(view_pos, 1.0) * 2.0 - 1.0);
                view_pos = (pos.xyz /= pos.w).xyz;

                shadow_pos = get_volumetric_pos(view_pos);

                shadow_detector = vol_shadow_sample(shadowtex0, vec3(shadow_pos.xy, shadow_pos.z - 0.001));
                if (shadow_detector < 1.0) {
                    shadow_black = vol_shadow_sample(shadowtex1, vec3(shadow_pos.xy, shadow_pos.z - 0.001));
                    vec4 transmission_sample = texture2D(shadowcolor0, shadow_pos.xy);
                    float transmission_chroma = max(
                        max(transmission_sample.r, transmission_sample.g),
                        transmission_sample.b) - min(
                        min(transmission_sample.r, transmission_sample.g),
                        transmission_sample.b);

                    // See get_colored_shadow: in Iris 1.11 translucent
                    // blocks can occupy both shadow depth textures. Their
                    // colour-buffer alpha is the dependable transmission mask.
                    #ifdef STAINED_GLASS_LIGHT
                    if (transmission_sample.a < 0.98
                        && transmission_chroma > 0.08) {
                        vec3 glass_tint = transmission_sample.rgb / max(
                            max(transmission_sample.r, max(
                                transmission_sample.g, transmission_sample.b)),
                            0.001);
                        float transmission = mix(0.52, 0.86,
                            clamp(1.0 - transmission_sample.a, 0.0, 1.0));
                        stained_volume += mix(vec3(0.08), glass_tint, 0.92)
                            * transmission;
                        continue;
                    }
                    #endif

                    if (shadow_black != shadow_detector) {
                        shadow_color = transmission_sample;
                        alpha_complement = 1.0 - shadow_color.a;
                        shadow_color.rgb *= alpha_complement;
                        shadow_color.rgb = mix(shadow_color.rgb, vec3(1.0), alpha_complement);
                    }
                }
                
                shadow_color *= shadow_black;
                light_color += clamp(shadow_color.rgb * (1.0 - shadow_detector) + shadow_detector, vec3(0.0), vec3(1.0));
            }

            // This function is used exclusively for stained-glass shafts.
            // Returning only the coloured integral avoids a white-air average
            // washing the beam out at high sample counts.
            stained_volume /= volumeSteps
                / day_blend_float(0.75, 1.0, 1.0);
            return stained_volume * STAINED_GLASS_RAY_STRENGTH;
        }
        
    #endif

#elif VOL_LIGHT == 1

    float ss_godrays(float dither) {
        if(fragment_cull() || any(greaterThan(texcoord, vec2(RENDER_SCALE))) || any(lessThan(texcoord, vec2(0.0)))) {
            return 0.0;
        }

        float light = 0.0;
        float comp = 1.0 - (near / (far * far));

        vec2 ray_step = vec2(lightpos - texcoord) * 0.2;
        vec2 dither2d = texcoord + (ray_step * dither);

        float depth;

        for (int i = 0; i < CHEAP_GODRAY_SAMPLES; i++) {
            if (any(greaterThan(dither2d, vec2(RENDER_SCALE))) || any(lessThan(dither2d, vec2(0.0)))) {
                break; 
            }
            depth = texture2D(depthtex1, dither2d).x;
            dither2d += ray_step;
            light += step(comp, depth);
        }

        #ifndef THE_END
            return light / float(CHEAP_GODRAY_SAMPLES) * 1.25;
        #else
            return light / float(CHEAP_GODRAY_SAMPLES);
        #endif
    }

#endif
