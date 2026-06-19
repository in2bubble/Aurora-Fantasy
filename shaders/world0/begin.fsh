#version 120
/* Aurora Fantasy - begin.fsh
Render: Sky before the shadow pass (Iris 1.11 / Minecraft 26.2 compatibility)

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#define PREPARE_SHADER
#define NO_SHADOWS
#define SET_FOG_COLOR

#include "/common/prepare_fragment.glsl"
