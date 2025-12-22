/* MakeUp - water.glsl
Water reflection and refraction related functions.
ULTRA OPTIMIZED: Hybrid Approach (Cheap Far + Low Cost Contact Near)
*/

// Definición de la función de nubes externa
vec3 get_cloud(vec3 view_vector, vec3 block_color, float bright, float dither, vec3 base_pos, int samples, float umbral, vec3 cloud_color, vec3 dark_cloud_color);

// Import defaults if config not loaded (safety)
#ifndef WATER_COLOR_R
#define WATER_COLOR_R 0.1
#define WATER_COLOR_G 0.4
#define WATER_COLOR_B 0.7
#endif

#ifndef WATER_OPACITY
#define WATER_OPACITY 0.45
#endif

// --- FUNCIÓN DEDICADA: Reflejos Cercanos ULTRA OPTIMIZADOS ---
// Usa menos pasos y un refinamiento barato para máximo rendimiento.
vec4 near_reflection_calc(vec3 fragpos, vec3 reflected_dir, float dither) {
    // 1. Configuración de BAJO COSTO
    // Reducimos pasos para no saturar la GPU. 
    // Usamos dither para compensar la falta de pasos (el ruido es mejor que el lag).
    const int steps = 10;       // Solo 10 lecturas de textura (muy ligero)
    float max_dist = 5.0;       // Solo reflejamos los 5 metros inmediatos
    float step_len = max_dist / float(steps);

    vec3 ray_pos = fragpos;
    vec3 ray_dir = reflected_dir; 

    // Inicio aleatorio (Jitter) para ocultar bandas
    vec3 current_pos = ray_pos + ray_dir * (step_len * dither);
    
    // Variables de estado
    vec3 screen_pos;
    bool hit = false;
    
    // 2. Búsqueda Lineal Rápida
    for(int i = 0; i < steps; i++) {
        current_pos += ray_dir * step_len;
        screen_pos = camera_to_screen(current_pos);

        // Salida rápida si sale de pantalla
        if(screen_pos.x < 0.0 || screen_pos.x > 1.0 || screen_pos.y < 0.0 || screen_pos.y > 1.0 || screen_pos.z > 1.0) {
            return vec4(0.0); // Abortamos inmediatamente
        }

        // Lectura de profundidad (lo más costoso, por eso limitamos a 10)
        float stored_depth = texture2D(depthtex0, screen_pos.xy).r;

        float diff = screen_pos.z - stored_depth;
        
        // Tolerancia generosa (0.05) para asegurar que detectamos bloques/jugador
        // aunque los pasos sean grandes.
        if(diff > 0.0 && diff < 0.05) { 
            hit = true;
            break; 
        }
    }

    // 3. Resolución de Impacto (Sin Bucle Binario)
    // En lugar de gastar rendimiento refinando con un bucle, 
    // hacemos una interpolación simple. Es "bueno, bonito y barato".
    if(hit) {
        // Retrocedemos medio paso para aproximar el contacto
        // Esto reduce el error visual sin gastar ni un ciclo extra de GPU.
        vec3 final_screen_pos = screen_pos - (camera_to_screen(ray_dir * step_len * 0.5));
        
        // Comprobación final de seguridad
        if (final_screen_pos.x < 0.0 || final_screen_pos.x > 1.0 || final_screen_pos.y < 0.0 || final_screen_pos.y > 1.0) return vec4(0.0);

        // Fading de bordes (Vignette)
        vec2 edge = abs(final_screen_pos.xy * 2.0 - 1.0);
        float screen_fade = 1.0 - pow(max(edge.x, edge.y), 6.0);
        
        // Fading por distancia (para mezclar suavemente con el reflejo lejano)
        float dist = length(current_pos - fragpos);
        float dist_fade = 1.0 - clamp(dist / max_dist, 0.0, 1.0);

        return vec4(texture2D(gaux1, final_screen_pos.xy).rgb, screen_fade * dist_fade);
    }

    return vec4(0.0);
}

