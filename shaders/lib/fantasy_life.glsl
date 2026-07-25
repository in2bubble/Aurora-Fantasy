/* Aurora Fantasy - shared nocturnal life field

   Flowers and nearby fireflies sample the same stable world-space field.
   This makes a flower brighten only while a local swarm is active instead
   of behaving like a permanently emissive lamp.
*/

#ifndef FANTASY_LIFE_GLSL
#define FANTASY_LIFE_GLSL

float fantasy_life_hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

vec3 fantasy_life_hash33(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

float fantasy_firefly_visit(vec3 worldPosition, float time) {
    vec3 lifeCell = floor(
        worldPosition * vec3(0.28, 0.40, 0.28));
    float seed = fantasy_life_hash13(lifeCell + 11.73);

    float visitWave = max(sin(
        time * (0.34 + seed * 0.14)
        + seed * 6.2831853), 0.0);
    float visitEnvelope = visitWave * visitWave;
    visitEnvelope *= visitEnvelope;

    float wingFlicker = 0.84 + 0.16 * sin(
        time * (4.2 + seed * 1.8)
        + seed * 21.7);
    return clamp(
        visitEnvelope * wingFlicker,
        0.0, 1.0);
}

vec3 fantasy_firefly_life_color(vec3 worldPosition) {
    vec3 lifeCell = floor(
        worldPosition * vec3(0.28, 0.40, 0.28));
    float hueSeed = fantasy_life_hash13(lifeCell + 37.41);
    return mix(
        vec3(1.0, 0.62, 0.20),
        vec3(0.30, 0.72, 1.0),
        smoothstep(0.68, 0.94, hueSeed));
}

float fantasy_player_disturbance(
    vec3 worldPosition,
    vec3 playerPosition
) {
    vec3 playerDelta = worldPosition - playerPosition;
    playerDelta.y *= 0.58;
    float playerDistanceSquared = dot(
        playerDelta, playerDelta);
    return 1.0 - smoothstep(
        3.24, 27.04, playerDistanceSquared);
}

float fantasy_plant_recovery_disturbance(
    vec3 worldPosition,
    vec3 playerPosition
) {
    vec3 playerDelta = worldPosition - playerPosition;
    playerDelta.y *= 0.54;
    float playerDistanceSquared = dot(
        playerDelta, playerDelta);
    float recoveryField = 1.0 - smoothstep(
        4.84, 51.84, playerDistanceSquared);
    return pow(clamp(recoveryField, 0.0, 1.0), 0.82);
}

float fantasy_perch_selector(vec3 worldPosition) {
    float perchSeed = fantasy_life_hash13(
        floor(worldPosition) + 73.19);
    return smoothstep(0.42, 0.82, perchSeed);
}

float fantasy_plant_tip_mask(vec3 worldPosition) {
    float localHeight = fract(worldPosition.y + 0.001);
    return smoothstep(0.46, 0.88, localHeight);
}

float fantasy_perch_spark_mask(vec3 worldPosition) {
    vec3 blockPosition = floor(worldPosition);
    float sparkSeed = fantasy_life_hash13(
        blockPosition + 91.27);
    vec3 localPosition = fract(worldPosition);
    float sparkHeight = 0.68 + sparkSeed * 0.16;
    float horizontalDistance = length(
        localPosition.xz - vec2(0.5));
    float horizontalCore = 1.0 - smoothstep(
        0.055, 0.22, horizontalDistance);
    float verticalCore = 1.0 - smoothstep(
        0.055, 0.18,
        abs(localPosition.y - sparkHeight));
    return horizontalCore * verticalCore;
}

vec3 fantasy_canopy_orb_center(vec3 worldPosition) {
    const vec3 canopyCellSize = vec3(3.6, 2.8, 3.6);
    vec3 canopyCell = floor(worldPosition / canopyCellSize);
    vec3 orbRandom = fantasy_life_hash33(
        canopyCell + 29.37);
    return (canopyCell + mix(
        vec3(0.24), vec3(0.76), orbRandom))
        * canopyCellSize;
}

#endif
