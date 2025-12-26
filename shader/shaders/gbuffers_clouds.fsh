#version 120
/* MakeUp - gbuffers_clouds.fsh
Render: sky, clouds

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define USE_BASIC_SH // Sets the use of a "basic" or "generic" shader for custom dimensions, instead of the default overworld shader. This can solve some rendering issues as the shader is closer to vanilla rendering.

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif
#define GBUFFER_CLOUDS
#define NO_SHADOWS
#define SPECIAL_TRANS

// BEGIN INLINE /common/clouds_blocks_fragment.glsl
#include "/lib/config.glsl"

/* Uniforms */

uniform sampler2D tex;
uniform float far;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
    uniform float darknessLightFactor;
#endif

#if V_CLOUDS == 0 || defined UNKNOWN_DIM
    uniform float pixel_size_x;
    uniform float pixel_size_y;
    uniform sampler2D gaux4;
#endif

/* Ins / Outs */

#if V_CLOUDS == 0 || defined UNKNOWN_DIM
    varying vec2 texcoord;
    varying vec4 tint_color;
#endif

// Main function ---------

void main() {
    #if V_CLOUDS == 0 || defined UNKNOWN_DIM
        vec4 block_color = texture2D(tex, texcoord) * tint_color;
// BEGIN INLINE /src/cloudfinalcolor.glsl

#if MC_VERSION < 12106
    block_color.rgb =
        mix(
            block_color.rgb,
            texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb,
            clamp(pow(gl_FogFragCoord / (far * 1.66), 1.5), 0.0, 1.0)
        );
#else
    block_color.rgb =
        mix(
            block_color.rgb,
            texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb,
            clamp(pow(gl_FogFragCoord / (2000.0), 1.5), 0.0, 1.0)
        );
#endif
// END INLINE /src/cloudfinalcolor.glsl
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
    #elif MC_VERSION <= 11300
        vec4 block_color = vec4(0.0);
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
    #endif
}
// END INLINE /common/clouds_blocks_fragment.glsl
