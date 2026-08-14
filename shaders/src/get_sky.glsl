/* __   ______________
  / /  /  _/_  __/ __/
 / /___/ /  / / / _/
/____/___/ /_/ /___/

Aurora Fantasy 5.4.1 - get_sky.glsl
Sky render. - Renderização do céu. 
*/

vec3 sky_color;

#if AA_TYPE > 0
    float dither = shifted_dither13(gl_FragCoord.xy);
#else
    float dither = dither13(gl_FragCoord.xy);
#endif

dither = (dither - .5) * 0.03125;

#if ((COLOR_SCHEME == 8 && SIMPLE_SKY == 0) || COLOR_SCHEME == 12) && !defined UNKNOWN_DIM // LITE Realistic Plus            
    vec4 fragpos = gbufferProjectionInverse * (vec4(gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y) / RENDER_SCALE, gl_FragCoord.z, 1.0) * 2.0 - 1.0);
    vec3 nfragpos = normalize(fragpos.xyz);
    float n_u = clamp(dot(nfragpos, up_vec) + 0.1 + dither, 0.0, 1.0);

    float raw_blend = pow(n_u, 0.5); // Sky height
    float blend_initial = mix(0.0, 1.0, raw_blend);

    float transition1_start = 0.0; // Horizon start
    float transition_mid_point = 0.6; // Mid sky max
    float transition2_end = 1.0; // Mid sky end

    // - COLOR INTERPOLATIONS - //
    
    #include "/src/current_sky_color.glsl"
    current_low_sky_color = xyz_to_rgb(current_low_sky_color);
    current_mid_sky_color = xyz_to_rgb(current_mid_sky_color);
    current_hi_sky_color = xyz_to_rgb(current_hi_sky_color);

    float t1 = smoothstep(transition_mid_point, transition2_end, blend_initial + (final_sun_factor * day_blend_float(0.0, 0.0, 0.1)));
    float t2 = smoothstep(transition1_start, transition_mid_point, blend_initial - day_blend_float(0.05, 0.1, 0.05) - (final_sun_factor * day_blend_float(0.05, 0.05, 0.0)));

    vec3 temp_sky_color = mix(current_mid_sky_color * biome_sky, current_hi_sky_color * biome_sky, t1);
    sky_color = mix(current_low_sky_color * biome_sky_low, temp_sky_color, t2);

    // Atmospheric scattering enhancement for Realistic+ sky
    #ifdef PREPARE_SHADER
    {
        vec3 viewDir = normalize((gbufferModelViewInverse * vec4(nfragpos, 0.0)).xyz);
        vec3 sunDir = normalize((gbufferModelViewInverse * vec4(normalize(sunPosition), 0.0)).xyz);
        
        // Sun-view angle for Mie scattering (sun glow)
        float cos_theta = dot(viewDir, sunDir);
        
        // Henyey-Greenstein phase function for sun glow
        float g = 0.76;
        float g2 = g * g;
        float mie_phase = (1.0 - g2) / (4.0 * 3.14159 * pow(1.0 + g2 - 2.0 * g * cos_theta, 1.5));
        
        // Rayleigh phase
        float rayleigh_phase = 0.75 * (1.0 + cos_theta * cos_theta);
        
        // Rayleigh scattering color (blue wavelength scatter more)
        vec3 rayleigh_color = vec3(0.15, 0.35, 0.65) * rayleigh_phase * 0.08;
        
        // Mie (sun glow) warm color near sun
        vec3 mie_color = vec3(1.0, 0.85, 0.6) * mie_phase * 0.15;
        
        // Height-based atmospheric density
        float height_factor = clamp(viewDir.y + 0.1, 0.0, 1.0);
        float atmosphere_density = exp(-height_factor * 2.0);
        
        // Combine: stronger at horizon, weaker at zenith
        vec3 scatter = (rayleigh_color + mie_color) * atmosphere_density;
        
        // Day/night fade: only apply during daytime
        float scatter_strength = light_mix * (1.0 - rainStrength * 0.8);
        sky_color += scatter * scatter_strength;
    }
    #endif
#elif COLOR_SCHEME == 11 // Vanilla
    vec4 fragpos =
        gbufferProjectionInverse *
        (vec4(gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y) / RENDER_SCALE, gl_FragCoord.z, 1.0) * 2.0 - 1.0);
    vec3 nfragpos = normalize(fragpos.xyz);
    float n_u = clamp(dot(nfragpos, up_vec) - 0.1 + dither, 0.0, 1.0);
    
    float raw_blend = pow(n_u, 0.22); // Sky height
    float blend_initial = mix(0.0, 1.0, raw_blend);

    float transition1_start = 0.0; // Horizon start
    float transition_mid_point = 0.65; // Mid sky max
    float transition2_end = 1.0; // Mid sky end

    // - COLOR INTERPOLATIONS - //
    
    #include "/src/current_sky_color.glsl"
    current_low_sky_color = xyz_to_rgb(current_low_sky_color);
    current_hi_sky_color = xyz_to_rgb(current_hi_sky_color);

    float t2 = smoothstep(transition1_start, transition_mid_point, blend_initial - 0.2 - (final_sun_factor * day_blend_float(0.05, 0.05, 0.05)));

    sky_color = mix(current_low_sky_color, current_hi_sky_color, t2);
#else // Using legacy color interpolation.
    vec4 fragpos =
        gbufferProjectionInverse *
        (vec4(gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y) / RENDER_SCALE, gl_FragCoord.z, 1.0) * 2.0 - 1.0);
    vec3 nfragpos = normalize(fragpos.xyz);
    float n_u = clamp(dot(nfragpos, up_vec) + dither, 0.0, 1.0);
    
    sky_color = mix(low_sky_color, hi_sky_color, smoothstep(0.0, 1.0, pow(n_u, 0.333)));
    sky_color = xyz_to_rgb(sky_color);
#endif

#ifdef GBUFFER_SKYBASIC
    vec4 background_color = vec4(sky_color, 1.0);
#endif

#ifdef PREPARE_SHADER
    vec3 block_color = sky_color;
#endif
