/* Aurora Fantasy - luma.glsl
Luma related functions.

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
} // Number of luminance of color.

vec3 v3_luma(vec3 color) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    return vec3(luma);
} // Equivalent to saturate(color, 0.0)

float color_average(vec3 color) {
    return (color.r + color.g + color.b) / 3;
} // Color average between red, green, and blue channels.

vec3 saturate(vec3 color, float saturation) {
    vec3 luma = vec3(luma(color));
    return mix(luma, color, saturation);
} // Apply saturation to a color based on a float, 1.0 is the default

vec4 saturate_v4(vec4 color, float saturation) {
    vec3 luma = vec3(luma(color.rgb));
    return mix(vec4(luma, color.a), vec4(color.rgb, color.a), saturation);
} // Same as saturate, but for vec4, designed to not affect alpha channel (transparency.)

vec3 vibrance(vec3 color, float amount) {
    float sat = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));

    float increase_factor = (1.0 - sat) * amount;
    float final_sat = 1.0 + max(0.0, increase_factor);

    return saturate(color, final_sat);
} // Only saturates low-saturation colors.

// Night Vision is an illumination aid, not a material tint. The old path
// multiplied albedo by (0.0, 0.6, 0.2), destroying the red and blue channels.
// Lift every lighting channel to the same floor, retain brighter authored
// light, and gently neutralize only the added illumination.
vec3 night_vision_lighting(vec3 sceneLight, float potionStrength) {
    float response = clamp(potionStrength * NIGHT_VISION_BOOST, 0.0, 1.0);
    float sceneLuma = luma(max(sceneLight, vec3(0.0)));
    float visionFloor = NIGHT_VISION_LUMA_FLOOR;

    // Concentrate the potion lift in genuinely dark illumination. The former
    // fixed 0.77 floor also replaced already readable light and, after the
    // night exposure pass, made terrain appear like a pale overcast day.
    float darknessNeed = 1.0 - smoothstep(
        visionFloor * 0.58,
        visionFloor * 1.65,
        sceneLuma
    );
    vec3 liftedLight = max(max(sceneLight, vec3(0.0)), vec3(visionFloor));
    liftedLight = mix(
        liftedLight,
        vec3(luma(liftedLight)),
        darknessNeed * 0.055
    );
    return mix(sceneLight, liftedLight, response * darknessNeed);
}
