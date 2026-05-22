/* Aurora Fantasy - water.glsl
Water reflection and refraction related functions.
*/

const float MIN_CORRECTION = 1.0; 
const float MAX_CORRECTION = 3.0; 
float adaptFPS = fps_correction(fps, MIN_CORRECTION, MAX_CORRECTION);

vec3 fast_raymarch(vec3 direction, vec3 hit_coord, inout float infinite, float dither) {
    vec3 dir_increment;
    vec3 current_march = hit_coord;
    vec3 old_current_march;
    float screen_depth;
    float depth_diff = 1.0;
    vec3 march_pos = camera_to_screen(hit_coord);
    float prev_screen_depth = march_pos.z;
    float hit_z = march_pos.z;
    bool search_flag = false;
    bool hidden_flag = false;
    bool first_hidden = true;
    bool out_flag = false;
    bool to_far = false;
    vec3 last_march_pos;
    
    int no_hidden_steps = 0;
    bool hiddens = false;

    // Ray marching
    for (int i = 0; i < RAYMARCH_STEPS + 1; i += int(adaptFPS)) {
        if (search_flag) {
            dir_increment *= 0.5;
            current_march += dir_increment * sign(depth_diff);
        } else {
            old_current_march = current_march;
            current_march = hit_coord + ((direction * exp2(i + dither)) - direction);
            dir_increment = current_march - old_current_march;
        }

        last_march_pos = march_pos;
        march_pos = camera_to_screen(current_march);

        if ( // Is outside screen space
            march_pos.x < 0.0 ||
            march_pos.x > 1.0 ||
            march_pos.y < 0.0 ||
            march_pos.y > 1.0 ||
            march_pos.z < 0.0
        ) {
            out_flag = true;
        }

        if (march_pos.z > 0.9999) {
            to_far = true;
        }

        screen_depth = texture2D(depthtex1, march_pos.xy).x;
        depth_diff = screen_depth - march_pos.z;

        if (depth_diff < 0.0 && abs(screen_depth - prev_screen_depth) > abs(march_pos.z - last_march_pos.z)) {
            hidden_flag = true;
            hiddens = true;
            if (first_hidden) {
                first_hidden = false;
            }
        } else if (depth_diff > 0.0) {
            hidden_flag = false;
            if (!hiddens) {
                no_hidden_steps++;
            }
        }

        if (search_flag == false && depth_diff < 0.0 && hidden_flag == false) {
            search_flag = true;
        }

        prev_screen_depth = screen_depth;
    }

    infinite = float(screen_depth > 0.9999);

    if (out_flag) {
        infinite = 1.0;
        return march_pos;
    } else if (to_far) {
        if (screen_depth > 0.9999) {
            infinite = 1.0;
            return march_pos;
        } else if (no_hidden_steps < 3 || screen_depth > hit_z) {
            return march_pos;
        } else {
            infinite = 1.0;
            return vec3(1.0);
        }
    } else {
        march_pos.xy = clamp(march_pos.xy, vec2(0.0), vec2(RENDER_SCALE));
        return march_pos;
    }
}

