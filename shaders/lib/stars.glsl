/* __   ______________
  / /  /  _/_  __/ __/
 / /___/ /  / / / _/
/____/___/ /_/ /___/

Aurora Fantasy 5.4.2 - stars.glsl
Stars render fixed in world space. - Renderização de estrelas fixas no espaço do mundo. 
*/

#include "/lib/render_aux.glsl"

// Cinematic Stars - Custom Procedural Star Field

float star_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Procedural Star Layer
float StarLayer(vec2 uv, float scale, float density, float flickerSpd) {
    vec2 p = uv * scale;
    vec2 id = floor(p);
    vec2 sub = fract(p) - 0.5;
    
    float rnd = star_hash(id);
    if (rnd < (1.0 - density)) return 0.0;
    
    // World-backed twinkling remains continuous across shader reloads.
    float twinkle = 0.6 + 0.4 * sin(persistentTimeSeconds * flickerSpd + rnd * 6.283);
    
    // Organic offset using deterministic hashes to scatter the stars naturally
    vec2 offset = vec2(star_hash(id + 1.0), star_hash(id + 2.0)) - 0.5;
    float d = length(sub - offset * 0.8);
    
    // Smooth falloff for soft star glow
    float glow = 0.003 / (d * d + 0.001);
    
    return glow * twinkle * rnd;
}

vec3 stars(vec3 viewDir) { 
    #if (STAR_SLIDER >= 1 && !defined THE_END && !defined NETHER) || (defined END_STARS && defined THE_END)
        
        vec3 dir = normalize(viewDir);
        
    #ifndef THE_END
        if (sunPathRotation != 0.0) {
            float path_rotation_rad = sunPathRotation * 0.0174532925;
            float tilt_c = cos(path_rotation_rad);
            float tilt_s = sin(-path_rotation_rad);
            float tilted_y = dir.y * tilt_c - dir.z * tilt_s;
            float tilted_z = dir.y * tilt_s + dir.z * tilt_c;
            dir.y = tilted_y; dir.z = tilted_z;
            float angle = sunAngle * 6.4 - 0.12;
            float c = cos(angle); float s = sin(angle);
            float new_x = dir.x * s - dir.z * c;
            float new_z = dir.x * c + dir.z * s;
            dir.x = new_x; dir.z = new_z;
        } else {
            float inv_y = dir.y; dir.y = dir.z; dir.z = -inv_y; 
            float angle = sunAngle * 6.28318530718;
            float c = cos(angle); float s = sin(angle);
            float new_x = dir.x * c - dir.z * s;
            float new_z = dir.x * s + dir.z * c;
            dir.x = new_x; dir.z = new_z;
        }
    #endif

        vec2 uv = cubic_uv(dir); 
        
        vec3 starColor = vec3(0.0);
        
        // 1. Tiny Background (Blue)
        starColor += vec3(0.5, 0.7, 1.0) * StarLayer(uv, 300.0, 0.005, 0.8);
        
        // 2. Medium (Gold)
        starColor += vec3(1.0, 0.9, 0.6) * StarLayer(uv, 150.0, 0.003, 0.5);

        // Masking
        #ifndef THE_END
            float rainMask = 1.0 - rainStrength;
            float globalBrightness = max(STARS_BRIGHTNESS, 0.5) * 3.0; 
            starColor *= day_blend_float_lgcy(0.1, 0.0, 0.9) * globalBrightness * rainMask;
        #else 
            starColor *= vec3(0.75, 0.5, 1.0) * 2.0;
        #endif

        return starColor;
        
    #else
        return vec3(0.0);
    #endif
}
