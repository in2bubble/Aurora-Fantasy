/* Aurora Fantasy - depth_dh.glsl
Depth utilities.

in2bubble - Based on MakeUp by KDXavier - GNU Lesser General Public License v3.0
*/

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}
