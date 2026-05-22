/* Aurora Fantasy - atmosphere.glsl
Simplified physically-based atmospheric scattering.
Rayleigh + Mie scattering for realistic sky gradients.
*/

// Rayleigh scattering coefficients (wavelength-dependent)
const vec3 RAYLEIGH_COEFF = vec3(5.8e-3, 13.5e-3, 33.1e-3); // RGB
const float MIE_COEFF = 2.0e-3;
const float RAYLEIGH_HEIGHT = 8000.0;
const float MIE_HEIGHT = 1200.0;
const float EARTH_RADIUS = 6371000.0;
const float ATMO_RADIUS = 6471000.0;

// Henyey-Greenstein phase function for Mie scattering
float hg_phase(float cosTheta, float g) {
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * 3.14159265 * denom * sqrt(denom));
}

// Rayleigh phase function
float rayleigh_phase(float cosTheta) {
    return 0.75 * (1.0 + cosTheta * cosTheta);
}

// Simplified ray-sphere intersection
float ray_sphere_exit(vec3 origin, vec3 dir, float radius) {
    float b = dot(origin, dir);
    float c = dot(origin, origin) - radius * radius;
    float d = b * b - c;
    if (d < 0.0) return -1.0;
    return -b + sqrt(d);
}

// Compute atmospheric scattering for a given view direction
// sunDir: normalized sun direction
// viewDir: normalized view direction  
// Returns: scattered light color
vec3 atmosphere_scatter(vec3 viewDir, vec3 sunDir, float sunIntensity) {
    const int PRIMARY_STEPS = 8;
    const int LIGHT_STEPS = 4;

    vec3 origin = vec3(0.0, EARTH_RADIUS + 100.0, 0.0); // Observer slightly above surface

    float ray_length = ray_sphere_exit(origin, viewDir, ATMO_RADIUS);
    if (ray_length < 0.0) return vec3(0.0);

    float step_size = ray_length / float(PRIMARY_STEPS);
    float cosTheta = dot(viewDir, sunDir);

    // Phase functions
    float rayleigh_p = rayleigh_phase(cosTheta);
    float mie_p = hg_phase(cosTheta, 0.76);

    vec3 total_rayleigh = vec3(0.0);
    float total_mie = 0.0;
    float optical_depth_r = 0.0;
    float optical_depth_m = 0.0;

    for (int i = 0; i < PRIMARY_STEPS; i++) {
        vec3 sample_pos = origin + viewDir * (float(i) + 0.5) * step_size;
        float height = length(sample_pos) - EARTH_RADIUS;

        // Density at this height
        float density_r = exp(-height / RAYLEIGH_HEIGHT) * step_size;
        float density_m = exp(-height / MIE_HEIGHT) * step_size;

        optical_depth_r += density_r;
        optical_depth_m += density_m;

        // Light ray (sun direction) optical depth
        float light_ray_len = ray_sphere_exit(sample_pos, sunDir, ATMO_RADIUS);
        float light_step = light_ray_len / float(LIGHT_STEPS);
        float light_od_r = 0.0;
        float light_od_m = 0.0;

        for (int j = 0; j < LIGHT_STEPS; j++) {
            vec3 light_pos = sample_pos + sunDir * (float(j) + 0.5) * light_step;
            float light_height = length(light_pos) - EARTH_RADIUS;
            light_od_r += exp(-light_height / RAYLEIGH_HEIGHT) * light_step;
            light_od_m += exp(-light_height / MIE_HEIGHT) * light_step;
        }

        // Total extinction
        vec3 attenuation = exp(-(RAYLEIGH_COEFF * (optical_depth_r + light_od_r) + MIE_COEFF * (optical_depth_m + light_od_m)));

        total_rayleigh += density_r * attenuation;
        total_mie += density_m * attenuation.r; // Use red channel approximation for Mie
    }

    vec3 color = sunIntensity * (total_rayleigh * RAYLEIGH_COEFF * rayleigh_p + total_mie * MIE_COEFF * mie_p);

    return color;
}

// Simplified version for use in sky rendering (less expensive)
vec3 atmosphere_simple(vec3 viewDir, vec3 sunDir) {
    float sunHeight = sunDir.y;
    float viewHeight = max(viewDir.y, 0.0);

    // Rayleigh scattering approximation  
    vec3 rayleigh = RAYLEIGH_COEFF * rayleigh_phase(dot(viewDir, sunDir));

    // Optical depth approximation
    float zenithAngle = acos(max(viewHeight, 0.001));
    float optical_path = 1.0 / (cos(zenithAngle) + 0.15 * pow(93.885 - degrees(zenithAngle), -1.253));

    // Sun extinction through atmosphere
    vec3 extinction = exp(-RAYLEIGH_COEFF * optical_path * 2.0);

    // Sun near horizon: more red/orange, higher: more blue
    float sunOptical = 1.0 / (max(sunHeight, 0.001) + 0.15 * pow(93.885 - degrees(acos(max(sunHeight, 0.001))), -1.253));
    vec3 sunExtinction = exp(-RAYLEIGH_COEFF * sunOptical * 5.0);

    // Mie scattering (forward scattering near sun)
    float cosTheta = dot(viewDir, sunDir);
    float mie = hg_phase(cosTheta, 0.76) * MIE_COEFF;

    // Combine
    vec3 scatter = rayleigh * sunExtinction * (1.0 - exp(-optical_path * RAYLEIGH_COEFF));
    scatter += vec3(mie) * sunExtinction;

    // Intensity based on sun height
    float intensity = max(sunHeight + 0.1, 0.0) * 20.0;

    return scatter * intensity;
}