#if SUN_REFLECTION == 1
#if !defined NETHER && !defined THE_END
// Reflejo solar/lunar optimizado
float sun_reflection(vec3 reflected_dir) {
    #ifdef USE_PRENORMALIZED_DIRS
        vec3 astro_dir = (worldTime > 12900.0) ? moonDir : sunDir;
        vec3 cam_dir   = cameraDir;
    #else
        vec3 astro_dir = (worldTime > 12900.0) ? normalize(moonPosition) : normalize(sunPosition);
        vec3 cam_dir = vec3(0.0, 0.0, -1.0); 
    #endif

    float alignment = max(dot(reflected_dir, astro_dir), 0.0);
    float highlight = pow(alignment, 70.0);

    float attenuation = clamp(lmcoord.y, 0.0, 1.0) * (1.0 - rainStrength);
    float distanceFactor = 1.0;
    #if DYNAMIC_SUN_REFLECTION == 1
        float camAngle = max(dot(cam_dir, astro_dir), 0.0);
        distanceFactor = mix(0.6, 2.2, camAngle);
    #endif

    return highlight * attenuation * distanceFactor * 2.5;
}
#endif
#endif

vec3 normal_waves(vec3 pos) {
    float speed = frameTimeCounter * .025;
    vec2 wave_1 = texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.05) + vec2(speed, speed)).rg;
    wave_1 = wave_1 - .5;
    vec2 partial_wave = wave_1 * 2.0;
    vec3 final_wave = vec3(partial_wave, WATER_TURBULENCE - (rainStrength * 0.6 * WATER_TURBULENCE * visible_sky));
    return normalize(final_wave);
}

vec3 refraction(vec3 fragpos, vec3 color, vec3 refraction) {
    vec2 pos = gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y);
    #if REFRACTION == 1
    pos = pos + refraction.xy * (0.075 * REFRACTION_STRENGTH / (1.0 + length(fragpos) * 0.4));
    #endif

    float water_absortion;
    vec3 water_tint = vec3(WATER_COLOR_R, WATER_COLOR_G, WATER_COLOR_B);
    if (isEyeInWater == 0) {
        float water_distance = 2.0 * near * far / (far + near - (2.0 * gl_FragCoord.z - 1.0) * (far - near));
        float earth_distance = texture2D(depthtex1, pos.xy).r;
        earth_distance = 2.0 * near * far / (far + near - (2.0 * earth_distance - 1.0) * (far - near));
        #if defined DISTANT_HORIZONS
        float earth_distance_dh = texture2D(dhDepthTex1, pos.xy).r;
        earth_distance_dh = 2.0 * dhNearPlane * dhFarPlane / (dhFarPlane + dhNearPlane - (2.0 * earth_distance_dh - 1.0) * (dhFarPlane - dhNearPlane));
        earth_distance = min(earth_distance, earth_distance_dh);
        #endif

        float raw_depth = earth_distance - water_distance;
        water_absortion = clamp(1.0 - exp(-raw_depth * WATER_ABSORPTION * 10.0), 0.0, 1.0);
        water_absortion = max(water_absortion, WATER_OPACITY);
    } else {
        water_absortion = 0.0;
    }

    vec3 background = texture2D(gaux1, pos.xy).rgb;
    return mix(background, water_tint, water_absortion);
}

vec3 get_normals(vec3 bump, vec3 fragpos) {
    float NdotE = abs(dot(water_normal, normalize(fragpos)));
    bump *= vec3(NdotE) + vec3(0.0, 0.0, 1.0 - NdotE);
    mat3 tbn_matrix = mat3(
        tangent.x, binormal.x, water_normal.x,
        tangent.y, binormal.y, water_normal.y,
        tangent.z, binormal.z, water_normal.z);
    return normalize(bump * tbn_matrix);
}

