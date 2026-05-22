// Screen-Space Reflections - Ported from Reflectify RT (in2bubble)
// Adapted for Aurora Fantasy's pipeline
#ifndef SSR_REFLECTION_GLSL
#define SSR_REFLECTION_GLSL

// SSR configuration (can be overridden by config.glsl)
#ifndef SSR_MAX_STEPS
    #define SSR_MAX_STEPS 16
#endif
#ifndef SSR_STEP_SIZE
    #define SSR_STEP_SIZE 1.2
#endif
#ifndef SSR_BINARY_STEPS
    #define SSR_BINARY_STEPS 6
#endif
#ifndef SSR_BINARY_Z_CUTOFF
    #define SSR_BINARY_Z_CUTOFF 16.0
#endif
#ifndef MIN_REFLECTIVITY
    #define MIN_REFLECTIVITY 0.01
#endif

float getReflectionVignette(vec2 uv) {
    uv.y = min(uv.y, 1.0 - uv.y);
    uv.x *= 1.0 - uv.x;
    uv.y *= uv.y;
    return 1.0 - pow(1.0 - uv.x, 20.0 * uv.y);
}

vec4 getReflectionColor(float depth, vec3 normal, vec3 viewPos, sampler2D sceneColor, sampler2D depthTex) {
    vec3 V = normalize(viewPos);
    vec3 R = normalize(reflect(V, normal));
    if (R.z >= -0.05) return vec4(0.0);

    float fresnel = 1.0 - dot(normal, -V);
    float grazingEpsilon = ssr_rescale(1.0 - abs(dot(R, normal)), 0.95, 1.0);
    float invR = 1.0 / abs(R.z);
    float invFar = 1.0 / (2.0 * far);
    float lengthR = 1.0;
    vec3 oldPos = viewPos;

    for (int i = 0; i < SSR_MAX_STEPS; i++) {
        vec3 curPos = viewPos + R * lengthR;
        vec2 curUV = ssr_view2screen(curPos).st;

        if (curUV.s < 0.0 || curUV.s > 1.0 || curUV.t < 0.0 || curUV.t > 1.0)
            break;

        float sceneDepth = texture2D(depthTex, curUV).x;
        float sceneZ = ssr_screen2view(curUV, sceneDepth).z;
        float distanceEpsilon = clamp(abs(sceneZ) * invFar, 0.0, 1.0);
        float epsilon = 1.0 + 0.1 * max(distanceEpsilon, grazingEpsilon);
        float diffZ = curPos.z - sceneZ * epsilon;

        if (diffZ < 0.0) {
            vec3 a = oldPos;
            vec3 b = curPos;

            if (diffZ > -SSR_BINARY_Z_CUTOFF) {
                for (int j = 0; j < SSR_BINARY_STEPS; j++) {
                    curPos = (a + b) * 0.5;
                    curUV = ssr_view2screen(curPos).st;
                    sceneDepth = texture2D(depthTex, curUV).x;
                    sceneZ = ssr_screen2view(curUV, sceneDepth).z;

                    if (-curPos.z < -sceneZ) { a = curPos; }
                    else                      { b = curPos; }
                }
            }

            return sceneDepth + 0.0001 <= depth
                ? vec4(0.0)
                : vec4(texture2D(sceneColor, curUV).rgb,
                       getReflectionVignette(curUV) * fresnel);
        }

        oldPos = curPos;
        lengthR += max(SSR_STEP_SIZE * abs(diffZ) * invR, 1.0);
    }

    return vec4(0.0);
}

#endif
