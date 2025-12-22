// --- CONSTANTES DE BIOMA (IRIS/OPTIFINE STANDARD) ---

// Uniforms (ya declarados en el padre, pero necesarios para contexto mental)
// uniform int biome_category;
// uniform float frameTimeCounter;

vec4 position2 = gl_ModelViewMatrix * gl_Vertex;
vec4 position = gbufferModelViewInverse * position2;
worldposition = position + vec4(cameraPosition.xyz, 0.0);

// --- MAREA Y OLEAJE FÍSICO DINÁMICO ---
#if WATER_DISPLACEMENT == 1
    if (mc_Entity.x == ENTITY_WATER) {
        float wave_amplitude = 0.06; // Base
        float wave_speed = 1.0;
        float wave_freq = 1.0;

        // Onda 1: Marea principal
        float tide = sin(frameTimeCounter * 0.8 * wave_speed + worldposition.x * 0.2 * wave_freq + worldposition.z * 0.2 * wave_freq);
        
        // Onda 2: Oleaje secundario (detalle)
        float chop = cos(frameTimeCounter * 1.8 * wave_speed + worldposition.x * 0.9 * wave_freq - worldposition.z * 0.7 * wave_freq);
        
        float final_wave = (tide * 0.7 + chop * 0.3);
        
        // Aplicamos el desplazamiento
        float displacement = final_wave * wave_amplitude; 
        
        vec4 displaceVec = gl_ModelViewMatrix * vec4(0.0, displacement, 0.0, 0.0);
        position2 += displaceVec;
    }
#endif
// -------------------------------------------------------

fragposition = position2.xyz;
gl_Position = gl_ProjectionMatrix * position2;
gl_FogFragCoord = length(position2.xyz);

#if AA_TYPE > 1
    gl_Position.xy += taa_offset * gl_Position.w;
#endif