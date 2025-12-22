/* MakeUp - config.glsl
Config variables
OPTIMIZED FOR GTX 1650 / Low-End GPUs
*/

/*------------------------------------------------------------------------------
  CATEGORIES
- ENTITY ID'S
- GENERAL
- REFLECTIONS
- FOG
- WATER
- DEPTH OF FIELD (DOF)
- AMBIENT OCCLUSION (AO)
- ANTI-ALIASING (AA)
- MOTION BLUR
- SHADOWS
- BLOOM
- CHROMATIC ABERRATION
- VOLUMETRIC LIGHTING
- CLOUDS
- GODRAYS
- COLORS
- COLORBLIND
- PERFORMANCE & OPTIMIZATION
- EXPERIMENTAL
------------------------------------------------------------------------------*/

//----------------------------------------
// ENTITY ID'S
//----------------------------------------
#define ENTITY_SMALLGRASS     10031.0
#define ENTITY_LOWERGRASS     10175.0
#define ENTITY_UPPERGRASS     10176.0
#define ENTITY_SMALLENTS      10059.0
#define ENTITY_SMALLENTS_NW   10032.0
#define ENTITY_LEAVES         10018.0
#define ENTITY_VINES          10106.0
#define ENTITY_EMMISIVE       10089.0
#define ENTITY_S_EMMISIVE     10090.0
#define ENTITY_F_EMMISIVE     10213.0
#define ENTITY_NO_SHADOW_FIRE 10214.0
#define ENTITY_WATER          10008.0
#define ENTITY_PORTAL         10090.0
#define ENTITY_STAINED        10079.0
#define ENTITY_METAL          10400.0
#define ENTITY_SAND           10410.0
#define ENTITY_FABRIC         10440.0

//----------------------------------------
// GENERAL
//----------------------------------------
#define ACERCADE 0 // [0]

#define AA_TYPE 2 // [0 1 2 3]

#define BLACK_ENTITY_FIX 0

const float sunPathRotation = -25.0;

#define BLOCKLIGHT_TEMP 1
#define DYN_HAND_LIGHT

//----------------------------------------
// REFLECTIONS
//----------------------------------------
#define REFLECTION_SLIDER 2 // [0 1 2]
/* 0 - Flipped image: Fastest.
1 - Flipped image (High Q): Fast.
2 - Raymarching: Heavy (Optimized to 5 steps below).
*/

#if REFLECTION_SLIDER == 0
#define REFLECTION 0
#define SSR_TYPE 0
#define REFLEX_INDEX 0.45
#elif REFLECTION_SLIDER == 1
#define REFLECTION 1
#define SSR_TYPE 0
#define REFLEX_INDEX 0.7
#elif REFLECTION_SLIDER == 2
#define REFLECTION 1
#define SSR_TYPE 1
#define REFLEX_INDEX 0.7
#endif

#define SUN_REFLECTION 1 // [0 1]
#define DYNAMIC_SUN_REFLECTION 1 // [0 1]

//----------------------------------------
// FOG
//----------------------------------------
#define FOG_ACTIVE // Toggle fog
#ifdef FOG_ACTIVE
// Don't remove
#endif

#define NETHER_FOG_DISTANCE 1 // [0 1]
#if NETHER_FOG_DISTANCE == 1
#define NETHER_SIGHT min(far / 2, 96)
#else
#define NETHER_SIGHT far
#endif

#define UNDERWATER_FOG 1        // [0 1]
#define UNDERWATER_FOG_DISTANCE 20.0 // [5.0 10.0 15.0 20.0 25.0 30.0 40.0 50.0]

#define FOG_ADJUST 2.0

//----------------------------------------
// WATER
//----------------------------------------
#define WAVES 1 // [0 1]

#define WATER_DISPLACEMENT 1 // [0 1]

#define WATER_NORMAL_STRENGTH 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0] 
#define WATER_WAVE_SPEED 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0]

