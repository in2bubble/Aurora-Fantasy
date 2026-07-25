#ifdef WATER_F
    block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
    /* DRAWBUFFERS:1 */
    gl_FragData[0] = block_color;
#elif (defined SPECIAL_TRANS && MC_VERSION >= 11300) || defined GBUFFER_HAND_WATER
    /* DRAWBUFFERS:1 */
    gl_FragData[0] = block_color;
#else
    #if defined SET_FOG_COLOR
        // Minecraft 26.2 / Iris 1.11 executes prepare as a real fullscreen pass.
        // The visible sky is subsequently rendered at full resolution by
        // gbuffers_skybasic, so writing colortex1 here only duplicates that
        // work.  Keep just the procedural fog lookup (gaux4 / colortex7).
        /* DRAWBUFFERS:7 */
        block_color = clamp(block_color, vec3(0.0), vec3(50.0));
        gl_FragData[0] = vec4(block_color, 1.0);
    #elif defined DISTANT_RENDER_MOD && defined GBUFFER_SKYBASIC && MC_VERSION >= 11604
        // DH terrain samples gaux4 as fog color, so keep procedural stars out of that buffer.
        /* DRAWBUFFERS:1 */
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        gl_FragData[0] = block_color;
    #elif MC_VERSION < 11604 && defined GBUFFER_SKYBASIC
        /* DRAWBUFFERS:17 */
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        gl_FragData[0] = block_color;
        gl_FragData[1] = block_color;
    #elif defined RAIN_PUDDLES && !defined NETHER && !defined THE_END && (defined GBUFFER_TERRAIN || defined GBUFFER_TEXTURED)
        /* DRAWBUFFERS:189 */
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        gl_FragData[0] = block_color;
        gl_FragData[1] = vec4(puddle_normal_out, 1.0);
        gl_FragData[2] = vec4(
            puddle_mask_out,
            puddle_wetness_out,
            0.5 + 0.49 * clamp(fantasy_habitat_out, 0.0, 1.0),
            puddle_depth_out);
    #elif defined RAIN_PUDDLES && !defined NETHER && !defined THE_END && (defined GBUFFER_HAND || defined GBUFFER_ENTITIES)
        // Clear SSR buffers for hand/entities so puddle reflections don't bleed through
        /* DRAWBUFFERS:189 */
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        gl_FragData[0] = block_color;
        gl_FragData[1] = vec4(0.0);
        gl_FragData[2] = vec4(0.0);
    #else
        /* DRAWBUFFERS:1 */
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        gl_FragData[0] = block_color;
    #endif
#endif
