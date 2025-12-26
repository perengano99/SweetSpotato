#version 120
/* MakeUp - gbuffers_spidereyes.vsh
Render: Some creatures eyes (like spider)

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define USE_BASIC_SH // Sets the use of a "basic" or "generic" shader for custom dimensions, instead of the default overworld shader. This can solve some rendering issues as the shader is closer to vanilla rendering.

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif
#define GBUFFER_SPIDEREYES
#define NO_SHADOWS

// BEGIN INLINE /common/spidereyes_blocks_vertex.glsl
#include "/lib/config.glsl"

/* Uniforms */

uniform mat4 gbufferProjectionInverse;

#if defined SHADOW_CASTING && !defined NETHER
    uniform mat4 gbufferModelViewInverse;
#endif

/* Ins / Outs */

varying vec2 texcoord;

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

// BEGIN INLINE /src/position_vertex.glsl
gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

#ifdef FOLIAGE_V  // Lógica optimizada para follaje y bloques generales
    
    is_foliage = 0.0;

    // Comprobamos si la entidad actual es un tipo de follaje.
    bool isFoliageEntity = (
        mc_Entity.x == ENTITY_LOWERGRASS ||
        mc_Entity.x == ENTITY_UPPERGRASS ||
        mc_Entity.x == ENTITY_SMALLGRASS ||
        mc_Entity.x == ENTITY_SMALLENTS ||
        mc_Entity.x == ENTITY_LEAVES ||
        mc_Entity.x == ENTITY_SMALLENTS_NW
    );

    vec4 sub_position = gl_ModelViewMatrix * gl_Vertex;
    vec4 position = gbufferModelViewInverse * sub_position;
    
    if (isFoliageEntity) {
        is_foliage = 0.4;

        #if WAVING == 1
            if (mc_Entity.x != ENTITY_SMALLENTS_NW) {
                vec3 worldpos = position.xyz + cameraPosition;

                // Lógica original para calcular el peso del movimiento
                float weight = float(gl_MultiTexCoord0.t < mc_midTexCoord.t);

                if (mc_Entity.x == ENTITY_UPPERGRASS) {
                    weight += 1.0;
                } else if (mc_Entity.x == ENTITY_LEAVES) {
                    weight = .3;
                } else if (mc_Entity.x == ENTITY_SMALLENTS && (weight > 0.9 || fract(worldpos.y + 0.0675) > 0.01)) {
                    weight = 1.0;
                }

                weight *= lmcoord.y * lmcoord.y;
                
                // Calculamos el DESPLAZAMIENTO y lo añadimos a la posición base ya calculada.
                vec3 wave_offset_world = wave_move(worldpos.xzy) * weight * (0.03 + (rainStrength * .05));
                vec4 wave_offset_clip = gl_ModelViewProjectionMatrix * vec4(wave_offset_world, 0.0);
                
                gl_Position += wave_offset_clip;
            }
        #endif
    }

#else // Lógica para cuando no es un shader con follaje (p. ej. entidades)

    vec4 sub_position = gl_ModelViewMatrix * gl_Vertex;
    #ifndef NO_SHADOWS
        #ifdef SHADOW_CASTING
            vec4 position = gbufferModelViewInverse * sub_position;
        #endif
    #endif
    
#endif

#ifdef EMMISIVE_V
    float is_fake_emmisor = float(mc_Entity.x == ENTITY_F_EMMISIVE);
#endif

#if AA_TYPE > 1
    gl_Position.xy += taa_offset * gl_Position.w;
#endif

#ifndef SHADER_BASIC
    vec4 homopos = gbufferProjectionInverse * vec4(gl_Position.xyz / gl_Position.w, 1.0);
    vec3 viewPos = homopos.xyz / homopos.w;

    #if defined GBUFFER_CLOUDS
        gl_FogFragCoord = length(viewPos.xz);
    #else
        gl_FogFragCoord = length(viewPos.xyz);
    #endif
#endif
// END INLINE /src/position_vertex.glsl
}
// END INLINE /common/spidereyes_blocks_vertex.glsl