#define TINTED_WATER 1  // [0 1]

#define REFRACTION 1  // [0 1]
#define REFRACTION_STRENGTH 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.5 2.0]

#define WATER_ABSORPTION 0.10
#define WATER_OPACITY 0.45 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

#define WATER_TEXTURE 0
// #define VANILLA_WATER
#define WATER_COLOR_SOURCE 0
#define WATER_TURBULENCE 0.9 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define WATER_FOAM 0 // [0 1]

//----------------------------------------
// DEPTH OF FIELD (DOF)
//----------------------------------------
// #define DOF // Disable DOF by default for performance
#define DOF_STRENGTH 0.09

//----------------------------------------
// AMBIENT OCCLUSION (AO)
//----------------------------------------
#define AO 1  // [0 1]
#if AO == 0
const float ambientOcclusionLevel = 0.7;
#else
const float ambientOcclusionLevel = 0.0;
#endif

#define AOSTEPS 3 // [2 3 4] Reduced from 4 to 3 for optimization
#define AO_STRENGTH 0.70

//----------------------------------------
// ANTI-ALIASING (AA)
//----------------------------------------
#define AA_TYPE 2 // [0 1 2 3]

//----------------------------------------
// MOTION BLUR
//----------------------------------------
//#define MOTION_BLUR
#define MOTION_BLUR_STRENGTH 1.0
#define MOTION_BLUR_SAMPLES 3 // [3 4] Reduced samples for speed

//----------------------------------------
// SHADOWS
//----------------------------------------
#define SHADOW_CASTING
#define SHADOW_TYPE 1 // [0 1]
#define SHADOW_BLUR 1.0 // [0.0 1.0 2.0 3.0]
// #define COLORED_SHADOW // DISABLED FOR PERFORMANCE

#define SHADOW_DISTANCE_SLIDER 1 // [0 1 2]
#define SHADOW_QTY_SLIDER 2 // [1 2 3]


#ifdef SHADOW_CASTING
// Shadow parameters
const float shadowIntervalSize = 3.0;
const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowColor0Mipmap = false;
const bool shadowColor1Mipmap = false;
const bool shadowtex0Clear = false;
const bool shadowtex1Clear = false;
const bool shadowcolor0Clear = false;
const bool shadowcolor1Clear = false;

#ifndef NO_SHADOWS
// --- OPTIMIZATION: Shadow Map Resolution Clamping ---
#if SHADOW_DISTANCE_SLIDER == 0 // Short Distance (75)
#if SHADOW_QTY_SLIDER == 1
#define SHADOW_LIMIT 75.0
const int shadowMapResolution = 300; // Ultra Low
const float shadowDistance = 75.0;
#define SHADOW_FIX_FACTOR 0.3
#define SHADOW_DIST 0.75

#elif SHADOW_QTY_SLIDER == 2
#define SHADOW_LIMIT 75.0
const int shadowMapResolution = 600; // Low/Medium
const float shadowDistance = 75.0;
#define SHADOW_FIX_FACTOR 0.15
#define SHADOW_DIST 0.81

#elif SHADOW_QTY_SLIDER == 3
#define SHADOW_LIMIT 75.0
const int shadowMapResolution = 1024; // CAPPED from 1200
const float shadowDistance = 75.0;
#define SHADOW_FIX_FACTOR 0.05
#define SHADOW_DIST 0.81

#endif

#elif SHADOW_DISTANCE_SLIDER == 1 // Medium Distance (105)
#if SHADOW_QTY_SLIDER == 1
#define SHADOW_LIMIT 105.0
const int shadowMapResolution = 420;
const float shadowDistance = 105.0;
#define SHADOW_FIX_FACTOR 0.28
#define SHADOW_DIST 0.75

#elif SHADOW_QTY_SLIDER == 2
#define SHADOW_LIMIT 105.0
const int shadowMapResolution = 840;
const float shadowDistance = 105.0;
#define SHADOW_FIX_FACTOR 0.07
#define SHADOW_DIST 0.83

