/* Aurora Fantasy - basic_utils.glsl
Misc utilities.

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

float square_pow(float x) {
    return x * x;
}

float fourth_pow(float x) {
    float temp_2 = x * x;
    return temp_2 * temp_2;
}

float sixth_pow(float x) {
    float temp_2 = x * x;
    return temp_2 * temp_2 * temp_2;
}
