/*
Aurora Fantasy - render-target pixel size

Compute this from the built-in per-program framebuffer dimensions.  A global
custom uniform can be evaluated while Iris is rendering the shadow map, which
would freeze the value at 1 / shadowMapResolution (commonly 1 / 1024) and make
screen-space effects cover only the lower-left 1024x1024 region.
*/

#ifndef AURORA_SCREEN_SIZE_GLSL
#define AURORA_SCREEN_SIZE_GLSL
    #define pixel_size_x (1.0 / max(viewWidth, 1.0))
    #define pixel_size_y (1.0 / max(viewHeight, 1.0))
#endif
