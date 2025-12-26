#version 120
/* MakeUp - composite1.fsh
Render: Bloom and DoF

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define USE_BASIC_SH // Sets the use of a "basic" or "generic" shader for custom dimensions, instead of the default overworld shader. This can solve some rendering issues as the shader is closer to vanilla rendering.

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif
#define COMPOSITE1_SHADER

// BEGIN INLINE /common/composite1_vertex.glsl
#include "/lib/config.glsl"

/* Ins / Outs */

varying vec2 texcoord;

// MAIN FUNCTION ------------------

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = gl_MultiTexCoord0.xy;
}
// END INLINE /common/composite1_vertex.glsl
