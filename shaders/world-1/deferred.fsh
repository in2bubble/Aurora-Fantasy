#version 120
/* Aurora Fantasy - deferred.fsh
Render: Ambient occlusion, volumetric clouds

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

#define NETHER
#define DEFERRED_SHADER
#define NO_SHADOWS
#define NO_CLOUDY_SKY

#include "/common/deferred_fragment.glsl"
