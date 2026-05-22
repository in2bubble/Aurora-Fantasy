/* Aurora Fantasy - color_utils.glsl
Usefull data for color manipulation.

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

uniform vec3 skyColor;
uniform float day_moment;
uniform float day_mixer;
uniform float night_mixer;

#define MID_SUNSET_COLOR HORIZON_SUNSET_COLOR
#define MID_DAY_COLOR HORIZON_DAY_COLOR
#define MID_NIGHT_COLOR HORIZON_NIGHT_COLOR

#define OMNI_TINT 0.8
#define LIGHT_SUNSET_COLOR vec3(0.25, 0.18, 0.28)
#define LIGHT_DAY_COLOR LIGHT_SUNSET_COLOR
#define LIGHT_NIGHT_COLOR LIGHT_SUNSET_COLOR

// Brighter End sky - Dark purple/violet tones
#define ZENITH_SUNSET_COLOR vec3(0.08, 0.06, 0.12)
#define ZENITH_DAY_COLOR vec3(0.08, 0.06, 0.12)
#define ZENITH_NIGHT_COLOR ZENITH_SUNSET_COLOR

#define HORIZON_SUNSET_COLOR vec3(0.06, 0.04, 0.08)
#define HORIZON_DAY_COLOR HORIZON_SUNSET_COLOR
#define HORIZON_NIGHT_COLOR HORIZON_SUNSET_COLOR

#define WATER_COLOR vec3(0.01647059, 0.13882353, 0.16470588)

#include "/lib/day_blend.glsl"

// Fog parameter per hour
#define FOG_DAY 1.0
#define FOG_SUNSET 1.0
#define FOG_NIGHT 1.0
#define FOG_DENSITY 3.0

#include "/lib/color_conversion.glsl"