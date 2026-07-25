#version 120
#extension GL_ARB_shader_texture_lod : enable
/* Aurora Fantasy - prepare.vsh
Render: Sky and procedural fog lookup

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#define USE_BASIC_SH

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif

#define PREPARE_SHADER
#define NO_SHADOWS

#include "/common/prepare_vertex.glsl"
