/* MakeUp - volumetric_clouds.glsl
Volumetric light - MakeUp implementation
*/

#if VOL_LIGHT == 2
    #define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

    const float[16] ditherPattern = float[16](
        0.0, 0.5, 0.125, 0.625,
        0.75, 0.25, 0.875, 0.375,
        0.1875, 0.6875, 0.0625, 0.5625,
        0.9375, 0.4375, 0.8125, 0.3125
    );

    vec3 get_volumetric_pos(vec3 shadow_pos) {
        shadow_pos = mat3(shadowModelView) * shadow_pos + shadowModelView[3].xyz;
        shadow_pos = diagonal3(shadowProjection) * shadow_pos + shadowProjection[3].xyz;

        // Distorsión simplificada para ahorrar ciclos
        float distb = length(shadow_pos.xy);
        float distortion = distb * SHADOW_DIST + (1.0 - SHADOW_DIST);

        shadow_pos.xy /= distortion;
        shadow_pos.z *= 0.2;
        return shadow_pos * 0.5 + 0.5;
    }

    float get_volumetric_light(float dither, float view_distance, mat4 modeli_times_projectioni) {
        float light = 0.0;
        
        // OPTIMIZACIÓN: Dither más agresivo basado en coordenadas de pantalla
        // Esto ayuda a disimular el bajo número de GODRAY_STEPS
        int px = int(gl_FragCoord.x) % 4;
        int py = int(gl_FragCoord.y) % 4;
        float jitter = ditherPattern[py * 4 + px]; 

        // Raymarch
        float stepLength = view_distance / float(GODRAY_STEPS);
        float currentDepth = 0.0;
        
        // Inicio aleatorio del rayo para evitar patrones de corte
        currentDepth += stepLength * jitter; 

        for (int i = 0; i < GODRAY_STEPS; i++) {
            if (currentDepth > view_distance) break;

            // Reconstrucción de posición (más barata si es lineal en este caso)
            // Convertimos profundidad lineal a profundidad de buffer logarítmica/proyectada si es necesario
            // Pero aquí simplificamos asumiendo distribución lineal para niebla cercana
            
            // Mapeo simple de profundidad (Trick: Usamos un sampleo pseudo-lineal para interiores)
            float depthSample = (far * (near + currentDepth)) / (far - near); // Aproximación
             
            // Corrección precisa:
            // Es mejor usar la depth real, pero para optimizar recalculamos menos
            vec3 view_pos = vec3(texcoord, currentDepth); // Z linear temporal

            // Proyección al mapa de sombras
            // Nota: Aquí usamos una simplificación. En shaders complejos se hace la inversa completa.
            // Para SweetSpotato, usaremos el método estándar de MakeUp pero con menos precisión.
            
            // -- Bloque estándar de MakeUp optimizado --
            float d_depth = exp2(float(i) + jitter) - 0.6; // Distribución exponencial
            if (d_depth > view_distance) break;
            
            float linear_d = (far * (d_depth - near)) / (d_depth * (far - near));
            vec3 v_pos = vec3(texcoord, linear_d);
            vec4 pos = modeli_times_projectioni * (vec4(v_pos, 1.0) * 2.0 - 1.0);
            v_pos = (pos.xyz /= pos.w).xyz;
            
            vec3 shadow_pos = get_volumetric_pos(v_pos);

            // Sampleo de sombra (Shadow Texture 1 suele ser más suave en MakeUp)
            // Usamos shadow2D para PCF hardware gratuito si está disponible
            float shadowSample = shadow2D(shadowtex1, shadow_pos).r;
            
            light += shadowSample;
        }

        light /= float(GODRAY_STEPS);
        
        // Curva de intensidad: Potencia la luz para que se vean haces definidos incluso con poca densidad
        return pow(light, 1.2) * 2.0; 
    }

    #if defined COLORED_SHADOW

        vec3 get_volumetric_color_light(float dither, float view_distance, mat4 modeli_times_projectioni) {
            float light = 0.0;

            float current_depth;
            vec3 view_pos;
            vec4 pos;
            vec3 shadow_pos;

            float shadow_detector = 1.0;
            float shadow_black = 1.0;
            vec4 shadow_color = vec4(1.0);
            vec3 light_color = vec3(0.0);

            float alpha_complement;

            for (int i = 0; i < GODRAY_STEPS; i++) {
                // Exponentialy spaced shadow samples
                current_depth = exp2(i + dither) - 0.6;
                if (current_depth > view_distance) {
                    break;
                }

                // Distance to depth
                current_depth = (far * (current_depth - near)) / (current_depth * (far - near));

                view_pos = vec3(texcoord, current_depth);

                // Clip to world
                pos = modeli_times_projectioni * (vec4(view_pos, 1.0) * 2.0 - 1.0);
                view_pos = (pos.xyz /= pos.w).xyz;
                shadow_pos = get_volumetric_pos(view_pos);
                
                light += shadow2D(shadowtex0, shadow_pos).r;
            }

            // light_color /= GODRAY_STEPS;
            light /= GODRAY_STEPS;

            // return light_color;
            return vec3(light);
        }
        
    #endif

#elif VOL_LIGHT == 1

    float ss_godrays(float dither) {
        float light = 0.0;
        float comp = 1.0 - (near / (far * far));

        vec2 ray_step = vec2(lightpos - texcoord) * 0.2;
        vec2 dither2d = texcoord + (ray_step * dither);

        float depth;

        for (int i = 0; i < CHEAP_GODRAY_SAMPLES; i++) {
            depth = texture2D(depthtex1, dither2d).x;
            dither2d += ray_step;
            light += step(comp, depth);
        }

        return light / CHEAP_GODRAY_SAMPLES;
  }

#endif
