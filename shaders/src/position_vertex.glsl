    // Keep OptiFine's legacy combined transform. It is also accepted by
    // current renderers, and avoids corrupt terrain coordinates on OptiFine
    // releases used by Minecraft 1.19 and older.
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

#ifdef FOLIAGE_V

    is_foliage = 0.0;

    bool isLeavesEntity = (
        mc_Entity.x == ENTITY_LEAVES ||
        mc_Entity.x == ENTITY_WHITE_LEAVES ||
        mc_Entity.x == ENTITY_FLOWERING_LEAVES ||
        mc_Entity.x == ENTITY_POPLAR_LEAVES
    );
    bool isGrassEntity = (
        mc_Entity.x == ENTITY_LOWERGRASS ||
        mc_Entity.x == ENTITY_UPPERGRASS ||
        mc_Entity.x == ENTITY_SMALLGRASS ||
        mc_Entity.x == ENTITY_SMALLENTS ||
        mc_Entity.x == ENTITY_FANTASY_FLOWERS ||
        mc_Entity.x == ENTITY_NEW_TREE_SAPLINGS
    );
    bool isFoliageEntity = isLeavesEntity || isGrassEntity ||
        mc_Entity.x == ENTITY_SMALLENTS_NW;

    vec4 sub_position = gl_ModelViewMatrix * gl_Vertex;
    vec4 position = gbufferModelViewInverse * sub_position;

    if (isFoliageEntity) {
        is_foliage = 0.4;

        #if WAVING == 1
            bool shouldWave = false;
            #if WAVING_LEAVES == 1
                shouldWave = isLeavesEntity;
            #endif
            #if WAVING_GRASS == 1
                shouldWave = shouldWave || isGrassEntity;
            #endif

            if (shouldWave && mc_Entity.x != ENTITY_SMALLENTS_NW) {
                vec3 worldpos = position.xyz + cameraPosition;
                float weight = float(gl_MultiTexCoord0.t < mc_midTexCoord.t);

                if (mc_Entity.x == ENTITY_UPPERGRASS) {
                    weight += 1.0;
                } else if (isLeavesEntity) {
                    weight = 0.6;
                } else if (mc_Entity.x == ENTITY_SMALLENTS &&
                           (weight > 0.9 || fract(worldpos.y + 0.0675) > 0.01)) {
                    weight = 1.0;
                }

                weight *= lmcoord.y * lmcoord.y;
                vec3 wave_offset_world = wave_move(worldpos.xzy) * weight *
                                         (0.03 + rainStrength * 0.01);
                // A direction uses w = 0, so translation is intentionally ignored.
                gl_Position += gl_ModelViewProjectionMatrix *
                               vec4(wave_offset_world, 0.0);
            }
        #endif
    }

#else

    vec4 sub_position = gl_ModelViewMatrix * gl_Vertex;
    #ifndef NO_SHADOWS
        #ifdef SHADOW_CASTING
            vec4 position = gbufferModelViewInverse * sub_position;
        #endif
    #endif

#endif

#if AA_TYPE > 1
    gl_Position.xy += taa_offset * gl_Position.w;
#endif

#ifndef SHADER_BASIC
    vec4 homopos = gbufferProjectionInverse * vec4(gl_Position.xyz / gl_Position.w, 1.0);
    vec3 viewPos = homopos.xyz / homopos.w;

    #if defined GBUFFER_CLOUDS
        gl_FogFragCoord = length(viewPos.xz);
    #else
        gl_FogFragCoord = length(viewPos.xyz);
    #endif
#endif