#if SUN_REFLECTION > 0
    #if !defined NETHER && !defined THE_END
        float sun_reflection(vec3 fragpos, float smoothstep1) {
            vec3 nfragPos = normalize(fragpos);
            vec3 astro_pos = worldTime > 13200 ? moonPosition : sunPosition;
            vec3 nastroPos = normalize(astro_pos);

            float reflection = 0.0;

            #if  SUN_REFLECTION == 2
                vec3 forward = normalize(mat3(gbufferModelViewInverse) * nastroPos);
                vec3 nFragWorld = normalize(mat3(gbufferModelViewInverse) * nfragPos);

                vec3 worldRef = vec3(0.0, 1.0, 0.0);
                if (abs(dot(forward, worldRef)) > 0.99) worldRef = vec3(0.0, 0.0, 1.0);

                vec3 rightBase = normalize(cross(worldRef, forward));
                vec3 upBase = cross(forward, rightBase);

                float rawX = dot(nFragWorld, rightBase);
                float rawY = dot(nFragWorld, upBase);

                float angle = sunPathRotation * 0.01745329; 
                float s = sin(angle);
                float c = cos(angle);
                
                // Rotation
                float dotX = rawX * c - rawY * s;
                float dotY = rawX * s + rawY * c;
                
                float square_shape = max(abs(dotX), abs(dotY));
                float size = 1.08 - smoothstep1;
                float frontal_mask = step(0.0, dot(nFragWorld, forward));
                
                reflection = smoothstep(size + 0.01, size, square_shape) * frontal_mask;
            #else
                float astro_vector = max(dot(nfragPos, nastroPos), 0.0);
                reflection = smoothstep(smoothstep1, 1.0, astro_vector);
            #endif

            return clamp(
                (reflection - 0.165) *
                clamp(lmcoord.y, 0.0, 1.0) *
                (1.0 - rainStrength) * day_blend_float(10.0, 10.0, 5.0), 0.0, 100.0);
        }
    #endif
#endif

vec3 normal_waves(vec3 pos) {
    float speed = frameTimeCounter;

    // Rotation matrices for natural wave flow directions
    float angle1 = 0.698; // ~40 degrees
    float s1 = sin(angle1);
    float c1 = cos(angle1);
    mat2 rot1 = mat2(c1, -s1, s1, c1);

    float angle2 = 1.047; // ~60 degrees  
    float s2 = sin(angle2);
    float c2 = cos(angle2);
    mat2 rot2 = mat2(c2, -s2, s2, c2);

    vec2 base_coord = pos.xy - pos.z * 0.2;

    // Layer 1: Primary ocean swell - large, slow movement
    vec2 swell_coord = base_coord * 0.06 + vec2(speed * 0.025, speed * 0.018);
    vec2 wave_1 = texture2D(noisetex, swell_coord).rg - 0.5;
    wave_1 *= 0.8;

    // Layer 2: Cross current - opposing direction for natural look
    vec2 cross_coord = rot1 * base_coord * 0.09 - vec2(speed * 0.03, speed * 0.012);
    vec2 wave_2 = texture2D(noisetex, cross_coord).rg - 0.5;
    wave_2 *= 0.65;

    // Layer 3: Surface ripples - medium detail
    vec2 ripple_coord = rot2 * base_coord * 0.18 + vec2(speed * 0.05, -speed * 0.035);
    vec2 wave_3 = texture2D(noisetex, ripple_coord).rg - 0.5;
    wave_3 *= 0.5;

    // Layer 4: Micro detail / shimmer - fine sparkle
    vec2 micro_coord = base_coord * 0.35 + vec2(-speed * 0.07, speed * 0.04);
    vec2 wave_4 = texture2D(noisetex, micro_coord).rg - 0.5;
    wave_4 *= 0.3;

    // Layer 5: Flow distortion - very large scale drift
    vec2 flow_coord = rot1 * base_coord * 0.04 + vec2(speed * 0.015, speed * 0.01);
    vec2 wave_5 = texture2D(noisetex, flow_coord).rg - 0.5;
    wave_5 *= 0.45;

    // Rain increases surface ripples, dampens deep swells
    float rain_ripple_boost = 1.0 + rainStrength * 1.5;
    float rain_swell_dampen = 1.0 - rainStrength * 0.3 * visible_sky;

    vec2 partial_wave = (wave_1 * rain_swell_dampen + wave_5 * rain_swell_dampen)
                      + (wave_2 + wave_3 * rain_ripple_boost + wave_4 * rain_ripple_boost);

    vec3 final_wave = vec3(
        partial_wave,
        WATER_TURBULENCE - (rainStrength * 0.4 * WATER_TURBULENCE * visible_sky)
    );

    return normalize(final_wave);
}

