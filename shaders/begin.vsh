#version 120
/* Aurora Fantasy - begin.vsh
Render: Sky before the shadow pass (Iris 1.11 / Minecraft 26.2 compatibility)

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#define USE_BASIC_SH

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif

#define PREPARE_SHADER
#define NO_SHADOWS

#include "/common/prepare_vertex.glsl"
