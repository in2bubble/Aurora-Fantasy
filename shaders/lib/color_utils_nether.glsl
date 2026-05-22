/* Aurora Fantasy - color_utils.glsl
Usefull data for color manipulation.

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

uniform float day_moment;
uniform float day_mixer;
uniform float night_mixer;
uniform vec3 skyColor;
uniform vec3 fogColor;

#define MID_SUNSET_COLOR HORIZON_SUNSET_COLOR
#define MID_DAY_COLOR HORIZON_DAY_COLOR
#define MID_NIGHT_COLOR HORIZON_NIGHT_COLOR

#define OMNI_TINT 0.6
// Warmer, more vibrant Nether lighting
#define LIGHT_SUNSET_COLOR vec3(0.12, 0.08, 0.06)
#define LIGHT_DAY_COLOR vec3(0.12, 0.08, 0.06)
#define LIGHT_NIGHT_COLOR vec3(0.12, 0.08, 0.06)

// Brighter reddish-brown sky colors
#define ZENITH_SUNSET_COLOR vec3(0.08, 0.06, 0.055)
#define ZENITH_DAY_COLOR vec3(0.08, 0.06, 0.055)
#define ZENITH_NIGHT_COLOR vec3(0.08, 0.06, 0.055)

#define HORIZON_SUNSET_COLOR vec3(0.09, 0.065, 0.06)
#define HORIZON_DAY_COLOR vec3(0.09, 0.065, 0.06)
#define HORIZON_NIGHT_COLOR vec3(0.09, 0.065, 0.06)

#define WATER_COLOR vec3(0.01647059, 0.13882353, 0.16470588)

#include "/lib/day_blend.glsl"

// Fog parameter per hour
#define FOG_DAY 1.0
#define FOG_SUNSET 1.0
#define FOG_NIGHT 1.0

#include "/lib/color_conversion.glsl"