vec3 refraction(vec3 fragpos, vec3 color, vec3 refraction) {
    vec2 pos = gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y);

    #if REFRACTION == 1
        pos = pos + refraction.xy * (0.075 / (1.0 + length(fragpos) * 0.4));
    #endif

    float water_absortion;
    if (isEyeInWater == 0) {
        float water_distance =
        2.0 * near * far / (far + near - (2.0 * gl_FragCoord.z - 1.0) * (far - near));

        float earth_distance = texture2D(depthtex1, pos.xy).r;
        earth_distance =
            2.0 * near * far / (far + near - (2.0 * earth_distance - 1.0) * (far - near));

        #if defined DISTANT_HORIZONS
            float earth_distance_dh = texture2D(dhDepthTex1, pos.xy).r;
            earth_distance_dh =
                2.0 * dhNearPlane * dhFarPlane / (dhFarPlane + dhNearPlane - (2.0 * earth_distance_dh - 1.0) * (dhFarPlane - dhNearPlane));
            earth_distance = min(earth_distance, earth_distance_dh);
        #endif

        water_absortion = earth_distance - water_distance;
        water_absortion *= water_absortion;
        water_absortion = (1.0 / -((water_absortion * WATER_ABSORPTION) + 1.33)) + 1.0;
    } else {
        water_absortion = 0.0;
    }

    return mix(texture2D(gaux1, pos.xy).rgb, color, water_absortion);
}

vec3 get_normals(vec3 bump, vec3 fragpos) {
    float NdotE = abs(dot(water_normal, normalize(fragpos)));

    bump *= vec3(NdotE) + vec3(0.05, 0.1, 1.0 - NdotE);

    mat3 tbn_matrix = mat3(
        tangent.x, binormal.x, water_normal.x,
        tangent.y, binormal.y, water_normal.y,
        tangent.z, binormal.z, water_normal.z
    );

    return normalize(bump * tbn_matrix);
}

vec4 reflection_calc(vec3 fragpos, vec3 normal, vec3 reflected, inout float infinite, float dither) {
    #if SSR_TYPE == 0  // Flipped image
        #if defined DISTANT_HORIZONS
            vec3 pos = camera_to_screen(fragpos + reflected * 768.0);
        #else
            vec3 pos = camera_to_screen(fragpos + reflected * 76.0);
        #endif
    #else  // Raymarch
        vec3 pos = fast_raymarch(reflected, fragpos, infinite, dither);
    #endif
    float pos_y_normalized = pos.y / RENDER_SCALE;

    float border =
        clamp((1.0 - (max(0.0, abs(pos_y_normalized - 0.5)) * 2.0)) * 50.0, 0.0, 1.0);

    border = clamp(border - pow(pos_y_normalized, 10.0), 0.0, 1.0);

    pos.x = abs(pos.x);

    if (pos.x > RENDER_SCALE) {
        pos.x = RENDER_SCALE - (pos.x - RENDER_SCALE);
    }
    
    return vec4(texture2D(gaux1, pos.xy).rgb, border);
}

vec3 water_shader(
    vec3 fragpos,
    vec3 normal,
    vec3 color,
    vec3 sky_reflect,
    vec3 reflected,
    float fresnel,
    float visible_sky,
    float dither,
    vec3 light_color
) {
    vec4 reflection = vec4(0.0);
    float infinite = 1.0;

    #if REFLECTION == 1
        reflection =
            reflection_calc(fragpos, normal, reflected, infinite, dither);
    #endif

    reflection.rgb = mix(
        sky_reflect * visible_sky,
        reflection.rgb,
        reflection.a
    );

    #ifdef VANILLA_WATER
        fresnel *= 0.8;
    #endif

    #if SUN_REFLECTION > 0
        #ifndef NETHER
            #ifndef THE_END
                return mix(color, reflection.rgb, fresnel * REFLEX_INDEX) +
                    vec3(sun_reflection(reflect(normalize(fragpos), normal), 0.999)) * light_color * infinite * visible_sky * day_blend(vec3(1.0, 1.0, 0.35), vec3(1.0, 1.0, 0.35), vec3(1.0));          
            #else
                return mix(color, reflection.rgb, fresnel * REFLEX_INDEX);
            #endif
        #else
            return mix(color, reflection.rgb, fresnel * REFLEX_INDEX);
        #endif
    #else
        return mix(color, reflection.rgb, fresnel * REFLEX_INDEX);
    #endif
}