#elif SHADOW_QTY_SLIDER == 3
#define SHADOW_LIMIT 105.0
const int shadowMapResolution = 1200; // CAPPED from 1680
const float shadowDistance = 105.0;
#define SHADOW_FIX_FACTOR 0.03
#define SHADOW_DIST 0.83

#endif

#elif SHADOW_DISTANCE_SLIDER == 2 // Far Distance (255)
#if SHADOW_QTY_SLIDER == 1
#define SHADOW_LIMIT 255.0
const int shadowMapResolution = 1024; 
const float shadowDistance = 255.0;
#define SHADOW_FIX_FACTOR 0.12
#define SHADOW_DIST 0.8

#elif SHADOW_QTY_SLIDER == 2
#define SHADOW_LIMIT 255.0
const int shadowMapResolution = 1536; // CAPPED from 2040
const float shadowDistance = 255.0;
#define SHADOW_FIX_FACTOR 0.03
#define SHADOW_DIST 0.85

#elif SHADOW_QTY_SLIDER == 3
#define SHADOW_LIMIT 255.0
const int shadowMapResolution = 2048; // HARD CAP from 4080 (Huge optimization)
const float shadowDistance = 255.0;
#define SHADOW_FIX_FACTOR 0.015
#define SHADOW_DIST 0.87

#endif
#endif

#if VOL_LIGHT == 2
const float shadowDistanceRenderMul = -1.0;
#else
const float shadowDistanceRenderMul = 1.0;
#endif

const bool shadowHardwareFiltering = true;
const bool shadowtex1Nearest = false;
#endif

#else
#define SHADOW_DIST 0.0
#define SHADOW_RES 0
const int shadowMapResolution = 100;
const float shadowDistance = 60.0;
#endif

//----------------------------------------
// BLOOM
//----------------------------------------
#define BLOOM
#define BLOOM_SAMPLES 2.0

//----------------------------------------
// CHROMATIC ABERRATION
//----------------------------------------
#define CHROMA_ABER 0
#define CHROMA_ABER_STRENGTH 0.04

//----------------------------------------
// VOLUMETRIC LIGHTING
//----------------------------------------
#define VOL_LIGHT 2 // [0 1 2]

//----------------------------------------
// CLOUDS
//----------------------------------------
#define V_CLOUDS 1 // [0 1 2]
#define CLOUD_VOL_STYLE 0 // [0 1]
#define CLOUD_REFLECTION 1 // [0 1]
// [0: Desactivado | 1: Activado] Reflejo de nubes independiente y optimizado sobre el agua. Toggleable y de bajo costo.
#define END_CLOUDS

// Cloud parameters
#if CLOUD_VOL_STYLE == 1
#define CLOUD_PLANE_SUP 380.0
#define CLOUD_PLANE_CENTER 335.0
#define CLOUD_PLANE 319.0
#else
#define CLOUD_PLANE_SUP 590.0
#define CLOUD_PLANE_CENTER 375.0
#define CLOUD_PLANE 319.0
#endif

// --- OPTIMIZATION: Cloud Steps ---
#define CLOUD_STEPS_AVG 6

#define CLOUD_SPEED 0
#if CLOUD_VOL_STYLE == 1
#if CLOUD_SPEED == 0
#define CLOUD_HI_FACTOR 0.001388888888888889
#define CLOUD_LOW_FACTOR 0.0002777777777777778
#elif CLOUD_SPEED == 1
#define CLOUD_HI_FACTOR 0.01388888888888889
#define CLOUD_LOW_FACTOR 0.002777777777777778
#elif CLOUD_SPEED == 2
#define CLOUD_HI_FACTOR 0.1388888888888889
#define CLOUD_LOW_FACTOR 0.02777777777777778
#endif
#else
#if CLOUD_SPEED == 0
#define CLOUD_HI_FACTOR 0.0016666666666666666
#define CLOUD_LOW_FACTOR 0.0002777777777777778
#elif CLOUD_SPEED == 1
#define CLOUD_HI_FACTOR 0.016666666666666666
#define CLOUD_LOW_FACTOR 0.002777777777777778
#elif CLOUD_SPEED == 2
#define CLOUD_HI_FACTOR 0.16666666666666666
#define CLOUD_LOW_FACTOR 0.02777777777777778
#endif
#endif

