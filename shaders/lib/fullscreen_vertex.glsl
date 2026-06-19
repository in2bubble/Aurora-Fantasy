/*
Aurora Fantasy - fullscreen pass compatibility

Post-processing passes must cover the complete render target.  Deriving their
clip-space position from the pass UV avoids depending on Minecraft/Iris legacy
fixed-function matrices, whose state can change between renderer versions.
*/

vec4 fullscreen_position(vec2 uv) {
    return vec4(uv * 2.0 - 1.0, 0.0, 1.0);
}
