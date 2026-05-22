/* Aurora Fantasy - ao.glsl
Enhanced GTAO-inspired ambient occlusion with multi-directional sampling.
Based on old Capt Tatsu's implementation, enhanced with horizon-based approach.
*/

float dbao(float dither) {
    float ao = 0.0;

    float inv_steps = 1.0 / clamp(AOSTEPS * RENDER_SCALE, 2.0, 10.0);
    vec2 offset;
    float n;
    float dither_x;

    float d = texture2DLod(depthtex0, texcoord.xy * RENDER_SCALE, 0.0).r;
    float hand_check = d < 0.56 ? 1024.0 : 1.0;
    d = ld(d);

    float sd = 0.0;
    float angle = 0.0;
    float dist = 0.0;
    float far_and_check = hand_check * 2.0 * far;
    vec2 scale = vec2(inv_aspect_ratio, 1.0) * (fov_y_inv / (d * far));
    vec2 scale_factor = scale * inv_steps;
    float sample_d;

    // Multi-directional sampling for better coverage
    float total_weight = 0.0;
    
    for (int i = 0; i < clamp(AOSTEPS * RENDER_SCALE, 2.0, 10.0); i++) {
        dither_x = (i + dither);
        n = fract(dither_x * 1.6180339887) * 3.141592653589793;
        offset = vec2(cos(n), sin(n)) * dither_x * scale_factor;

        // Primary sample
        sd = ld(texture2DLod(depthtex0, texcoord.xy * RENDER_SCALE + offset, 0.0).r);
        sample_d = (d - sd) * far_and_check;
        angle = clamp(0.5 - sample_d, 0.0, 1.0);
        dist = clamp(0.25 * sample_d - 1.0, 0.0, 1.0);

        // Opposite sample
        sd = ld(texture2DLod(depthtex0, texcoord.xy * RENDER_SCALE - offset, 0.0).r);
        sample_d = (d - sd) * far_and_check;
        angle += clamp(0.5 - sample_d, 0.0, 1.0);
        dist += clamp(0.25 * sample_d - 1.0, 0.0, 1.0);

        // Cross-axis sample for thicker AO in corners
        vec2 cross_offset = vec2(-offset.y, offset.x) * 0.5;
        sd = ld(texture2DLod(depthtex0, texcoord.xy * RENDER_SCALE + cross_offset, 0.0).r);
        float cross_d = (d - sd) * far_and_check;
        float cross_ao = clamp(0.5 - cross_d, 0.0, 1.0) + clamp(0.25 * cross_d - 1.0, 0.0, 1.0);

        ao += clamp(angle + dist, 0.0, 1.0) + cross_ao * 0.3;
        total_weight += 1.3;
    }
    ao /= max(total_weight, 1.0);

    // Distance-based fade (AO fades at distance)
    float dist_fade = 1.0 - smoothstep(0.6, 0.95, d * far / far);
    ao *= dist_fade;

    return sqrt((ao * clamp(AO_STRENGTH, 0.0, 1.0)) + (1.0 - clamp(AO_STRENGTH, 0.0, 1.0)));
}