//----------------------------------------
// GODRAYS
//----------------------------------------
#define GODRAY_STEPS 40 // [4 5 6 8 10 12 16 40]
#define CHEAP_GODRAY_SAMPLES 40 // [4 6 8 10 12 40]
#define VOL_LIGHT_STRENGTH 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.5 2.0]

//----------------------------------------
// COLORS
//----------------------------------------
#define COLOR_SCHEME 1

#define NIGHT_BRIGHT 0.1

// Custom colors
#define LIGHT_SUNSET_COLOR_R 1
#define LIGHT_SUNSET_COLOR_G 0.59
#define LIGHT_SUNSET_COLOR_B 0.35
#define LIGHT_DAY_COLOR_R 0.90
#define LIGHT_DAY_COLOR_G 0.84
#define LIGHT_DAY_COLOR_B 0.79
#define LIGHT_NIGHT_COLOR_R 0.05
#define LIGHT_NIGHT_COLOR_G 0.05
#define LIGHT_NIGHT_COLOR_B 0.06
#define ZENITH_SUNSET_COLOR_R 0.14
#define ZENITH_SUNSET_COLOR_G 0.24
#define ZENITH_SUNSET_COLOR_B 0.36
#define ZENITH_DAY_COLOR_R 0.14
#define ZENITH_DAY_COLOR_G 0.24
#define ZENITH_DAY_COLOR_B 0.36
#define ZENITH_NIGHT_COLOR_R 0.014
#define ZENITH_NIGHT_COLOR_G 0.019
#define ZENITH_NIGHT_COLOR_B 0.025
#define HORIZON_SUNSET_COLOR_R 1.0
#define HORIZON_SUNSET_COLOR_G 0.65
#define HORIZON_SUNSET_COLOR_B 0.38
#define HORIZON_DAY_COLOR_R 0.65
#define HORIZON_DAY_COLOR_G 0.91
#define HORIZON_DAY_COLOR_B 1.3
#define HORIZON_NIGHT_COLOR_R 0.021
#define HORIZON_NIGHT_COLOR_G 0.031
#define HORIZON_NIGHT_COLOR_B 0.039

#define ZENITH_SKY_RAIN_COLOR vec3(.7, .85, 1.0)
#define HORIZON_SKY_RAIN_COLOR vec3(0.35 , 0.425, 0.5)

// Restored to original values
#define WATER_COLOR_R 0.05
#define WATER_COLOR_G 0.10
#define WATER_COLOR_B 0.11

#define NV_COLOR_R 0.5
#define NV_COLOR_G 0.8
#define NV_COLOR_B 1.0
#define OMNI_TINT_CUSTOM 0.3

//----------------------------------------
// COLORBLIND
//----------------------------------------
#define COLOR_BLIND_MODE 0

//----------------------------------------
// PERFORMANCE & OPTIMIZATION
//----------------------------------------
const float eyeBrightnessHalflife = 3.0;
const float centerDepthHalflife = 0.66;

#define AVOID_DARK_LEVEL 0.001

// --- OPTIMIZATION: Raymarch Steps ---
#define RAYMARCH_STEPS 5

//----------------------------------------
// EXPERIMENTAL
//----------------------------------------
#define MATERIAL_GLOSS

// DH exclusive
#if defined DISTANT_HORIZONS
#define TRANSITION_DH_SUP 0.05
#define TRANSITION_DH_INF 0.90
#endif

// #define DEBUG_MODE