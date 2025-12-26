#version 120
/* MakeUp - gbuffers_damagedblock.vsh
Render: Damaged block effect

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define NO_SHADOWS
#define GBUFFER_DAMAGE

// BEGIN INLINE /common/damage_vertex.glsl
#include "/lib/config.glsl"

/* Uniforms */

uniform mat4 gbufferProjectionInverse;

/* Ins / Outs */

varying vec2 texcoord;
varying float var_fog_frag_coord;

/* Utility functions */

#if AA_TYPE > 0
// BEGIN INLINE /src/taa_offset.glsl
#if MC_VERSION >= 11300
    uniform vec2 taa_offset;
#else
    uniform int frame_mod;
    uniform float pixel_size_x;
    uniform float pixel_size_y;

    vec2[10] offset_array = vec2[10] (
        vec2(0.7071067811865476, 0.0),
        vec2(-0.5720614028176843, 0.4156269377774535),
        vec2(0.2185080122244104, -0.6724985119639574),
        vec2(0.21850801222441057, 0.6724985119639574),
        vec2(-0.5720614028176845, -0.4156269377774534),
        vec2(0.7071067811865476, 0.0),
        vec2(-0.5720614028176843, 0.4156269377774535),
        vec2(0.2185080122244104, -0.6724985119639574),
        vec2(0.21850801222441057, 0.6724985119639574),
        vec2(-0.5720614028176845, -0.4156269377774534)
    );

    vec2 taa_offset = offset_array[frame_mod] * vec2(pixel_size_x, pixel_size_y);
#endif
// END INLINE /src/taa_offset.glsl
#endif

// MAIN FUNCTION ------------------

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    vec4 homopos = gbufferProjectionInverse * vec4(gl_Position.xyz / gl_Position.w, 1.0);
    vec3 viewPos = homopos.xyz / homopos.w;
    gl_FogFragCoord = length(viewPos.xyz);
}
// END INLINE /common/damage_vertex.glsl
