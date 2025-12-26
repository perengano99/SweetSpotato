#version 120
/* MakeUp - gbuffers_armor_glint.fsh
Render: Glow objects

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define GBUFFER_ARMOR_GLINT
#define SHADER_BASIC

// BEGIN INLINE /common/glint_blocks_fragment.glsl
#include "/lib/config.glsl"

/* Uniforms */

uniform sampler2D tex;

/* Ins / Outs */

varying vec2 texcoord;
varying vec4 tint_color;
varying float exposure;

// MAIN FUNCTION ------------------

void main() {
    // Toma el color puro del bloque
    vec4 block_color = texture2D(tex, texcoord) * tint_color / max(0.001, exposure);

// BEGIN INLINE /src/writebuffers.glsl
#ifdef WATER_F
    block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
    /* DRAWBUFFERS:1 */
    gl_FragData[0] = block_color;
#elif (defined SPECIAL_TRANS && MC_VERSION >= 11300) || defined GBUFFER_HAND_WATER
    /* DRAWBUFFERS:1 */
    gl_FragData[0] = block_color;
#else
    #if defined SET_FOG_COLOR
        /* DRAWBUFFERS:17 */
        block_color = clamp(block_color, vec3(0.0), vec3(50.0));
        gl_FragData[0] = vec4(block_color, 1.0);
        gl_FragData[1] = vec4(block_color, 1.0);
    #elif MC_VERSION < 11604 && defined GBUFFER_SKYBASIC
        /* DRAWBUFFERS:17 */
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        gl_FragData[0] = block_color;
        gl_FragData[1] = block_color;
    #else
        /* DRAWBUFFERS:1 */
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        gl_FragData[0] = block_color;
    #endif
#endif
// END INLINE /src/writebuffers.glsl
}
// END INLINE /common/glint_blocks_fragment.glsl
