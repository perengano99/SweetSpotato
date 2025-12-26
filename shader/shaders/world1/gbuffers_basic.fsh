#version 120
/* MakeUp - gbuffers_basic.fsh
Render: Basic elements - lines

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define THE_END
#define GBUFFER_BASIC
#define NO_SHADOWS

// BEGIN INLINE /common/basic_blocks_fragment.glsl
#include "/lib/config.glsl"

/* Uniforms, ins, outs */
varying vec4 tint_color;
varying vec2 texcoord;
varying vec3 basic_light;

// MAIN FUNCTION ------------------

void main() {
    vec4 block_color = tint_color;
    block_color.rgb *= basic_light;

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
// END INLINE /common/basic_blocks_fragment.glsl
