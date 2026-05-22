#version 120
/* Aurora Fantasy - gbuffers_clouds.fsh
Render: sky, clouds

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#define GBUFFER_CLOUDS
#define NO_SHADOWS
#define SPECIAL_TRANS

#include "/common/clouds_blocks_fragment.glsl"