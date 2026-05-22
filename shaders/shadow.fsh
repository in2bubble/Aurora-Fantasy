#version 120
/* Aurora Fantasy - shadow.fsh
Render: Shadowmap

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif
#define SHADOW_SHADER

#include "/common/shadow_fragment.glsl"
