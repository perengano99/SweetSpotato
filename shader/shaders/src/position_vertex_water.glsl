// --- ARCHIVO: shaders/src/position_vertex_water.glsl ---
// (Sin uniform float frameTimeCounter; al inicio)

vec4 position2 = gl_ModelViewMatrix * gl_Vertex;
vec4 position = gbufferModelViewInverse * position2;
worldposition = position + vec4(cameraPosition.xyz, 0.0);

// --- MAREA Y OLEAJE FÍSICO ---
#if WATER_DISPLACEMENT == 1
    if (mc_Entity.x == ENTITY_WATER) {
        // Onda 1: Marea lenta y amplia
        float tide = sin(frameTimeCounter * 0.8 + worldposition.x * 0.2 + worldposition.z * 0.2);
        
        // Onda 2: Oleaje más rápido
        float chop = cos(frameTimeCounter * 1.8 + worldposition.x * 0.9 - worldposition.z * 0.7);
        
        float final_wave = (tide * 0.7 + chop * 0.3);
        float displacement = final_wave * 0.06; 
        
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