#version 120
/* MakeUp - gbuffers_line.vsh
Render: Render lines

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define GBUFFER_LINE
#define NO_SHADOWS
#define SHADER_BASIC
#define SHADER_LINE

// BEGIN INLINE /common/line_blocks_vertex.glsl
#include "/lib/config.glsl"

/* Uniforms */

uniform float viewHeight;
uniform float viewWidth;

/* Ins / Outs */

varying vec4 tint_color;

/* Utility functions */

#if AA_TYPE > 1
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

// BEGIN INLINE /lib/mu_ftransform.glsl
vec4 mu_ftransform() {
    float lineWidth = 2.0;
    vec2 screenSize = vec2(viewWidth, viewHeight);
    mat4 VIEW_SCALE = mat4(mat3(1.0 - 0.00390625));
    mat4 tempmat = gl_ProjectionMatrix * VIEW_SCALE * gl_ModelViewMatrix;
    vec4 linePosStart = tempmat * gl_Vertex;
    vec4 linePosEnd = tempmat * vec4(gl_Vertex.xyz + gl_Normal, 1.0);
    vec3 ndc1 = linePosStart.xyz / linePosStart.w;
    vec3 ndc2 = linePosEnd.xyz / linePosEnd.w;
    vec2 lineScreenDirection = normalize((ndc2.xy - ndc1.xy) * screenSize);
    vec2 lineOffset = vec2(-lineScreenDirection.y, lineScreenDirection.x) * lineWidth / screenSize;
    if(lineOffset.x < 0.0)
        lineOffset *= -1.0;
    if(gl_VertexID % 2 == 0)
        return vec4((ndc1 + vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
    else
        return vec4((ndc1 - vec3(lineOffset, 0.0)) * linePosStart.w, linePosStart.w);
}
// END INLINE /lib/mu_ftransform.glsl

// MAIN FUNCTION ------------------

void main() {
    tint_color = gl_Color;
    gl_Position = mu_ftransform();

    #if AA_TYPE > 1
        gl_Position.xy += taa_offset * gl_Position.w;
    #endif
}
// END INLINE /common/line_blocks_vertex.glsl
