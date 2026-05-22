/* Aurora Fantasy - sky_astro.glsl
Draws the screen-space sun and moon. Include before volumetric clouds so clouds
can occlude the discs and halos naturally.
*/

vec2 astro_hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float astro_voronoi(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);
    float m = 8.0;
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        vec2 g = vec2(float(i), float(j));
        vec2 o = astro_hash22(n + g);
        vec2 r = g - f + o;
        float d = dot(r, r);
        if (d < m) m = d;
    }
    return m;
}

float astro_hash12_low(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float astro_noise_low(in vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float res = mix(
        mix(astro_hash12_low(p), astro_hash12_low(p + vec2(1.0, 0.0)), f.x),
        mix(astro_hash12_low(p + vec2(0.0, 1.0)), astro_hash12_low(p + vec2(1.0, 1.0)), f.x),
        f.y
    );
    return res;
}

float astro_fbm_low(vec2 p) {
    float f = 0.0;
    float w = 0.5;
    for (int i = 0; i < 4; i++) {
        f += w * astro_noise_low(p);
        p *= 2.0;
        w *= 0.5;
    }
    return f;
}

vec3 draw_sky_astro(vec3 sky_color, vec2 uv, bool is_sky_pixel) {
    if (!is_sky_pixel) return sky_color;

    vec4 sunClipPos = gbufferProjection * vec4(sunPosition, 1.0);
    vec2 sunScreen = (sunClipPos.xy / sunClipPos.w) * 0.5 + 0.5;

    vec4 moonClipPos = gbufferProjection * vec4(-sunPosition, 1.0);
    vec2 moonScreen = (moonClipPos.xy / moonClipPos.w) * 0.5 + 0.5;

    float aspectRatio = viewWidth / viewHeight;
    float fovScale = gbufferProjection[1][1] * 0.5;

    float sunRad = 0.03923 * fovScale;
    float sunGlowRad = 0.16806 * fovScale;
    float moonRad = 0.03923 * fovScale;
    float moonGlowRad = 0.21007 * fovScale;

    vec3 sunWorldDir = normalize((gbufferModelViewInverse * vec4(normalize(sunPosition), 0.0)).xyz);
    float sunHorizonFade = smoothstep(-0.05, 0.05, sunWorldDir.y);
    float moonHorizonFade = smoothstep(-0.05, 0.05, -sunWorldDir.y);
    float weatherVisibility = 1.0 - rainStrength;

    if (sunClipPos.w > 0.0 && sunHorizonFade > 0.001) {
        vec2 distVec = uv - sunScreen;
        distVec.x *= aspectRatio;
        float dist = length(distVec);

        if (dist < sunRad) {
            float edge = fwidth(dist) * 2.0;
            float alpha = smoothstep(sunRad, sunRad - edge, dist);

            vec2 sunUV = (distVec / sunRad) * 14.0;
            float granulation = astro_voronoi(sunUV * 2.0);
            granulation = smoothstep(0.1, 0.6, granulation);

            float turbulence = astro_fbm_low(sunUV * 1.5);
            float grad = 1.0 - (dist / sunRad);

            vec3 sunCore = vec3(1.0, 1.0, 0.9);
            vec3 sunEdge = vec3(1.0, 0.5, 0.1);
            vec3 sunColor = mix(sunEdge, sunCore, pow(grad, 0.4));
            sunColor *= 0.7 + 0.3 * granulation;
            sunColor *= 0.85 + 0.15 * turbulence;
            sunColor *= 1.2;
            sunColor = clamp(sunColor, vec3(0.0), vec3(10.0));

            alpha *= weatherVisibility * sunHorizonFade;
            sky_color = mix(sky_color, sunColor, alpha);
        }

        if (dist < sunGlowRad) {
            float glow = smoothstep(sunGlowRad, sunRad, dist);
            sky_color += vec3(1.0, 0.8, 0.4) * glow * 0.3 * weatherVisibility * sunHorizonFade;
        }
    }

    if (moonClipPos.w > 0.0 && moonHorizonFade > 0.001) {
        vec2 distVec = uv - moonScreen;
        distVec.x *= aspectRatio;
        float dist = length(distVec);

        if (dist < moonRad + 0.005 * fovScale / 0.71405) {
            float edge = fwidth(dist) * 2.0;
            float alpha = smoothstep(moonRad, moonRad - edge, dist);

            vec2 moonUV = (distVec / moonRad) * 11.2;
            float v = astro_voronoi(moonUV * 1.5);
            float mareNoise = astro_fbm_low(moonUV * 0.3 + vec2(8.0));
            float mare = smoothstep(0.4, 0.7, mareNoise);

            vec3 colBright = vec3(0.9, 0.95, 1.0);
            vec3 colDark = vec3(0.4, 0.45, 0.5);
            vec3 colCrater = vec3(0.6, 0.65, 0.7);

            vec3 moonColor = mix(colBright, colDark, mare);
            float craterMask = 1.0 - smoothstep(0.0, 0.2, v);
            moonColor = mix(moonColor, colCrater, craterMask * 0.7);

            float sphereGrad = sqrt(1.0 - clamp(dist / moonRad, 0.0, 1.0));
            moonColor *= 0.5 + 0.5 * sphereGrad;
            moonColor *= 0.5;

            alpha *= weatherVisibility * moonHorizonFade;
            sky_color = mix(sky_color, moonColor, alpha);
        }

        if (dist < moonGlowRad) {
            float glow = smoothstep(moonGlowRad, moonRad, dist);
            sky_color += vec3(0.1, 0.3, 1.0) * glow * 0.4 * weatherVisibility * moonHorizonFade;
        }
    }

    return sky_color;
}