// --- REFLEJOS HÍBRIDOS ---
vec3 water_shader(
    vec3 fragpos,
    vec3 normal,
    vec3 color,
    vec3 sky_reflect,
    vec3 reflected,
    float fresnel,
    float visible_sky,
    float dither,
    vec3 light_color) {
    
    vec3 final_reflection = vec3(0.0);
    float reflection_alpha = 0.0;

    // 1. REFLEJO LEJANO: FLIPPED IMAGE (Barato)
    #if defined DISTANT_HORIZONS
        vec3 distant_pos = camera_to_screen(fragpos + reflected * 768.0);
    #else
        vec3 distant_pos = camera_to_screen(fragpos + reflected * 76.0);
    #endif
    
    // Flipped Image Logic
    if (distant_pos.x > 0.0 && distant_pos.x < 1.0 && distant_pos.y > 0.0 && distant_pos.y < 1.0) {
        final_reflection = texture2D(gaux1, distant_pos.xy).rgb;
        vec2 fade_coord = (distant_pos.xy - 0.5) * 2.0;
        float border = 1.0 - pow(max(abs(fade_coord.x), abs(fade_coord.y)), 4.0);
        reflection_alpha = border;
    }

    // --- REFLEJOS VOLUMÉTRICOS (Fondo) ---
    #if defined(V_CLOUDS) && V_CLOUDS > 0 && defined(CLOUD_REFLECTION) && CLOUD_REFLECTION == 1
        vec3 world_reflected = mat3(gbufferModelViewInverse) * reflected;
        if (world_reflected.y > 0.0) {
             vec3 player_pos = (gbufferModelViewInverse * vec4(fragpos, 1.0)).xyz;
             vec3 world_pos = player_pos + cameraPosition;
             vec3 ref_cloud_col = light_color * 1.3 + vec3(0.15);
             vec3 ref_cloud_dark = light_color * 0.4;
             float umbral_local = (smoothstep(1.0, 0.0, rainStrength) * 0.3) + 0.25;
             
             // Muestras bajas (4) porque es fondo
             vec3 cloud_ref = get_cloud(world_reflected, sky_reflect, visible_sky, dither, world_pos, 4, umbral_local, ref_cloud_col, ref_cloud_dark);
             
             // Mezclar donde el flipped falla
             final_reflection = mix(cloud_ref * visible_sky, final_reflection, reflection_alpha);
             reflection_alpha = max(reflection_alpha, visible_sky); 
        }
    #endif

    // 2. REFLEJO CERCANO: RAYMARCHING DE CONTACTO (Calidad Local)
    vec4 near_ref = near_reflection_calc(fragpos, reflected, dither);
    
    // Mezcla final
    final_reflection = mix(final_reflection, near_ref.rgb, near_ref.a);

    #ifdef VANILLA_WATER
        fresnel *= 0.8;
    #endif

    float surface_visibility = max(fresnel, 0.15);
    
    #if SUN_REFLECTION == 1 && !defined(NETHER) && !defined(THE_END)
        return mix(color, final_reflection, surface_visibility * REFLEX_INDEX) +
               vec3(sun_reflection(reflected)) * light_color * visible_sky;
    #else
        return mix(color, final_reflection, surface_visibility * REFLEX_INDEX);
    #endif
}

// Shader para cristal
vec4 cristal_reflection_calc(vec3 fragpos, vec3 normal, inout float infinite, float dither) {
    vec3 reflected_vector = reflect(normalize(fragpos), normal);
    
    // Flipped Image para cristal
    vec3 pos = camera_to_screen(fragpos + reflected_vector * 76.0);
    vec2 fade_coord = (pos.xy - 0.5) * 2.0;
    float border = 1.0 - pow(max(abs(fade_coord.x), abs(fade_coord.y)), 4.0);
    border = clamp(border, 0.0, 1.0);
    
    vec3 final_col = texture2D(gaux1, pos.xy).rgb;

    // Reflejo cercano para cristal
    vec4 near_ref = near_reflection_calc(fragpos, reflected_vector, dither);
    final_col = mix(final_col, near_ref.rgb, near_ref.a);
    border = max(border, near_ref.a);

    return vec4(final_col, border);
}

vec4 cristal_shader(vec3 fragpos, vec3 normal, vec4 color, vec3 sky_reflection, float fresnel, float visible_sky, float dither, vec3 light_color) {
    vec4 reflection = vec4(0.0);
    float infinite = 0.0;
    
    #if REFLECTION == 1
        reflection = cristal_reflection_calc(fragpos, normal, infinite, dither);
    #endif
    
    sky_reflection = mix(color.rgb, sky_reflection, visible_sky * visible_sky);
    reflection.rgb = mix(sky_reflection, reflection.rgb, reflection.a);
    
    color.rgb = mix(color.rgb, sky_reflection, fresnel);
    color.rgb = mix(color.rgb, reflection.rgb, fresnel);
    color.a = mix(color.a, 1.0, fresnel * .9);
    
    #if SUN_REFLECTION == 1 && !defined(NETHER) && !defined(THE_END)
         return color + vec4(mix(vec3(sun_reflection(reflect(normalize(fragpos), normal)) * light_color * visible_sky), vec3(0.0), reflection.a), 0.0);
    #else
         return color;
    #endif
}