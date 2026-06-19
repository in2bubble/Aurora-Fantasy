/* Aurora Fantasy - blur.glsl
Blur functions.

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

uniform float near;
uniform float far;

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

vec3 noised_blur(vec4 color_depth, sampler2D image, vec2 coords, float force, float dither) {
    if(fragment_cull()) discard;
    vec3 block_color = color_depth.rgb;
    float the_depth = color_depth.a;
    float blur_radius = 0.0;

    if (the_depth > 0.56) {  // No hands
        float pixelDistance = ld(the_depth) * far;
        float focusDistance = ld(centerDepthSmooth) * far;

        // Ensure focus distance is reasonable
        focusDistance = max(focusDistance, 0.5);

        // Near-field protection: completely disable blur for objects close to player
        // Objects under 3.5 blocks are kept sharp, and we smoothly fade in blur up to 5.5 blocks
        float nearFade = clamp((pixelDistance - 3.5) / 2.0, 0.0, 1.0);

        // Acceptable focus range (depth of field depth) which increases with focus distance
        float focusRange = 0.5 + focusDistance * 0.08;

        // Calculate distance difference outside the focus range
        float diff = max(abs(pixelDistance - focusDistance) - focusRange, 0.0);

        // Calculate blur amount (0.0 to 1.0)
        // Transition speed scales with distance so it feels natural
        float blurScale = 4.0 + focusDistance * 0.12;
        float blurFactor = clamp(diff / blurScale, 0.0, 1.0);

        // Apply near fade
        blurFactor *= nearFade;

        // Fade out blur when focusing on the sky (depth of 1.0)
        float skyFade = clamp((1.0 - centerDepthSmooth) * 10000.0, 0.0, 1.0);
        blurFactor *= skyFade;

        // Apply near-focus filter: only blur when focusing on close objects (autofocus distance < 12.0 blocks)
        float closeFocusFade = clamp((12.0 - focusDistance) / 4.0, 0.0, 1.0);
        blurFactor *= closeFocusFade;

        // Crosshair protection: ensure the exact aimed-at area is never blurred
        vec2 centerDist = coords - vec2(0.5);
        centerDist.x /= inv_aspect_ratio;
        float centerFade = smoothstep(0.015, 0.04, length(centerDist));
        blurFactor *= centerFade;

        // Convert blur factor to texture coordinate space blur radius
        // The scaling factor (0.04) ensures the blur remains visually safe and attractive
        blur_radius = blurFactor * force * 0.04 * fov_y_inv;
        blur_radius = min(blur_radius, 0.05); // Cap to prevent extreme ghosting
    }

    if (blur_radius > min(pixel_size_x, pixel_size_y)) {
        vec3 blur_sample = vec3(0.0);
        vec2 blur_radius_vec = vec2(blur_radius * inv_aspect_ratio, blur_radius);

        float dither_base = dither;
        dither *= 6.283185307179586;

        float current_radius = (0.25 + dither_base);
        vec2 offset = vec2(cos(dither), sin(dither)) * blur_radius_vec * current_radius;

        blur_sample += texture2D(image, coords + offset, -2.0).rgb;
        blur_sample += texture2D(image, coords - offset, -2.0).rgb;

        block_color = blur_sample * 0.5;
    }

    return block_color;
}
