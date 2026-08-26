/* Aurora Fantasy - volumetric_clouds.glsl
Fast volumetric clouds - MakeUp & Aurora Fantasy implementation
*/

// Constants for the second cloud layer
#ifdef CIRRUS
    #define CLOUD_PLANE_2 (CLOUD_PLANE + 800.0)
    #define CLOUD_PLANE_SUP_2 (CLOUD_PLANE_SUP + 1000.0)
    #define CLOUD_PLANE_CENTER_2 (CLOUD_PLANE_CENTER + 800.0)
    #define CLOUD_X_OFFSET 800.0
#endif

vec3 get_cloud(vec3 view_vector, vec3 block_color, float bright, float dither, vec3 base_pos, int samples, float umbral, vec3 cloud_color_orig, vec3 dark_cloud_color_orig, float dynamicValue) {
    // More raymarch samples must improve shape fidelity, not increase apparent
    // density. Balanced gently reconstructs missed medium volumes; Extreme uses
    // the accurately sampled optical depth with a calmer artistic opacity.
    #if PROFILE_QUALITY == 1
        const float mainCloudOpticalPower = 0.82;
        const float mainCloudProfileOpacity = 1.00;
        const float cirrusOpticalPower = 0.82;
        const float cirrusProfileOpacity = 1.00;
    #else
        const float mainCloudOpticalPower = 1.04;
        const float mainCloudProfileOpacity = 0.86;
        const float cirrusOpticalPower = 1.08;
        const float cirrusProfileOpacity = 0.82;
    #endif

    float plane_distance;
    float cloud_value;
    float density = 0.0;
    vec3 intersection_pos;
    vec3 intersection_pos_sup;
    float dif_inf;
    float dif_sup;
    float dist_aux_coeff;
    float current_value;
    float surface_inf;
    float surface_sup;
    bool first_contact = true;
    float opacity_dist;
    vec3 increment;
    float increment_dist;
    float view_y_inv = 1.0 / view_vector.y;
    float distance_aux;
    float dist_aux_coeff_blur;

    // Cirrus clouds variables
    #ifdef CIRRUS
        float cloud_value_2;
        float density_2 = 0.0;
        vec3 intersection_pos_2;
        vec3 intersection_pos_sup_2;
        float dif_inf_2;
        float dif_sup_2;
        float opacity_dist_2;
        vec3 increment_2;
        float increment_dist_2;
        bool first_contact_2 = true;
        float current_value2;
    #endif

    #if VOL_LIGHT == 0
        block_color.rgb *=
            clamp(bright + ((dither - .5) * .1), 0.0, 1.0) * .3 + 1.0;
    #endif

    #if defined DISTANT_HORIZONS && defined DEFERRED_SHADER
        float d_dh = texture2D(dhDepthTex0, vec2(gl_FragCoord.x / viewWidth, gl_FragCoord.y / viewHeight)).r;
        float linear_d_dh = ld_dh(d_dh);
        if (linear_d_dh < 0.9999) {
            return block_color;
        }
    #endif

    if (view_vector.y > 0.0) {
        // 1st layer
        plane_distance = (CLOUD_PLANE - base_pos.y) * view_y_inv;
        intersection_pos = (view_vector * plane_distance) + base_pos;

        plane_distance = (CLOUD_PLANE_SUP - base_pos.y) * view_y_inv;
        intersection_pos_sup = (view_vector * plane_distance) + base_pos;

        dif_sup = (CLOUD_PLANE_SUP - CLOUD_PLANE_CENTER) / CLOUD_DENSITY;
        dif_inf = (CLOUD_PLANE_CENTER - CLOUD_PLANE) / CLOUD_DENSITY;
        dist_aux_coeff = (CLOUD_PLANE_SUP - CLOUD_PLANE) * 0.075 / CLOUD_DENSITY;
        dist_aux_coeff_blur = dist_aux_coeff * 0.3;

        opacity_dist = dist_aux_coeff * 2.0 * view_y_inv;

        #if CLOUD_VOL_STYLE == 0
            int total_cloud_samples = samples;
        #else
            int total_cloud_samples = samples + 7;
        #endif
        increment = (intersection_pos_sup - intersection_pos)
            / float(total_cloud_samples);
        increment_dist = length(increment);

        cloud_value = 0.0;

        intersection_pos += (increment * dither);

        for (int i = 0; i < total_cloud_samples; i++) {
            current_value =
                texture2D(
                    gaux2,
                    (intersection_pos.xz * 0.0002777777777777778) + (persistentTimeSeconds * (WIND_FORCE * 0.55 + 0.5) * CLOUD_HI_FACTOR)
                ).r;


            #if V_CLOUDS == 2 && CLOUD_VOL_STYLE == 0
                current_value +=
                    texture2D(
                        gaux2,
                        (intersection_pos.zx * 0.0002777777777777778) + (persistentTimeSeconds * (WIND_FORCE * 0.55 + 0.5) * CLOUD_LOW_FACTOR)
                    ).r;

                current_value *= 0.5;
                current_value = smoothstep(0.05, 0.95, current_value);
            #endif
            
            // Ajuste por umbral
            #if CLOUD_VOL_STYLE == 0
                current_value = (current_value - umbral) / (0.1 + dynamicValue - umbral);
                // A negative height has no physical cloud volume. Keeping the
                // raymarch bounds ordered also prevents fragmented silhouettes.
                float plateau = clamp(current_value, 0.0, 1.0);
            #else
                current_value = (current_value - umbral) / (1.0 - umbral);
                float plateau = pow(clamp(current_value, 0.0, 1.0), 0.1); 
            #endif

            surface_inf = CLOUD_PLANE_CENTER - (plateau * dif_inf); 
            surface_sup = CLOUD_PLANE_CENTER + (plateau * dif_sup);

            if (  // Dentro de la nube
                intersection_pos.y > surface_inf &&
                intersection_pos.y < surface_sup
                ) {
                    cloud_value += min(increment_dist, surface_sup - surface_inf);

                    if (first_contact) {
                        first_contact = false;
                        density =
                        (surface_sup - intersection_pos.y) /
                        (CLOUD_PLANE_SUP - CLOUD_PLANE);
                    }
            }
            else if (surface_inf < surface_sup && i > 0) {  // Fuera de la nube
                distance_aux = min(
                    abs(intersection_pos.y - surface_inf),
                    abs(intersection_pos.y - surface_sup)
                );

                if (distance_aux < dist_aux_coeff_blur) {
                    float effective_step = min(increment_dist, dist_aux_coeff_blur);
                    cloud_value += min(
                        (clamp(dist_aux_coeff_blur - distance_aux, 0.0, dist_aux_coeff_blur) / dist_aux_coeff_blur) * effective_step,
                        surface_sup - surface_inf
                    );

                    if (first_contact) {
                        first_contact = false;
                        density =
                        (surface_sup - intersection_pos.y) /
                        (CLOUD_PLANE_SUP - CLOUD_PLANE);
                    }
                }
            }

            intersection_pos += increment;
        }

        // Convert sampled path length to optical coverage. A gentle power curve
        // recovers medium-density formations that five Balanced samples can
        // otherwise under-estimate, without changing the raymarch cost.
        cloud_value = pow(
            clamp(cloud_value / opacity_dist, 0.0, 1.0),
            mainCloudOpticalPower);
        density = clamp(density, 0.0001, 1.0);

        float att_factor = mix(1.0, 0.75, bright * (1.0 - rainStrength));

        vec3 cloud_color_1 = vec3(0.0);
        cloud_color_1 = mix(cloud_color_orig * att_factor, dark_cloud_color_orig * att_factor, pow(density, 0.4));

        vec3 light_color = day_blend(
            LIGHT_SUNSET_COLOR * 1.66,
            LIGHT_DAY_COLOR,
            LIGHT_NIGHT_COLOR * vec3(0.8, 0.6, 1.0)
        );

        // Sun halo.
        #if CLOUD_VOL_STYLE == 0
            cloud_color_1 =
                mix(cloud_color_1, cloud_color_1 + light_color * day_blend_float(3.0, 3.0, 0.0), (1.0 - pow(cloud_value, 0.2)) * bright * bright * bright * bright * (1.0 - rainStrength));
        #else
            cloud_color_1 =
                mix(cloud_color_1, cloud_color_1 + light_color * day_blend_float(2.0, 1.5, 10.0), (1.0 - cloud_value) * bright * bright * sqrt(bright) * (1.0 - rainStrength));
        #endif

        #if CLOUD_VOL_STYLE == 0
            cloud_color_1 =
                mix(cloud_color_1, cloud_color_1 + light_color * day_blend_float(0.0, 0.0, 0.25), (pow(cloud_value, 1.0)) * bright * bright * bright * (1.0 - rainStrength));
        #else
            cloud_color_1 =
                mix(cloud_color_1, cloud_color_1 + light_color * day_blend_float(0.1, 0.1, 0.25), (pow(cloud_value, 1.0)) * bright * bright * bright * (1.0 - rainStrength));
        #endif

        #if CLOUD_VOL_STYLE == 0
            float twilight_alpha = day_blend_float(0.88, 1.0, 0.42);
            float rainyNightClouds = rainStrength
                * day_blend_float(0.0, 0.0, 1.0);
            // Clear nights remain sparse, but a rainy night must retain the
            // storm volume. Previously the unconditional 12% night presence
            // erased almost every cloud and left a single-colour sky gradient.
            float nightCloudPresence = day_blend_float(1.0, 1.0, 0.12);
            nightCloudPresence = mix(
                nightCloudPresence, 0.76, rainyNightClouds);
            twilight_alpha = max(
                twilight_alpha, rainyNightClouds * 0.72);
            vec3 underlyingSky = max(block_color, vec3(0.0));
            float underlyingSkyLuma = max(luma(underlyingSky), 0.001);
            vec3 perceptualSky = sqrt(underlyingSky);
            float perceptualSkyLuma = max(luma(perceptualSky), 0.001);
            vec3 localSkyHue = clamp(
                perceptualSky / perceptualSkyLuma,
                vec3(0.42),
                vec3(1.72));
            float cloudEdge = 1.0 - smoothstep(
                0.12, 0.78, clamp(density, 0.0, 1.0));

            // Derive storm-cloud luminance from the local sky while keeping
            // density contrast: dense bases are darker, thin edges catch more
            // diffuse moon/twilight light. This reveals cloud drawings without
            // making the entire night sky grey.
            vec3 rainyNightCloudColor = max(
                underlyingSky * mix(0.48, 1.14, cloudEdge),
                vec3(0.010, 0.016, 0.027)
                    * mix(0.72, 1.28, cloudEdge));
            cloud_color_1 = mix(
                cloud_color_1,
                rainyNightCloudColor,
                rainyNightClouds * 0.86);

            // Sunrise needs its own ambient response. Dense cloud bases were
            // still using the neutral shadow palette while the surrounding sky
            // had already become pink, which made them read as black cut-outs.
            float sunriseCloudDistance = min(
                abs(day_moment - 0.045),
                abs(day_moment - 1.045));
            float sunriseCloudLight = 1.0
                - smoothstep(0.035, 0.17, sunriseCloudDistance);

            // Borrow the local sky hue at equal luminance during sunrise and
            // daytime without flattening density detail. Night deliberately
            // keeps the earlier neutral cloud palette.
            float cloudSurfaceLuma = max(luma(cloud_color_1), 0.001);
            vec3 skyTintedCloud = localSkyHue * cloudSurfaceLuma;
            float skyHueCoupling = day_blend_float(0.34, 0.26, 0.0)
                * mix(0.72, 1.0, cloudEdge);
            cloud_color_1 = mix(
                cloud_color_1,
                skyTintedCloud,
                skyHueCoupling);

            // A small sky-irradiance floor prevents detached grey/black slabs.
            // It is deliberately luminance-only before the shared hue is added.
            cloudSurfaceLuma = max(luma(cloud_color_1), 0.001);
            float skyIrradianceFloor = underlyingSkyLuma
                * day_blend_float(0.15, 0.12, 0.0)
                * mix(0.68, 1.0, cloudEdge);
            cloud_color_1 = cloud_color_1 * max(
                cloudSurfaceLuma,
                skyIrradianceFloor) / cloudSurfaceLuma;

            // Lift only the missing ambient component, then borrow the local
            // sky hue at the same luminance. Density contrast remains intact,
            // but sunrise clouds can no longer collapse to neutral black.
            cloudSurfaceLuma = max(luma(cloud_color_1), 0.001);
            float sunriseCloudFloor = underlyingSkyLuma
                * mix(0.22, 0.31, cloudEdge);
            cloud_color_1 = cloud_color_1 * mix(
                1.0,
                max(cloudSurfaceLuma, sunriseCloudFloor)
                    / cloudSurfaceLuma,
                sunriseCloudLight * (1.0 - rainStrength * 0.65));
            cloudSurfaceLuma = max(luma(cloud_color_1), 0.001);
            cloud_color_1 = mix(
                cloud_color_1,
                localSkyHue * cloudSurfaceLuma,
                sunriseCloudLight
                    * mix(0.42, 0.58, cloudEdge)
                    * (1.0 - rainStrength * 0.65));

            float mainCloudOpacity =
                cloud_value * twilight_alpha
                * clamp(
                    (view_vector.y - 0.025)
                        * mix(mix(50.0, 6.0, rainStrength),
                            13.0, rainyNightClouds),
                    0.0, 1.0)
                * (1.0 - arid * rainStrength)
                * nightCloudPresence
                * mainCloudProfileOpacity;

            block_color = mix(
                block_color,
                cloud_color_1,
                mainCloudOpacity
            );
        #else
                block_color = mix(
                block_color,
                cloud_color_1,
                cloud_value * clamp((view_vector.y - 0.06) * 5.0, 0.0, 1.0)
            );
        #endif

    #ifdef CIRRUS
        if (CLOUD_DENSITY >= 1.0) {
            umbral *= 1.0 / pow(CLOUD_DENSITY, 3.5);
        } else {
            umbral /= CLOUD_DENSITY * 3.0;
        }
        
        #if CLOUD_VOL_STYLE == 0
            // 2nd layer CIRRUS clouds
            plane_distance = (CLOUD_PLANE_2 - base_pos.y) * view_y_inv;
            intersection_pos_2 = (view_vector * plane_distance) + base_pos;

            plane_distance = (CLOUD_PLANE_SUP_2 - base_pos.y) * view_y_inv;
            intersection_pos_sup_2 = (view_vector * plane_distance) + base_pos;

            dif_sup_2 = (CLOUD_PLANE_SUP_2 - CLOUD_PLANE_CENTER_2) / CLOUD_DENSITY;
            dif_inf_2 = (CLOUD_PLANE_CENTER_2 - CLOUD_PLANE_2) / CLOUD_DENSITY;
            dist_aux_coeff = (CLOUD_PLANE_SUP_2 - CLOUD_PLANE_2) * 0.075;
            dist_aux_coeff_blur = dist_aux_coeff * 0.3;

            opacity_dist_2 = dist_aux_coeff * 2.0 * view_y_inv;

            increment_2 = (intersection_pos_sup_2 - intersection_pos_2)
                / float(CIRRUS_STEPS_AVG);
            increment_dist_2 = length(increment_2);

            cloud_value_2 = 0.0;
            intersection_pos_2 += (increment_2 * dither);

            for (int i = 0; i < CIRRUS_STEPS_AVG; i++) {
                #if CLOUD_VOL_STYLE == 0
                    current_value2 =
                        texture2D(
                            gaux2,
                            ((intersection_pos_2.xz + vec2(CLOUD_X_OFFSET, 0.0)) * 0.0002777777777777778) + (persistentTimeSeconds * (WIND_FORCE * 0.55 + 0.5) * CLOUD_HI_FACTOR)
                        ).r;
                #else
                    current_value2 = 0.0;
                #endif

                #if V_CLOUDS == 2 && CLOUD_VOL_STYLE == 0
                    current_value2 +=
                        texture2D(
                            gaux2,
                            ((intersection_pos_2.zx + vec2(0.0, CLOUD_X_OFFSET)) * 0.0002777777777777778) + (persistentTimeSeconds * (WIND_FORCE * 0.55 + 0.5) * CLOUD_LOW_FACTOR)
                        ).r;
                    current_value2 *= 0.5;
                    current_value2 = smoothstep(0.05, 0.95, current_value2);
                #endif

                #if CLOUD_VOL_STYLE == 0
                    // Build a thin positive-height cirrus field from the bright
                    // part of the same noise. The old expression was negative
                    // for nearly every clear-weather sample, reversing the
                    // layer bounds and silently removing the upper clouds.
                    float cirrusThreshold = umbral * 0.96;
                    float cirrusPlateau = clamp(
                        (current_value2 - cirrusThreshold)
                            / max(0.78 - cirrusThreshold, 0.12),
                        0.0,
                        1.0);
                    current_value2 = pow(cirrusPlateau, 1.25) * 0.34;
                #else
                    current_value2 = (current_value2 - umbral) / (1.0 - umbral);
                #endif

                surface_inf = CLOUD_PLANE_CENTER_2 - (current_value2 * dif_inf_2);
                surface_sup = CLOUD_PLANE_CENTER_2 + (current_value2 * dif_sup_2);

                if (intersection_pos_2.y > surface_inf && intersection_pos_2.y < surface_sup) {
                    cloud_value_2 += min(increment_dist_2, surface_sup - surface_inf);
                    if (first_contact_2) {
                        first_contact_2 = false;
                        density_2 = (surface_sup - intersection_pos_2.y) / (CLOUD_PLANE_SUP_2 - CLOUD_PLANE_2);
                    }
                }
                else if (surface_inf < surface_sup && i > 0) {
                    distance_aux = min(
                        abs(intersection_pos_2.y - surface_inf),
                        abs(intersection_pos_2.y - surface_sup)
                    );
                    if (distance_aux < dist_aux_coeff_blur) {
                        float effective_step_2 = min(increment_dist_2, dist_aux_coeff_blur);
                        cloud_value_2 += min(
                            (clamp(dist_aux_coeff_blur - distance_aux, 0.0, dist_aux_coeff_blur) / dist_aux_coeff_blur) * effective_step_2,
                            surface_sup - surface_inf
                        );
                        if (first_contact_2) {
                            first_contact_2 = false;
                            density_2 = (surface_sup - intersection_pos_2.y) / (CLOUD_PLANE_SUP_2 - CLOUD_PLANE_2);
                        }
                    }
                }
                intersection_pos_2 += increment_2;
            }

            cloud_value_2 = pow(
                clamp(cloud_value_2 / opacity_dist_2, 0.0, 1.0),
                cirrusOpticalPower);
            density_2 = clamp(density_2, 0.0001, 1.0);

            vec3 cloud_color_2 = vec3(0.0);
            cloud_color_2 = mix(cloud_color_orig * att_factor, dark_cloud_color_orig * att_factor, pow(density_2, 0.4));

            cloud_color_2 =
                mix(cloud_color_2, cloud_color_2 + light_color * day_blend_float(2.5, 4.0, 1.0), (1.0 - pow(cloud_value_2, 0.2)) * bright * (1.0 - rainStrength));

            cloud_color_2 =
                mix(cloud_color_2, cloud_color_2 + light_color * day_blend_float(0.0, 0.5, 1.0), (pow(cloud_value_2, 0.1)) * bright * bright * bright * (1.0 - rainStrength));

            float twilight_alpha_2 = day_blend_float(0.78, 0.90, 0.28);
            float rainyNightCirrus = rainStrength
                * day_blend_float(0.0, 0.0, 1.0);
            float nightCirrusPresence = day_blend_float(1.0, 1.0, 0.08);
            nightCirrusPresence = mix(
                nightCirrusPresence, 0.34, rainyNightCirrus);
            twilight_alpha_2 = max(
                twilight_alpha_2, rainyNightCirrus * 0.38);
            float cirrusEdge = 1.0 - smoothstep(
                0.10, 0.74, clamp(density_2, 0.0, 1.0));
            float cirrusSurfaceLuma = max(luma(cloud_color_2), 0.001);
            vec3 skyTintedCirrus = localSkyHue * cirrusSurfaceLuma;
            float cirrusSkyCoupling = day_blend_float(
                0.40, 0.32, 0.0) * mix(0.76, 1.0, cirrusEdge);
            cloud_color_2 = mix(
                cloud_color_2,
                skyTintedCirrus,
                cirrusSkyCoupling);

            // Cirrus shares the same sunrise irradiance, with a slightly lower
            // floor so the upper wisps stay lighter and more translucent.
            cirrusSurfaceLuma = max(luma(cloud_color_2), 0.001);
            float sunriseCirrusFloor = underlyingSkyLuma
                * mix(0.18, 0.26, cirrusEdge);
            cloud_color_2 = cloud_color_2 * mix(
                1.0,
                max(cirrusSurfaceLuma, sunriseCirrusFloor)
                    / cirrusSurfaceLuma,
                sunriseCloudLight * (1.0 - rainStrength * 0.65));
            cirrusSurfaceLuma = max(luma(cloud_color_2), 0.001);
            cloud_color_2 = mix(
                cloud_color_2,
                localSkyHue * cirrusSurfaceLuma,
                sunriseCloudLight
                    * mix(0.46, 0.62, cirrusEdge)
                    * (1.0 - rainStrength * 0.65));

            // Blend the second layer with the first
            float second_layer_opacity = cloud_value_2
                * clamp((view_vector.y - 0.025) * 2, 0.0, 1.0)
                * (1.0 - cloud_value)
                * twilight_alpha_2
                * nightCirrusPresence
                * cirrusProfileOpacity;
            block_color = mix(
                block_color,
                cloud_color_2,
                second_layer_opacity
            );
        #endif
    #endif
    }

    return block_color;
}
