#version 120
/* MakeUp - composite1.fsh
Render: Antialiasing and motion blur

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define NETHER
#define COMPOSITE2_SHADER
#define NO_SHADOWS

// BEGIN INLINE /common/composite2_vertex.glsl
#include "/lib/config.glsl"

/* Ins / Outs */

varying vec2 texcoord;

// MAIN FUNCTION ------------------

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = gl_MultiTexCoord0.xy;
}
// END INLINE /common/composite2_vertex.glsl
