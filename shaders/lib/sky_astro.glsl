/* Aurora Fantasy - sky_astro.glsl
Draws the screen-space sun and moon. Include before volumetric clouds so clouds
can occlude the discs and halos naturally.
*/

uniform sampler2D auroraMoonTexture;
uniform sampler2D auroraSunTexture;

// Roll bright painted texels into a controlled HDR shoulder. Limiting luminance
// instead of individual RGB channels keeps the original texture hue and local
// contrast, while still leaving enough HDR energy for the bloom pass.
vec3 astro_soft_knee_luma(vec3 color, float knee, float ceiling) {
    float sourceLuma = max(luma(color), 0.0001);
    float shoulderWidth = max(ceiling - knee, 0.0001);
    float shoulder = max(sourceLuma - knee, 0.0);
    float limitedLuma = min(sourceLuma, knee)
        + shoulderWidth * (1.0 - exp(-shoulder / shoulderWidth));
    return color * (limitedLuma / sourceLuma);
}

vec3 draw_sky_astro(vec3 sky_color, vec2 uv, bool is_sky_pixel) {
    if (!is_sky_pixel) return sky_color;

    float fovScale = gbufferProjection[1][1] * 0.5;

    float sunRad = 0.05200;
    float sunCoronaRad = 0.06600;
    float sunInnerGlowRad = 0.13800;
    float sunOuterGlowRad = 0.22800;
    // A painted fantasy moon: present enough to anchor the sky without taking
    // the enormous scale of the concept references literally.
    float moonRad = 0.06100;
    float moonCoronaRad = 0.07400;
    float moonInnerGlowRad = 0.14800;
    float moonOuterGlowRad = 0.24800;

    vec3 sunWorldDir = normalize((gbufferModelViewInverse * vec4(normalize(sunPosition), 0.0)).xyz);
    vec3 moonWorldDir = -sunWorldDir;
    float sunHorizonFade = smoothstep(-0.05, 0.05, sunWorldDir.y);
    float moonHorizonFade = smoothstep(-0.05, 0.05, moonWorldDir.y);
    float weatherVisibility = 1.0 - rainStrength;

    if (sunHorizonFade > 0.001) {
        // Direction-space reconstruction keeps the painted sun fixed to the
        // celestial sphere and gives it the same stable motion as the moon.
        vec4 sunViewRayH = gbufferProjectionInverse
            * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
        vec3 sunViewRay = normalize(
            sunViewRayH.xyz / max(abs(sunViewRayH.w), 0.00001));
        vec3 sunViewWorldDir = normalize(
            (gbufferModelViewInverse * vec4(sunViewRay, 0.0)).xyz);

        vec3 sunOrbitAxis = vec3(1.0, 0.0, 0.0);
        if (abs(dot(sunOrbitAxis, sunWorldDir)) > 0.96) {
            sunOrbitAxis = vec3(0.0, 0.0, 1.0);
        }
        vec3 sunRight = normalize(cross(sunOrbitAxis, sunWorldDir));
        vec3 sunUp = normalize(cross(sunWorldDir, sunRight));
        float sunForward = dot(sunViewWorldDir, sunWorldDir);

        if (sunForward > 0.0) {
            vec2 sunPlane = vec2(
                dot(sunViewWorldDir, sunRight),
                dot(sunViewWorldDir, sunUp)) / sunForward;
            float sunDist = length(sunPlane);
            float sunSceneExposure = clamp(
                texture2D(gaux3, vec2(0.5)).r,
                0.65,
                3.50);

            vec3 sunSkyPerceptual = sqrt(max(sky_color, vec3(0.0)));
            float sunSkyLuma = max(luma(sunSkyPerceptual), 0.001);
            vec3 localSunSkyHue = clamp(
                sunSkyPerceptual / sunSkyLuma,
                vec3(0.42),
                vec3(1.64));
            float sunSkyMax = max(
                sunSkyPerceptual.r,
                max(sunSkyPerceptual.g, sunSkyPerceptual.b));
            float sunSkyMin = min(
                sunSkyPerceptual.r,
                min(sunSkyPerceptual.g, sunSkyPerceptual.b));
            float sunSkySaturation = (sunSkyMax - sunSkyMin)
                / max(sunSkyMax, 0.001);
            float sunSkyPresence = smoothstep(
                0.08,
                0.58,
                sunSkySaturation);

            // Warm peach near the horizon, golden through the day and softly
            // pearlescent near zenith, continuously blended with the live sky.
            float sunAltitude = clamp(sunWorldDir.y, 0.0, 1.0);
            float riseToDay = smoothstep(0.015, 0.38, sunAltitude);
            float dayToZenith = smoothstep(0.42, 0.90, sunAltitude);
            vec3 sunStageTint = mix(
                vec3(1.10, 0.72, 0.50),
                vec3(1.03, 0.94, 0.76),
                riseToDay);
            sunStageTint = mix(
                sunStageTint,
                vec3(1.00, 1.02, 0.96),
                dayToZenith);
            sunStageTint = mix(
                sunStageTint,
                localSunSkyHue,
                mix(0.08, 0.16, sunSkyPresence));

            float sunAA = max(
                fwidth(sunDist) * 1.10,
                0.65 / max(viewHeight * fovScale, 1.0));
            if (sunDist < sunRad + sunAA) {
                float analyticAlpha = 1.0 - smoothstep(
                    sunRad - sunAA,
                    sunRad + sunAA,
                    sunDist);
                vec2 sunUV = sunPlane / sunRad;
                vec2 sunTexcoord = vec2(
                    0.5 + sunUV.x * 0.435,
                    0.5 - sunUV.y * 0.435);
                vec4 paintedSun = texture2D(
                    auroraSunTexture,
                    sunTexcoord);

                float sunTextureLuma = clamp(
                    luma(paintedSun.rgb),
                    0.0,
                    1.0);
                vec3 sunTextureChroma = clamp(
                    paintedSun.rgb / max(sunTextureLuma, 0.001),
                    vec3(0.30),
                    vec3(2.20));
                float sunLumaFloor = mix(
                    0.34,
                    0.40,
                    dayToZenith);
                float sunLumaCeiling = mix(
                    1.03,
                    1.10,
                    dayToZenith);
                float paintedSunLuma = mix(
                    sunLumaFloor,
                    sunLumaCeiling,
                    pow(sunTextureLuma, 1.65));
                float softSolarLuma = mix(
                    sunLumaFloor,
                    sunLumaCeiling,
                    0.50);
                paintedSunLuma = mix(
                    softSolarLuma,
                    paintedSunLuma,
                    mix(0.94, 0.90, dayToZenith));
                float solarTextureColor = mix(
                    0.78,
                    0.68,
                    dayToZenith);
                vec3 sunColor = mix(
                    vec3(paintedSunLuma),
                    sunTextureChroma * paintedSunLuma,
                    solarTextureColor);
                sunColor *= sunStageTint;

                float sunRadialLight = clamp(
                    1.0 - sunDist / sunRad,
                    0.0,
                    1.0);
                sunColor *= mix(
                    0.96,
                    1.04,
                    pow(sunRadialLight, 0.55));

                // Equal-luminance grading lets the entire solar surface accept
                // dawn/sky colors while preserving its plasma structures.
                float sunSurfaceLuma = max(luma(sunColor), 0.001);
                vec3 sunSkySurfaceColor = localSunSkyHue
                    * sunSurfaceLuma;
                sunColor = mix(
                    sunColor,
                    sunSkySurfaceColor,
                    mix(0.05, 0.10, sunSkyPresence));
                sunColor = max(
                    sunColor,
                    vec3(0.22, 0.16, 0.10));
                sunColor = astro_soft_knee_luma(
                    sunColor,
                    0.82,
                    1.12);
                sunColor /= max(
                    pow(sunSceneExposure, 0.22),
                    0.90);

                float alpha = analyticAlpha * paintedSun.a
                    * weatherVisibility * sunHorizonFade;
                sky_color = mix(sky_color, sunColor, alpha);
            }

            if (sunDist < sunOuterGlowRad) {
                float coronaGlow = 1.0
                    - smoothstep(sunRad, sunCoronaRad, sunDist);
                float innerGlow = 1.0
                    - smoothstep(sunRad, sunInnerGlowRad, sunDist);
                float outerGlow = 1.0
                    - smoothstep(sunRad, sunOuterGlowRad, sunDist);
                coronaGlow *= coronaGlow;
                innerGlow *= innerGlow;
                outerGlow *= outerGlow;
                float outsideDisc = smoothstep(
                    sunRad * 0.97,
                    sunRad * 1.04,
                    sunDist);
                coronaGlow *= outsideDisc;
                innerGlow *= outsideDisc;
                outerGlow *= outsideDisc;

                vec3 sunriseHalo = vec3(1.08, 0.39, 0.17);
                vec3 daylightHalo = vec3(1.04, 0.72, 0.30);
                vec3 zenithHalo = vec3(0.82, 0.92, 1.04);
                vec3 sunHaloColor = mix(
                    sunriseHalo,
                    daylightHalo,
                    riseToDay);
                sunHaloColor = mix(
                    sunHaloColor,
                    zenithHalo,
                    dayToZenith);
                sunHaloColor = mix(
                    sunHaloColor,
                    localSunSkyHue,
                    mix(0.28, 0.44, sunSkyPresence));
                vec3 coronaColor = mix(
                    vec3(1.04, 0.92, 0.70),
                    sunHaloColor,
                    mix(0.28, 0.40, sunSkyPresence));

                float halo = innerGlow * 0.165
                    + outerGlow * 0.045;
                vec3 corona = coronaColor * coronaGlow * 0.42;
                float sunHaloExposureComp = max(
                    pow(sunSceneExposure, 0.30),
                    1.0);
                sky_color += (corona + sunHaloColor * halo)
                    / sunHaloExposureComp
                    * weatherVisibility * sunHorizonFade;
            }
        }
    }

    if (moonHorizonFade > 0.001) {
        // Reconstruct the pixel ray in world direction space. Both the texture
        // and its tangent frame are therefore attached to the celestial sphere,
        // not to screen UVs, eliminating camera-relative moon drift.
        vec4 viewRayH = gbufferProjectionInverse
            * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
        vec3 viewRay = normalize(viewRayH.xyz / max(abs(viewRayH.w), 0.00001));
        vec3 viewWorldDir = normalize(
            (gbufferModelViewInverse * vec4(viewRay, 0.0)).xyz);

        // Minecraft's celestial orbit is centered on the world X axis. A
        // fallback keeps the basis stable with unusual sun-path rotations.
        vec3 orbitAxis = vec3(1.0, 0.0, 0.0);
        if (abs(dot(orbitAxis, moonWorldDir)) > 0.96) {
            orbitAxis = vec3(0.0, 0.0, 1.0);
        }
        vec3 moonRight = normalize(cross(orbitAxis, moonWorldDir));
        vec3 moonUp = normalize(cross(moonWorldDir, moonRight));
        float moonForward = dot(viewWorldDir, moonWorldDir);

        if (moonForward > 0.0) {
            vec2 moonPlane = vec2(
                dot(viewWorldDir, moonRight),
                dot(viewWorldDir, moonUp)) / moonForward;
            float dist = length(moonPlane);
            float moonSceneExposure = clamp(
                texture2D(gaux3, vec2(0.5)).r,
                0.65,
                3.50);
            // Read the live sky color behind every moon/halo fragment. Work in
            // a soft perceptual space and normalize its luminance so the moon
            // borrows the aurora hue without inheriting its exposure.
            vec3 localSkyPerceptual = sqrt(max(sky_color, vec3(0.0)));
            float localSkyLuma = max(luma(localSkyPerceptual), 0.001);
            vec3 localAuroraHue = clamp(
                localSkyPerceptual / localSkyLuma,
                vec3(0.38),
                vec3(1.72));
            float localSkyMax = max(
                localSkyPerceptual.r,
                max(localSkyPerceptual.g, localSkyPerceptual.b));
            float localSkyMin = min(
                localSkyPerceptual.r,
                min(localSkyPerceptual.g, localSkyPerceptual.b));
            float localAuroraSaturation = (localSkyMax - localSkyMin)
                / max(localSkyMax, 0.001);
            float localAuroraPresence = smoothstep(
                0.08,
                0.58,
                localAuroraSaturation);

            // Height above the horizon is a continuous proxy for the moon's
            // journey: warm pearl while rising/setting, lavender through night,
            // and clear blue-white near midnight at the top of its arc.
            float moonAltitude = clamp(moonWorldDir.y, 0.0, 1.0);
            float riseToNight = smoothstep(0.015, 0.42, moonAltitude);
            float nightToMidnight = smoothstep(0.42, 0.88, moonAltitude);
            vec3 moonStageTint = mix(
                vec3(1.06, 0.76, 0.60),
                vec3(0.91, 0.81, 1.00),
                riseToNight);
            moonStageTint = mix(
                moonStageTint,
                vec3(0.70, 0.90, 1.08),
                nightToMidnight);
            moonStageTint = mix(
                moonStageTint,
                localAuroraHue,
                mix(0.07, 0.13, localAuroraPresence));

            float moonAA = max(
                fwidth(dist) * 1.10,
                0.65 / max(viewHeight * fovScale, 1.0));
            if (dist < moonRad + moonAA) {
                float analyticAlpha = 1.0 - smoothstep(
                    moonRad - moonAA,
                    moonRad + moonAA,
                    dist);
                vec2 moonUV = moonPlane / moonRad;
                vec2 moonTexcoord = vec2(
                    0.5 + moonUV.x * 0.435,
                    0.5 - moonUV.y * 0.435);
                vec4 paintedMoon = texture2D(
                    auroraMoonTexture,
                    moonTexcoord);

                // Compress only texture luminance before the global exposure.
                // This retains the high-resolution painted landmasses without
                // allowing their ivory highlights to collapse into flat white.
                float textureLuma = clamp(luma(paintedMoon.rgb), 0.0, 1.0);
                vec3 textureChroma = clamp(
                    paintedMoon.rgb / max(textureLuma, 0.001),
                    vec3(0.32),
                    vec3(2.20));
                float paintedLuma = mix(
                    0.28,
                    0.88,
                    pow(textureLuma, 1.22));
                float softLunarLuma = mix(
                    0.28,
                    0.88,
                    0.52);
                paintedLuma = mix(
                    softLunarLuma,
                    paintedLuma,
                    0.86);
                vec3 moonColor = mix(
                    vec3(paintedLuma),
                    textureChroma * paintedLuma,
                    0.74);
                moonColor *= moonStageTint;

                float moonRadialLight = clamp(
                    1.0 - dist / moonRad,
                    0.0,
                    1.0);
                moonColor *= mix(
                    0.94,
                    1.07,
                    pow(moonRadialLight, 0.65));

                // Apply the live aurora hue across the entire painted disc,
                // not merely its corona. Mixing equal-luminance colors keeps
                // maria/highland detail intact and prevents a flat color disc.
                float moonSurfaceLuma = max(luma(moonColor), 0.001);
                vec3 auroraSurfaceColor = localAuroraHue
                    * moonSurfaceLuma;
                moonColor = mix(
                    moonColor,
                    auroraSurfaceColor,
                    mix(0.16, 0.25, localAuroraPresence));
                moonColor = max(
                    moonColor,
                    vec3(0.11, 0.12, 0.15));
                moonColor = astro_soft_knee_luma(
                    moonColor,
                    0.78,
                    1.08);
                moonColor /= max(
                    pow(moonSceneExposure, 0.60),
                    0.90);

                float alpha = analyticAlpha * paintedMoon.a
                    * weatherVisibility * moonHorizonFade;
                sky_color = mix(sky_color, moonColor, alpha);
            }

            if (dist < moonOuterGlowRad) {
                float coronaGlow = 1.0
                    - smoothstep(moonRad, moonCoronaRad, dist);
                float innerGlow = 1.0
                    - smoothstep(moonRad, moonInnerGlowRad, dist);
                float outerGlow = 1.0
                    - smoothstep(moonRad, moonOuterGlowRad, dist);
                coronaGlow *= coronaGlow;
                innerGlow *= innerGlow;
                outerGlow *= outerGlow;
                float outsideDisc = smoothstep(
                    moonRad * 0.97,
                    moonRad * 1.04,
                    dist);
                coronaGlow *= outsideDisc;
                innerGlow *= outsideDisc;
                outerGlow *= outsideDisc;

                vec3 horizonHalo = vec3(1.00, 0.48, 0.34);
                vec3 nightHalo = vec3(0.58, 0.49, 1.00);
                vec3 midnightHalo = vec3(0.26, 0.68, 1.08);
                vec3 moonHaloColor = mix(
                    horizonHalo,
                    nightHalo,
                    riseToNight);
                moonHaloColor = mix(
                    moonHaloColor,
                    midnightHalo,
                    nightToMidnight);
                moonHaloColor = mix(
                    moonHaloColor,
                    localAuroraHue,
                    mix(0.18, 0.30, localAuroraPresence));
                vec3 coronaColor = mix(
                    vec3(0.88, 0.94, 1.05),
                    moonHaloColor,
                    mix(0.24, 0.34, localAuroraPresence));

                float moonFullness = clamp(
                    abs(4.0 - float(moonPhase)) * 0.25,
                    0.0,
                    1.0);
                float haloPhase = mix(0.72, 1.0, moonFullness);
                float halo = innerGlow * 0.100
                    + outerGlow * 0.030;
                vec3 corona = coronaColor * coronaGlow * 0.24;
                float haloExposureComp = max(
                    pow(moonSceneExposure, 0.56),
                    1.0);
                sky_color += (corona + moonHaloColor * halo)
                    * haloPhase / haloExposureComp
                    * weatherVisibility * moonHorizonFade;
            }
        }
    }

    return sky_color;
}