//  GLASS

vec4 cristal_reflection_calc(vec3 fragpos, vec3 normal, inout float infinite, float dither) {
    #if SSR_TYPE == 0
        #if defined DISTANT_HORIZONS
            vec3 reflected_vector = reflect(normalize(fragpos), normal) * 768.0;
        #else
            vec3 reflected_vector = reflect(normalize(fragpos), normal) * 76.0;
        #endif
            vec3 pos = camera_to_screen(fragpos + reflected_vector);
    #else
        vec3 reflected_vector = reflect(normalize(fragpos), normal);
        vec3 pos = fast_raymarch(reflected_vector, fragpos, infinite, dither);

        if (pos.x > 99.0) { // Fallback
            #if defined DISTANT_HORIZONS
                pos = camera_to_screen(fragpos + reflected_vector * 768.0);
            #else
                pos = camera_to_screen(fragpos + reflected_vector * 76.0);
            #endif
        }
    #endif
    
    #ifdef FSR
        float pos_y_normalized = pos.y / RENDER_SCALE;

        float border =
            clamp((1.0 - (max(0.0, abs(pos_y_normalized - 0.5)) * 2.0)), 0.0, 1.0);

        border = clamp(border - square_pow(pos_y_normalized), 0.0, 1.0);

        pos.x = abs(pos.x);

        if (pos.x > RENDER_SCALE) {
            pos.x = RENDER_SCALE - (pos.x - RENDER_SCALE);
        }
    #else
        float border_x = max(-fourth_pow(abs(2.0 * pos.x - 1.0)) + 1.0, 0.0);
        float border_y = max(-fourth_pow(abs(2.0 * pos.y - 1.0)) + 1.0, 0.0);
        float border = min(border_x, border_y);
    #endif
    
    return vec4(texture2D(gaux1, pos.xy).rgb, border);
}

vec4 cristal_shader(
    vec3 fragpos,
    vec3 normal,
    vec4 color,
    vec3 sky_reflection,
    float fresnel,
    float visible_sky,
    float dither,
    vec3 light_color
) {
    vec4 reflection = vec4(0.0);
    float infinite = 0.0;

    #if REFLECTION == 1
        reflection = cristal_reflection_calc(fragpos, normal, infinite, dither);
    #endif

    sky_reflection = mix(color.rgb, sky_reflection, visible_sky * visible_sky);

    reflection.rgb = mix(
        sky_reflection,
        reflection.rgb,
        reflection.a
    );

    color.rgb = mix(color.rgb, sky_reflection, fresnel);
    color.rgb = mix(color.rgb, reflection.rgb, fresnel);

    color.a = mix(color.a, 1.0, fresnel);

    #if SUN_REFLECTION > 0
        #ifndef NETHER
            #ifndef THE_END
                return color + vec4(
                    mix(
                            vec3(sun_reflection(reflect(normalize(fragpos), normal), 0.99) * 0.1 * light_color * infinite * day_blend(vec3(1.0, 1.0, 0.15), vec3(1.0, 1.0, 0.15), vec3(1.0))),
                        vec3(0.0),
                        reflection.a
                    ),
                    0.0
                );
            #else
            return color;
        #endif
        #else
            return color;
        #endif
    #else
        return color;
    #endif
}
