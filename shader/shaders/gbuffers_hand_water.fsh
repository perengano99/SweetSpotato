#version 120
/* MakeUp - gbuffers_hand_water.fsh
Render: Translucent hand objects

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define USE_BASIC_SH // Sets the use of a "basic" or "generic" shader for custom dimensions, instead of the default overworld shader. This can solve some rendering issues as the shader is closer to vanilla rendering.

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif
#define GBUFFER_HAND_WATER
#define SPECIAL_TRANS

// BEGIN INLINE /common/solid_blocks_fragment.glsl
#include "/lib/config.glsl"

// MAIN FUNCTION ------------------

#if defined THE_END
// BEGIN INLINE /lib/color_utils_end.glsl
/* MakeUp - color_utils.glsl
Usefull data for color manipulation.

Javier Garduño - GNU Lesser General Public License v3.0
*/

uniform float day_moment;
uniform float day_mixer;
uniform float night_mixer;

#define OMNI_TINT 0.5
#define LIGHT_SUNSET_COLOR vec3(0.1023825, 0.082467, 0.1023825)
#define LIGHT_DAY_COLOR vec3(0.1023825, 0.082467, 0.1023825)
#define LIGHT_NIGHT_COLOR vec3(0.1023825, 0.082467, 0.1023825)

#define ZENITH_SUNSET_COLOR vec3(0.0465375, 0.037485, 0.0465375)
#define ZENITH_DAY_COLOR vec3(0.0465375, 0.037485, 0.0465375)
#define ZENITH_NIGHT_COLOR vec3(0.0465375, 0.037485, 0.0465375)

#define HORIZON_SUNSET_COLOR vec3(0.0465375, 0.037485, 0.0465375)
#define HORIZON_DAY_COLOR vec3(0.0465375, 0.037485, 0.0465375)
#define HORIZON_NIGHT_COLOR vec3(0.0465375, 0.037485, 0.0465375)

#define WATER_COLOR vec3(0.01647059, 0.13882353, 0.16470588)

#if BLOCKLIGHT_TEMP == 0
    #define CANDLE_BASELIGHT vec3(0.29975, 0.15392353, 0.0799)
#elif BLOCKLIGHT_TEMP == 1
    #define CANDLE_BASELIGHT vec3(0.27475, 0.17392353, 0.0899)
#elif BLOCKLIGHT_TEMP == 2
    #define CANDLE_BASELIGHT vec3(0.24975, 0.19392353, 0.0999)
#elif BLOCKLIGHT_TEMP == 3
    #define CANDLE_BASELIGHT vec3(0.22, 0.19, 0.14)
#else
    #define CANDLE_BASELIGHT vec3(0.19, 0.19, 0.19)
#endif

// BEGIN INLINE /lib/day_blend.glsl
vec3 day_blend(vec3 sunset, vec3 day, vec3 night) {
    // f(x) = min(-((x-.25)^2)∙20 + 1.25, 1)
    // g(x) = min(-((x-.75)^2)∙50 + 3.125, 1)

    vec3 day_color = mix(sunset, day, day_mixer);
    vec3 night_color = mix(sunset, night, night_mixer);

    return mix(day_color, night_color, step(0.5, day_moment));
}

float day_blend_float(float sunset, float day, float night) {
    // f(x) = min(-((x-.25)^2)∙20 + 1.25, 1)
    // g(x) = min(-((x-.75)^2)∙50 + 3.125, 1)

    float day_value = mix(sunset, day, day_mixer);
    float night_value = mix(sunset, night, night_mixer);

    return mix(day_value, night_value, step(0.5, day_moment));
}
// END INLINE /lib/day_blend.glsl

// Fog parameter per hour
#if VOL_LIGHT == 1 || (VOL_LIGHT == 2 && defined SHADOW_CASTING)
    #define FOG_DENSITY 1.0
#else
    #define FOG_DAY 1.0
    #define FOG_SUNSET 1.0
    #define FOG_NIGHT 1.0
#endif

// BEGIN INLINE /lib/color_conversion.glsl
vec3 rgb_to_xyz(vec3 rgb) {
    vec3 xyz;
    vec3 rgb2 = rgb;
    vec3 mask = vec3(greaterThan(rgb, vec3(0.04045)));
    rgb2 = mix(rgb2 / 12.92, pow((rgb2 + 0.055) / 1.055, vec3(2.4)), mask);
    
    const mat3 rgb_to_xyz_matrix = mat3(
        0.4124564, 0.3575761, 0.1804375,
        0.2126729, 0.7151522, 0.0721750,
        0.0193339, 0.1191920, 0.9503041
    );
    
    xyz = rgb_to_xyz_matrix * rgb2;
    return xyz;
}

vec3 xyz_to_lab(vec3 xyz) {
    vec3 xyz2 = xyz / vec3(0.95047, 1.0, 1.08883);
    vec3 mask = vec3(greaterThan(xyz2, vec3(0.008856)));
    xyz2 = mix(7.787 * xyz2 + 16.0 / 116.0, pow(xyz2, vec3(1.0 / 3.0)), mask);
    
    float L = 116.0 * xyz2.y - 16.0;
    float a = 500.0 * (xyz2.x - xyz2.y);
    float b = 200.0 * (xyz2.y - xyz2.z);
    
    return vec3(L, a, b);
}

vec3 lab_to_xyz(vec3 lab) {
    float L = lab.x;
    float a = lab.y;
    float b = lab.z;
    
    float y = (L + 16.0) / 116.0;
    float x = a / 500.0 + y;
    float z = y - b / 200.0;
    
    vec3 xyz = vec3(x, y, z);
    vec3 mask = vec3(greaterThan(xyz, vec3(0.2068966)));
    xyz = mix((xyz - 16.0 / 116.0) / 7.787, xyz * xyz * xyz, mask);
    
    return xyz * vec3(0.95047, 1.0, 1.08883);
}

vec3 xyz_to_rgb(vec3 xyz) {
    const mat3 xyz_to_rgb_matrix = mat3(
        3.2404542, -1.5371385, -0.4985314,
        -0.9692660,  1.8760108,  0.0415560,
        0.0556434, -0.2040259,  1.0572252
    );
    
    vec3 rgb = xyz_to_rgb_matrix * xyz;
    vec3 mask = vec3(greaterThan(rgb, vec3(0.0031308)));
    rgb = mix(12.92 * rgb, 1.055 * pow(rgb, vec3(1.0 / 2.4)) - 0.055, mask);
    
    return clamp(rgb, 0.0, 1.0);
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

/* ----------- */

// Funciones auxiliares para la corrección gamma (sRGB <-> Lineal)
// Convierte un canal de sRGB a RGB lineal
float srgb_to_linear(float c) {
    if (c <= 0.04045) {
        return c / 12.92;
    } else {
        return pow((c + 0.055) / 1.055, 2.4);
    }
}

// Convierte un vector de sRGB a RGB lineal
vec3 srgb_to_linear(vec3 c) {
    return vec3(
        srgb_to_linear(c.r),
        srgb_to_linear(c.g),
        srgb_to_linear(c.b)
    );
}

// Convierte un canal de RGB lineal a sRGB
float linear_to_srgb(float c) {
    if (c <= 0.0031308) {
        return c * 12.92;
    } else {
        return 1.055 * pow(c, 1.0 / 2.4) - 0.055;
    }
}

// Convierte un vector de RGB lineal a sRGB
vec3 linear_to_srgb(vec3 c) {
    return vec3(
        linear_to_srgb(c.r),
        linear_to_srgb(c.g),
        linear_to_srgb(c.b)
    );
}

// Matrices de transformación para Oklab
const mat3 M1 = mat3(
    0.412453, 0.357576, 0.180438,
    0.212671, 0.715160, 0.072169,
    0.019334, 0.119192, 0.950304
);

const mat3 M2 = mat3(
    0.2104542553,  0.7936177850, -0.0040720468,
    1.9779984951, -2.4285922050,  0.4505937099,
    0.0259040371,  0.7827717662, -0.8086757660
);

const mat3 INV_M1 = mat3(
    3.2404542, -1.5371385, -0.4985314,
   -0.9692660,  1.8760108,  0.0415560,
    0.0556434, -0.2040259,  1.0572252
);

const mat3 INV_M2 = mat3(
    1.0, 0.3963377774, 0.2158037573,
    1.0, -0.1055613458, -0.0638541728,
    1.0, -0.0894841775, -1.2914855480
);


// ----- FUNCIÓN PRINCIPAL DE CONVERSIÓN RGB -> OKLAB -----
vec3 rgb_to_oklab(vec3 c) {
    // 1. Convertir de sRGB a RGB lineal
    vec3 linear_rgb = srgb_to_linear(c);
    vec3 lms = M1 * linear_rgb;
    vec3 lms_cubed = pow(lms, vec3(1.0/3.0));
    return M2 * lms_cubed;
}


// ----- FUNCIÓN PRINCIPAL DE CONVERSIÓN OKLAB -> RGB -----
vec3 oklab_to_rgb(vec3 c) {
    vec3 lms_cubed = INV_M2 * c;
    vec3 lms = pow(lms_cubed, vec3(3.0));
    vec3 linear_rgb = INV_M1 * lms;

    return linear_to_srgb(linear_rgb);
}
// END INLINE /lib/color_conversion.glsl
// END INLINE /lib/color_utils_end.glsl
#elif defined NETHER
// BEGIN INLINE /lib/color_utils_nether.glsl
/* MakeUp - color_utils.glsl
Usefull data for color manipulation.

Javier Garduño - GNU Lesser General Public License v3.0
*/

uniform float day_moment;
uniform float day_mixer;
uniform float night_mixer;

#define OMNI_TINT 0.5
#define LIGHT_SUNSET_COLOR vec3(0.06885294, 0.06297058, 0.04879411)
#define LIGHT_DAY_COLOR vec3(0.06885294, 0.06297058, 0.04879411)
#define LIGHT_NIGHT_COLOR vec3(0.06885294, 0.06297058, 0.04879411)

#define ZENITH_SUNSET_COLOR vec3(0.0479638 , 0.04343892, 0.04253394)
#define ZENITH_DAY_COLOR vec3(0.0479638 , 0.04343892, 0.04253394)
#define ZENITH_NIGHT_COLOR vec3(0.0479638 , 0.04343892, 0.04253394)

#define HORIZON_SUNSET_COLOR vec3(0.0479638 , 0.04343892, 0.04253394)
#define HORIZON_DAY_COLOR vec3(0.0479638 , 0.04343892, 0.04253394)
#define HORIZON_NIGHT_COLOR vec3(0.0479638 , 0.04343892, 0.04253394)

#define WATER_COLOR vec3(0.01647059, 0.13882353, 0.16470588)

#if BLOCKLIGHT_TEMP == 0
    #define CANDLE_BASELIGHT vec3(0.29975, 0.15392353, 0.0799)
#elif BLOCKLIGHT_TEMP == 1
    #define CANDLE_BASELIGHT vec3(0.27475, 0.17392353, 0.0899)
#elif BLOCKLIGHT_TEMP == 2
    #define CANDLE_BASELIGHT vec3(0.24975, 0.19392353, 0.0999)
#elif BLOCKLIGHT_TEMP == 3
    #define CANDLE_BASELIGHT vec3(0.22, 0.19, 0.14)
#else
    #define CANDLE_BASELIGHT vec3(0.19, 0.19, 0.19)
#endif

// BEGIN INLINE /lib/day_blend.glsl
vec3 day_blend(vec3 sunset, vec3 day, vec3 night) {
    // f(x) = min(-((x-.25)^2)∙20 + 1.25, 1)
    // g(x) = min(-((x-.75)^2)∙50 + 3.125, 1)

    vec3 day_color = mix(sunset, day, day_mixer);
    vec3 night_color = mix(sunset, night, night_mixer);

    return mix(day_color, night_color, step(0.5, day_moment));
}

float day_blend_float(float sunset, float day, float night) {
    // f(x) = min(-((x-.25)^2)∙20 + 1.25, 1)
    // g(x) = min(-((x-.75)^2)∙50 + 3.125, 1)

    float day_value = mix(sunset, day, day_mixer);
    float night_value = mix(sunset, night, night_mixer);

    return mix(day_value, night_value, step(0.5, day_moment));
}
// END INLINE /lib/day_blend.glsl

// Fog parameter per hour
#define FOG_DAY 1.0
#define FOG_SUNSET 1.0
#define FOG_NIGHT 1.0

// BEGIN INLINE /lib/color_conversion.glsl
vec3 rgb_to_xyz(vec3 rgb) {
    vec3 xyz;
    vec3 rgb2 = rgb;
    vec3 mask = vec3(greaterThan(rgb, vec3(0.04045)));
    rgb2 = mix(rgb2 / 12.92, pow((rgb2 + 0.055) / 1.055, vec3(2.4)), mask);
    
    const mat3 rgb_to_xyz_matrix = mat3(
        0.4124564, 0.3575761, 0.1804375,
        0.2126729, 0.7151522, 0.0721750,
        0.0193339, 0.1191920, 0.9503041
    );
    
    xyz = rgb_to_xyz_matrix * rgb2;
    return xyz;
}

vec3 xyz_to_lab(vec3 xyz) {
    vec3 xyz2 = xyz / vec3(0.95047, 1.0, 1.08883);
    vec3 mask = vec3(greaterThan(xyz2, vec3(0.008856)));
    xyz2 = mix(7.787 * xyz2 + 16.0 / 116.0, pow(xyz2, vec3(1.0 / 3.0)), mask);
    
    float L = 116.0 * xyz2.y - 16.0;
    float a = 500.0 * (xyz2.x - xyz2.y);
    float b = 200.0 * (xyz2.y - xyz2.z);
    
    return vec3(L, a, b);
}

vec3 lab_to_xyz(vec3 lab) {
    float L = lab.x;
    float a = lab.y;
    float b = lab.z;
    
    float y = (L + 16.0) / 116.0;
    float x = a / 500.0 + y;
    float z = y - b / 200.0;
    
    vec3 xyz = vec3(x, y, z);
    vec3 mask = vec3(greaterThan(xyz, vec3(0.2068966)));
    xyz = mix((xyz - 16.0 / 116.0) / 7.787, xyz * xyz * xyz, mask);
    
    return xyz * vec3(0.95047, 1.0, 1.08883);
}

vec3 xyz_to_rgb(vec3 xyz) {
    const mat3 xyz_to_rgb_matrix = mat3(
        3.2404542, -1.5371385, -0.4985314,
        -0.9692660,  1.8760108,  0.0415560,
        0.0556434, -0.2040259,  1.0572252
    );
    
    vec3 rgb = xyz_to_rgb_matrix * xyz;
    vec3 mask = vec3(greaterThan(rgb, vec3(0.0031308)));
    rgb = mix(12.92 * rgb, 1.055 * pow(rgb, vec3(1.0 / 2.4)) - 0.055, mask);
    
    return clamp(rgb, 0.0, 1.0);
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

/* ----------- */

// Funciones auxiliares para la corrección gamma (sRGB <-> Lineal)
// Convierte un canal de sRGB a RGB lineal
float srgb_to_linear(float c) {
    if (c <= 0.04045) {
        return c / 12.92;
    } else {
        return pow((c + 0.055) / 1.055, 2.4);
    }
}

// Convierte un vector de sRGB a RGB lineal
vec3 srgb_to_linear(vec3 c) {
    return vec3(
        srgb_to_linear(c.r),
        srgb_to_linear(c.g),
        srgb_to_linear(c.b)
    );
}

// Convierte un canal de RGB lineal a sRGB
float linear_to_srgb(float c) {
    if (c <= 0.0031308) {
        return c * 12.92;
    } else {
        return 1.055 * pow(c, 1.0 / 2.4) - 0.055;
    }
}

// Convierte un vector de RGB lineal a sRGB
vec3 linear_to_srgb(vec3 c) {
    return vec3(
        linear_to_srgb(c.r),
        linear_to_srgb(c.g),
        linear_to_srgb(c.b)
    );
}

// Matrices de transformación para Oklab
const mat3 M1 = mat3(
    0.412453, 0.357576, 0.180438,
    0.212671, 0.715160, 0.072169,
    0.019334, 0.119192, 0.950304
);

const mat3 M2 = mat3(
    0.2104542553,  0.7936177850, -0.0040720468,
    1.9779984951, -2.4285922050,  0.4505937099,
    0.0259040371,  0.7827717662, -0.8086757660
);

const mat3 INV_M1 = mat3(
    3.2404542, -1.5371385, -0.4985314,
   -0.9692660,  1.8760108,  0.0415560,
    0.0556434, -0.2040259,  1.0572252
);

const mat3 INV_M2 = mat3(
    1.0, 0.3963377774, 0.2158037573,
    1.0, -0.1055613458, -0.0638541728,
    1.0, -0.0894841775, -1.2914855480
);


// ----- FUNCIÓN PRINCIPAL DE CONVERSIÓN RGB -> OKLAB -----
vec3 rgb_to_oklab(vec3 c) {
    // 1. Convertir de sRGB a RGB lineal
    vec3 linear_rgb = srgb_to_linear(c);
    vec3 lms = M1 * linear_rgb;
    vec3 lms_cubed = pow(lms, vec3(1.0/3.0));
    return M2 * lms_cubed;
}


// ----- FUNCIÓN PRINCIPAL DE CONVERSIÓN OKLAB -> RGB -----
vec3 oklab_to_rgb(vec3 c) {
    vec3 lms_cubed = INV_M2 * c;
    vec3 lms = pow(lms_cubed, vec3(3.0));
    vec3 linear_rgb = INV_M1 * lms;

    return linear_to_srgb(linear_rgb);
}
// END INLINE /lib/color_conversion.glsl
// END INLINE /lib/color_utils_nether.glsl
#endif

/* Uniforms */

uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
uniform sampler2D tex;
uniform int isEyeInWater;
uniform float nightVision;
uniform float rainStrength;
uniform float light_mix;
uniform float pixel_size_x;
uniform float pixel_size_y;
uniform sampler2D gaux4;

#if defined DISTANT_HORIZONS
    uniform float dhNearPlane;
    uniform float far;
#endif

#if defined GBUFFER_ENTITIES
    uniform int entityId;
    uniform vec4 entityColor;
#endif

#ifdef NETHER
    uniform vec3 fogColor;
#endif

#if defined SHADOW_CASTING
    uniform sampler2DShadow shadowtex1;
    #if defined COLORED_SHADOW
        uniform sampler2DShadow shadowtex0;
        uniform sampler2D shadowcolor0;
    #endif
#endif

uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
    uniform float darknessLightFactor;
#endif

#ifdef MATERIAL_GLOSS
  // Don't remove
#endif

#if defined MATERIAL_GLOSS && !defined NETHER
    uniform int worldTime;
    uniform vec3 moonPosition;
    uniform vec3 sunPosition;
    #if defined THE_END
        uniform mat4 gbufferModelView;
    #endif
#endif

/* Ins / Outs */

varying vec2 texcoord;
varying vec4 tint_color;
varying float frog_adjust;
varying vec3 direct_light_color;
varying vec3 candle_color;
varying float direct_light_strength;
varying vec3 omni_light;

#if defined GBUFFER_TERRAIN || defined GBUFFER_HAND
    varying float emmisive_type;
#endif

#ifdef FOLIAGE_V
    varying float is_foliage;
#endif

#if defined SHADOW_CASTING && !defined NETHER
    varying vec3 shadow_pos;
    varying float shadow_diffuse;
#endif

#if defined MATERIAL_GLOSS && !defined NETHER
    varying vec3 flat_normal;
    varying vec3 sub_position3_normalized;
    varying vec2 lmcoord_alt;
    varying float gloss_factor;
    varying float gloss_power;
    varying float luma_factor;
    varying float luma_power;
#endif

/* Utility functions */

#if (defined SHADOW_CASTING && !defined NETHER) || defined DISTANT_HORIZONS
// BEGIN INLINE /lib/dither.glsl
/* MakeUp - dither.glsl
Dither and hash functions

There are a multitude of dithers in MakeUp, with different variants.

There are fixed ones (that do not change over time) as well as those that change
when temporal sampling is active. Of the latter, there are two versions:
one that uses dither_shift (Minecraft 1.13+) and another that uses frame_mod
to rotate the dither values.

There are several variants because each one performs better or worse
depending on the situation in which it is used.

The philosophy of their use is as follows:
1) use the fastest one possible that still produces acceptable results.
2) If multiple effects use a dithering and they are in the same step
of the Optifine/Iris pipeline, then calculate the dithering only once
and use it in all the effects that need it to avoid redundant calculations.

The variants that change over time have the prefix "shifted".

The variants with the prefix 'eclectic' are perturbed versions of their simpler counterparts.
They offer good results because they avoid the appearance of repetitive patterns,
but they require the calculation of a hash to create this perturbation.

There is a function based on a texture, which assumes a size for the texture of 64x64 pixels,
but there is no such texture currently.

*/

#if MC_VERSION >= 11300
    uniform float dither_shift;
#endif
uniform int frame_mod;

float hash12(vec2 v)
{
    v = 0.0002314814814814815 * v + vec2(0.25, 0.0);
    float state = fract(dot(v * v, vec2(3571.0)));
    return fract(state * state * 7142.0);
}

float hash13(vec3 v)
{
    v = fract(v * .1031);
    v += dot(v, v.zyx + 31.32);
    return fract((v.x + v.y) * v.z);
}

vec2 hash22(vec2 p)
{
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

float r_dither(vec2 frag) {
    return fract(dot(frag, vec2(0.75487766624669276, 0.569840290998)));
}

float eclectic_r_dither(vec2 frag) {
    vec2 v = 0.0002314814814814815 * frag + vec2(0.25, 0.0);
    float state = fract(dot(v * v, vec2(3571.0)));
    float p4 = fract(state * state * 7142.0) * 0.075;

    return fract(dot(frag, vec2(0.75487766624669276, 0.569840290998)) + p4);
}

float dither13(vec2 frag)
{
    return fract(dot(frag, vec2(0.3076923076923077, 0.5384615384615384)));
}

float eclectic_dither13(vec2 frag)
{
    vec2 v = 0.0002314814814814815 * frag + vec2(0.25, 0.0);
    float state = fract(dot(v * v, vec2(3571.0)));
    float p4 = fract(state * state * 7142.0) * 0.075;

    return fract(dot(frag, vec2(0.3076923076923077, 0.5384615384615384)) + p4);
}

float dither17(vec2 pos) {
  return fract(dot(pos, vec2(0.11764705882352941, 0.4117647058823529)));
}

float eclectic_dither17(vec2 frag) {
  vec2 v = 0.0002314814814814815 * frag + vec2(0.25, 0.0);
  float state = fract(dot(v * v, vec2(3571.0)));
  float p4 = fract(state * state * 7142.0) * 0.15;

  return fract(p4 + dot(frag, vec2(0.11764705882352941, 0.4117647058823529)));
}

float dither_grad_noise(vec2 frag) {
    return fract(52.9829189 * fract(dot(vec2(0.06711056, 0.00583715), frag)));
}

float eclectic_dither_grad_noise(vec2 frag) {
    vec2 v = 0.0002314814814814815 * frag + vec2(0.25, 0.0);
    float state = fract(dot(v * v, vec2(3571.0)));
    float p4 = fract(state * state * 7142.0) * 0.075;

    return fract(52.9829189 * fract(dot(vec2(0.06711056, 0.00583715), frag)) + p4);
}

float texture_noise_64(vec2 p, sampler2D noise) {
    return texture2DLod(noise, p * 0.015625, 0).r;
}

float semiblue(vec2 xy) {
    vec2 tile = floor(xy * 0.25);
    float flip = mod(tile.x + tile.y, 2.0);
    xy = mix(xy, xy.yx, flip);

    return fract(dot(vec2(0.75487766624669276, 0.569840290998), xy) + hash12(tile));
}

float dither_makeup(vec2 xy) {
    vec2 tile = floor(xy * 0.125);
    float flip = mod(tile.x + tile.y, 2.0);
    vec2 zw = mix(xy, xy.yx, flip);

    return fract(
        dot(vec2(0.24512233375330728, 0.4301597090019468), zw) +
        dot(vec2(0.735151469707489, 0.737424373626709), tile)
    );
}

// float valve_red(vec2 xy) {
//     float vDither = dot(vec2( 171.0, 231.0 ), xy );
//     return fract(vDither / 103.0);  // (103.0, 71. 97.0 )
// }

#if MC_VERSION >= 11300

    float shifted_hash12(vec2 v)
    {
        v = 0.0002314814814814815 * v + vec2(0.25, 0.0);
        float state = fract(dot(v * v, vec2(3571.0)));
        return fract(dither_shift + (state * state * 7142.0));
    }

    float shifted_hash13(vec3 v)
    {
        v = fract(v * .1031);
        v += dot(v, v.zyx + 31.32);
        return fract(dither_shift + ((v.x + v.y) * v.z));
    }

    float shifted_r_dither(vec2 frag) {
        return fract(dither_shift + dot(frag, vec2(0.75487766624669276, 0.569840290998)));
    }

    float shifted_eclectic_r_dither(vec2 frag) {
        vec2 v = 0.0002314814814814815 * frag + vec2(0.25, 0.0);
        float state = fract(dot(v * v, vec2(3571.0)));
        float p4 = fract(state * state * 7142.0) * 0.075;

        return fract(dot(frag, vec2(0.75487766624669276, 0.569840290998)) + dither_shift + p4);
    }

    float shifted_dither13(vec2 frag)
    {
        return fract(dither_shift + dot(frag, vec2(0.3076923076923077, 0.5384615384615384)));
    }

    float shifted_eclectic_dither13(vec2 frag)
    {
        vec2 v = 0.0002314814814814815 * frag + vec2(0.25, 0.0);
        float state = fract(dot(v * v, vec2(3571.0)));
        float p4 = fract(state * state * 7142.0) * 0.075;

        return fract(dot(frag, vec2(0.3076923076923077, 0.5384615384615384)) + dither_shift + p4);
    }

    float shifted_dither17(vec2 pos) {
        return fract(dither_shift + dot(pos, vec2(0.11764705882352941, 0.4117647058823529)));
    }

    float shifted_eclectic_dither17(vec2 frag) {
        vec2 v = 0.0002314814814814815 * frag + vec2(0.25, 0.0);
        float state = fract(dot(v * v, vec2(3571.0)));
        float p4 = fract(state * state * 7142.0) * 0.15;

        return fract(dither_shift + p4 + dot(frag, vec2(0.11764705882352941, 0.4117647058823529)));
    }

    float shifted_dither_grad_noise(vec2 frag) {
        return fract(dither_shift + (52.9829189 * fract(dot(vec2(0.06711056, 0.00583715), frag))));
    }

    float shifted_eclectic_dither_grad_noise(vec2 frag) {
        vec2 v = 0.0002314814814814815 * frag + vec2(0.25, 0.0);
        float state = fract(dot(v * v, vec2(3571.0)));
        float p4 = fract(state * state * 7142.0) * 0.075;

        return fract(52.9829189 * fract(dot(vec2(0.06711056, 0.00583715), frag)) + dither_shift + p4);  
    }

    float shifted_texture_noise_64(vec2 p, sampler2D noise) {
        float dither = texture2DLod(noise, p * 0.015625, 0).r;
        return fract(dither_shift + dither);
    }

    float shifted_semiblue(vec2 xy) {
        vec2 tile = floor(xy * 0.25);
        float flip = mod(tile.x + tile.y, 2.0);
        xy = mix(xy, xy.yx, flip);

        return fract(dither_shift + dot(vec2(0.75487766624669276, 0.569840290998), xy) + hash12(tile));
    }

    float shifted_dither_makeup(vec2 xy) {
        xy = xy + vec2(frame_mod * 3, frame_mod);
        vec2 tile = floor(xy * 0.125);
        float flip = mod(tile.x + tile.y, 2.0);
        vec2 zw = mix(xy, xy.yx, flip);

        return fract(
            dither_shift +
            dot(vec2(0.24512233375330728, 0.4301597090019468), zw) +
            dot(vec2(0.735151469707489, 0.737424373626709), tile)
        );
    }


    // float shifted_valve_red(vec2 xy) {
    //     float vDither = dot(vec2( 171.0, 231.0 ), xy );
    //     vDither = fract(vDither / 103.0);  // (103.0, 71. 97.0 )

    //     return fract(dither_shift + vDither);
    // }

#else

    float shifted_hash12(vec2 v)
    {
        v = 0.0002314814814814815 * v + vec2(0.25, 0.0);
        float state = fract(dot(v * v, vec2(3571.0)));
        return fract((frame_mod * 0.4) + (state * state * 7142.0));
    }

    float shifted_hash13(vec3 v)
    {
        v = fract(v * .1031);
        v += dot(v, v.zyx + 31.32);
        return fract((frame_mod * 0.4) + ((v.x + v.y) * v.z));
    }

    float shifted_r_dither(vec2 frag) {
        return fract((frame_mod * 0.4) + dot(frag, vec2(0.75487766624669276, 0.569840290998)));
    }

    float shifted_r_dither(vec2 frag) {
        return fract((frame_mod * 0.4) + dot(frag, vec2(0.75487766624669276, 0.569840290998)));
    }

    float shifted_eclectic_r_dither(vec2 frag) {
        vec2 v = 0.0002314814814814815 * frag + vec2(0.25, 0.0);
        float state = fract(dot(v * v, vec2(3571.0)));
        float p4 = fract(state * state * 7142.0) * 0.075;

        return fract(dot(frag, vec2(0.75487766624669276, 0.569840290998)) + (frame_mod * 0.4) + p4);
    }

    float shifted_dither13(vec2 frag)
    {
        return fract((frame_mod * 0.4) + dot(frag, vec2(0.3076923076923077, 0.5384615384615384)));
    }

    float shifted_dither_grad_noise(vec2 frag) {
        return fract((frame_mod * 0.4) + (52.9829189 * fract(dot(vec2(0.06711056, 0.00583715), frag))));
    }

    float shifted_eclectic_dither_grad_noise(vec2 frag) {
        vec2 v = 0.0002314814814814815 * frag + vec2(0.25, 0.0);
        float state = fract(dot(v * v, vec2(3571.0)));
        float p4 = fract(state * state * 7142.0) * 0.075;

        return fract(52.9829189 * fract(dot(vec2(0.06711056, 0.00583715), frag)) + (frame_mod * 0.4) + p4);
    }

    float shifted_texture_noise_64(vec2 p, sampler2D noise) {
        float dither = texture2DLod(noise, p * 0.015625, 0).r;
        return fract((frame_mod * 0.4) + dither);
    }

    float shifted_semiblue(vec2 xy) {
        vec2 tile = floor(xy * 0.25);
        float flip = mod(tile.x + tile.y, 2.0);
        xy = mix(xy, xy.yx, flip);

        return fract((frame_mod * 0.4) + dot(vec2(0.75487766624669276, 0.569840290998), xy) + hash12(tile));
    }

    float shifted_dither_makeup(vec2 xy) {
        vec2 tile = floor(xy * 0.125);
        float flip = mod(tile.x + tile.y, 2.0);
        vec2 zw = mix(xy, xy.yx, flip);

        return fract(
            (frame_mod * 0.4) +
            dot(vec2(0.24512233375330728, 0.4301597090019468), zw) +
            dot(vec2(0.735151469707489, 0.737424373626709), tile)
        );
    }

    // float shifted_valve_red(vec2 xy) {
    //     float vDither = dot(vec2( 171.0, 231.0 ), xy );
    //     vDither = fract(vDither / 103.0);  // (103.0, 71. 97.0 )

    //     return fract((frame_mod * 0.4) + vDither);
    // }

#endif
// END INLINE /lib/dither.glsl
#endif

#if defined SHADOW_CASTING && !defined NETHER
// BEGIN INLINE /lib/shadow_frag.glsl
/* MakeUp - shadow_frag.glsl
Fragment shadow function.

Javier Garduño - GNU Lesser General Public License v3.0
*/

float get_shadow(vec3 the_shadow_pos, float dither) {
    float shadow_sample = 1.0;

#if SHADOW_TYPE == 0  // Pixelated
    shadow_sample = shadow2D(shadowtex1, the_shadow_pos).r;
#elif SHADOW_TYPE == 1  // Soft
    float current_radius = dither;
    dither *= 6.283185307179586;
    float dither_2 = dither + 1.5707963267948966;

    shadow_sample = 0.0;

    vec2 offset = (vec2(cos(dither), sin(dither)) * current_radius * SHADOW_BLUR) / shadowMapResolution;
    vec2 offset_2 = (vec2(cos(dither_2), sin(dither_2)) * (1.0 - current_radius) * SHADOW_BLUR) / shadowMapResolution;
    // vec2 offset_2 = vec2(-offset.y, offset.x);

    float z_bias = dither * 0.00002;

    shadow_sample += shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset, the_shadow_pos.z - z_bias)).r;
    shadow_sample += shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset, the_shadow_pos.z - z_bias)).r;
    shadow_sample += shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset_2, the_shadow_pos.z - z_bias)).r;
    shadow_sample += shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset_2, the_shadow_pos.z - z_bias)).r;

    // shadow_sample *= 0.5;
    shadow_sample *= 0.25;
#endif

    return shadow_sample;
}

#if defined COLORED_SHADOW

vec3 get_colored_shadow(vec3 the_shadow_pos, float dither) {
#if SHADOW_TYPE == 0  // Pixelated
    float shadow_detector = 1.0;
    float shadow_black = 1.0;
    vec4 shadow_color = vec4(1.0);

    float alpha_complement;

    shadow_detector = shadow2D(shadowtex0, vec3(the_shadow_pos.xy, the_shadow_pos.z)).r;
    if (shadow_detector < 1.0) {
        shadow_black = shadow2D(shadowtex1, vec3(the_shadow_pos.xy, the_shadow_pos.z)).r;
        if (shadow_black != shadow_detector) {
            shadow_color = texture2D(shadowcolor0, the_shadow_pos.xy);
            alpha_complement = 1.0 - shadow_color.a;
            shadow_color.rgb = mix(shadow_color.rgb, vec3(1.0), alpha_complement);
            shadow_color.rgb *= alpha_complement;
        }
    }

    shadow_color *= shadow_black;
    shadow_color.rgb = clamp(shadow_color.rgb * (1.0 - shadow_detector) + shadow_detector, vec3(0.0), vec3(1.0));

    return shadow_color.rgb;

#elif SHADOW_TYPE == 1  // Soft
    float shadow_detector_a = 1.0;
    float shadow_black_a = 1.0;
    vec4 shadow_color_a = vec4(1.0);

    float shadow_detector_b = 1.0;
    float shadow_black_b = 1.0;
    vec4 shadow_color_b = vec4(1.0);

    float shadow_detector_c = 1.0;
    float shadow_black_c = 1.0;
    vec4 shadow_color_c = vec4(1.0);

    float shadow_detector_d = 1.0;
    float shadow_black_d = 1.0;
    vec4 shadow_color_d = vec4(1.0);

    float alpha_complement;

    float current_radius = dither;
    dither *= 6.283185307179586;
    float dither_2 = dither + 1.5707963267948966;

    vec2 offset = (vec2(cos(dither), sin(dither)) * current_radius * SHADOW_BLUR) / shadowMapResolution;
    vec2 offset_2 = (vec2(cos(dither_2), sin(dither_2)) * (1.0 - current_radius) * SHADOW_BLUR) / shadowMapResolution;
    // vec2 offset_2 = vec2(-offset.y, offset.x);

    float z_bias = dither * 0.00002;

    shadow_detector_a = shadow2D(shadowtex0, vec3(the_shadow_pos.xy + offset, the_shadow_pos.z - z_bias)).r;
    shadow_detector_b = shadow2D(shadowtex0, vec3(the_shadow_pos.xy - offset, the_shadow_pos.z - z_bias)).r;
    shadow_detector_c = shadow2D(shadowtex0, vec3(the_shadow_pos.xy + offset_2, the_shadow_pos.z - z_bias)).r;
    shadow_detector_d = shadow2D(shadowtex0, vec3(the_shadow_pos.xy - offset_2, the_shadow_pos.z - z_bias)).r;

    if (shadow_detector_a < 1.0) {
        shadow_black_a = shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset, the_shadow_pos.z - z_bias)).r;
        if (shadow_black_a != shadow_detector_a) {
            shadow_color_a = texture2D(shadowcolor0, the_shadow_pos.xy + offset);
            alpha_complement = 1.0 - shadow_color_a.a;
            shadow_color_a.rgb = mix(shadow_color_a.rgb, vec3(1.0), alpha_complement);
            shadow_color_a.rgb *= alpha_complement;
        }
    }

    shadow_color_a *= shadow_black_a;

    if (shadow_detector_b < 1.0) {
        shadow_black_b = shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset, the_shadow_pos.z - z_bias)).r;
        if (shadow_black_b != shadow_detector_b) {
            shadow_color_b = texture2D(shadowcolor0, the_shadow_pos.xy - offset);
            alpha_complement = 1.0 - shadow_color_b.a;
            shadow_color_b.rgb = mix(shadow_color_b.rgb, vec3(1.0), alpha_complement);
            shadow_color_b.rgb *= alpha_complement;
        }
    }

    shadow_color_b *= shadow_black_b;

    if (shadow_detector_c < 1.0) {
        shadow_black_c = shadow2D(shadowtex1, vec3(the_shadow_pos.xy + offset_2, the_shadow_pos.z - z_bias)).r;
        if (shadow_black_c != shadow_detector_c) {
            shadow_color_c = texture2D(shadowcolor0, the_shadow_pos.xy + offset_2);
            alpha_complement = 1.0 - shadow_color_c.a;
            shadow_color_c.rgb = mix(shadow_color_c.rgb, vec3(1.0), alpha_complement);
            shadow_color_c.rgb *= alpha_complement;
        }
    }

    shadow_color_c *= shadow_black_c;

    if (shadow_detector_d < 1.0) {
        shadow_black_d = shadow2D(shadowtex1, vec3(the_shadow_pos.xy - offset_2, the_shadow_pos.z - z_bias)).r;
        if (shadow_black_d != shadow_detector_d) {
            shadow_color_d = texture2D(shadowcolor0, the_shadow_pos.xy - offset_2);
            alpha_complement = 1.0 - shadow_color_d.a;
            shadow_color_d.rgb = mix(shadow_color_d.rgb, vec3(1.0), alpha_complement);
            shadow_color_d.rgb *= alpha_complement;
        }
    }

    shadow_color_d *= shadow_black_d;

    shadow_detector_a = (shadow_detector_a + shadow_detector_b + shadow_detector_c + shadow_detector_d);
    shadow_detector_a *= 0.25;

    shadow_color_a.rgb = (shadow_color_a.rgb + shadow_color_b.rgb + shadow_color_c.rgb + shadow_color_d.rgb) * 0.25;
    shadow_color_a.rgb = mix(shadow_color_a.rgb, vec3(1.0), shadow_detector_a);

    return shadow_color_a.rgb;
#endif
}

#endif
// END INLINE /lib/shadow_frag.glsl
#endif

// BEGIN INLINE /lib/luma.glsl
/* MakeUp - luma.glsl
Luma related functions.

Javier Garduño - GNU Lesser General Public License v3.0
*/

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float color_average(vec3 color) {
    return (color.r + color.g + color.b) * 0.3333333333;
}
// END INLINE /lib/luma.glsl

#if defined MATERIAL_GLOSS && !defined NETHER
// BEGIN INLINE /lib/material_gloss_fragment.glsl
#if defined THE_END
    float material_gloss(vec3 reflected_vector, vec2 lmcoord_alt, float gloss_power, vec3 flat_normal) {
        vec3 astro_pos = (gbufferModelView * vec4(0.0, 0.89442719, 0.4472136, 0.0)).xyz;
        float astro_vector =
            max(dot(normalize(reflected_vector), normalize(astro_pos)), 0.0) * step(0.0001, dot(astro_pos, flat_normal));

        return clamp(
            mix(0.0, 1.0, pow(clamp(astro_vector * 2.0 - 1.0, 0.0, 1.0), gloss_power)),
            0.0,
            1.0
        );
    }
#else
    float material_gloss(vec3 reflected_vector, vec2 lmcoord_alt, float gloss_power, vec3 flat_normal) {
        vec3 astro_pos = mix(-sunPosition, sunPosition, light_mix);
        float astro_vector =
            max(dot(normalize(reflected_vector), normalize(astro_pos)), 0.0) *
        step(0.0001, dot(astro_pos, flat_normal));

        return clamp(
            mix(0.0, 1.0, pow(clamp(astro_vector * 2.0 - 1.0, 0.0, 1.0), gloss_power)) *
            clamp(lmcoord_alt.y, 0.0, 1.0) *
            (1.0 - rainStrength),
            0.0,
            1.0
        ) * abs(mix(1.0, -1.0, light_mix));
    }
#endif
// END INLINE /lib/material_gloss_fragment.glsl
#endif

void main() {
    #if (defined SHADOW_CASTING && !defined NETHER) || defined DISTANT_HORIZONS
        #if AA_TYPE > 0 
            float dither = shifted_dither_makeup(gl_FragCoord.xy);
        #else
            float dither = r_dither(gl_FragCoord.xy);
        #endif
    #endif
    // Avoid render in DH transition
    #if defined DISTANT_HORIZONS && !defined GBUFFER_BEACONBEAM
        float t = far - dhNearPlane;
        float sup = t * TRANSITION_DH_SUP;
        float inf = t * TRANSITION_DH_INF;
        float umbral = (gl_FogFragCoord - (dhNearPlane + inf)) / (far - sup - inf - dhNearPlane);
        if(umbral > dither) {
            discard;
            return;
        }
    #endif

    // Toma el color puro del bloque
    #if defined GBUFFER_ENTITIES && BLACK_ENTITY_FIX == 1
        vec4 block_color = texture2D(tex, texcoord);
        if(block_color.a < 0.1 && entityId != 10101) {   // Black entities bug workaround
            discard;
        }
        block_color *= tint_color;
    #else
        vec4 block_color = texture2D(tex, texcoord) * tint_color;
    #endif

        float block_luma = luma(block_color.rgb);

        vec3 final_candle_color = candle_color;
    #if defined GBUFFER_TERRAIN || defined GBUFFER_HAND
        if(emmisive_type > 0.5) {
            final_candle_color *= block_luma * 1.5;
        }
    #endif

    #ifdef GBUFFER_WEATHER
        block_color.a *= .5;
    #endif

    #if defined GBUFFER_ENTITIES
        // Thunderbolt render
        if(entityId == 10101) {
            block_color.a = 1.0;
        }
    #endif

    #if defined SHADOW_CASTING && !defined NETHER
        #if defined COLORED_SHADOW
            vec3 shadow_c = get_colored_shadow(shadow_pos, dither);
            shadow_c = mix(shadow_c, vec3(1.0), shadow_diffuse);
        #else
            float shadow_c = get_shadow(shadow_pos, dither);
            shadow_c = mix(shadow_c, 1.0, shadow_diffuse);
        #endif
    #else
        float shadow_c = abs((light_mix * 2.0) - 1.0);
    #endif

    #if defined GBUFFER_BEACONBEAM
        block_color.rgb *= 1.5;
    #elif defined GBUFFER_ENTITY_GLOW
        block_color.rgb =
            clamp(vec3(luma(block_color.rgb)) * vec3(0.75, 0.75, 1.5), vec3(0.3), vec3(1.0));
        vec3 real_light = omni_light +
                (shadow_c * direct_light_color * direct_light_strength) * (1.0 - (rainStrength * 0.75)) +
                final_candle_color;
    #else
        #if defined MATERIAL_GLOSS && !defined NETHER
            float final_gloss_power = gloss_power;
            block_luma *= luma_factor;

            if(luma_power < 0.0) {  // Metallic
                final_gloss_power -= (block_luma * 73.334);
            } else {
                block_luma = pow(block_luma, luma_power);
            }

            float material_gloss_factor = material_gloss(reflect(sub_position3_normalized, flat_normal), lmcoord_alt, final_gloss_power, flat_normal) * gloss_factor;

            float material = material_gloss_factor * block_luma;
            vec3 real_light = omni_light +
                (shadow_c * ((direct_light_color * direct_light_strength) + (direct_light_color * material))) * (1.0 - (rainStrength * 0.75)) +
                final_candle_color;
        #else
            vec3 real_light = omni_light +
                (shadow_c * direct_light_color * direct_light_strength) * (1.0 - (rainStrength * 0.75)) +
                final_candle_color;
        #endif

        block_color.rgb *= mix(real_light, vec3(1.0), nightVision * 0.125);
        block_color.rgb *= mix(vec3(1.0, 1.0, 1.0), vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B), nightVision);
    #endif

    #if defined GBUFFER_ENTITIES
        if(entityId == 10101) {
            // Thunderbolt render
            block_color = vec4(1.0, 1.0, 1.0, 0.5);
        } else {
            float entity_poderation = luma(real_light);  // Red damage bright ponderation
            block_color.rgb = mix(block_color.rgb, entityColor.rgb, entityColor.a * entity_poderation * 3.0);
        }
    #endif

    #if MC_VERSION < 11300 && defined GBUFFER_TEXTURED
        block_color.rgb *= 1.5;
    #endif

// BEGIN INLINE /src/finalcolor.glsl
#if defined THE_END
    if(isEyeInWater == 0 && FOG_ADJUST < 15.0) {  // In the air
        block_color.rgb = mix(block_color.rgb, ZENITH_DAY_COLOR, frog_adjust);
    }
#elif defined NETHER
    if(isEyeInWater == 0 && FOG_ADJUST < 15.0) {  // In the air
        block_color.rgb = mix(block_color.rgb, mix(fogColor * 0.1, vec3(1.0), 0.04), frog_adjust);
    }
#else
    #ifdef FOG_ACTIVE  // Fog active
        #if MC_VERSION >= 11900
            vec3 fog_texture;
            if(darknessFactor > .01) {
                fog_texture = vec3(0.0);
            } else {
                fog_texture = texture2D(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y)).rgb;
            }
        #else
            vec3 fog_texture = texture2D(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y)).rgb;
        #endif
        #if defined GBUFFER_ENTITIES
            if(isEyeInWater == 0 && entityId != 10101 && FOG_ADJUST < 15.0) {  // In the air
                block_color.rgb = mix(block_color.rgb, fog_texture, frog_adjust);
            }
        #else
            if(isEyeInWater == 0) {  // In the air
                block_color.rgb = mix(block_color.rgb, fog_texture, frog_adjust);
            }
        #endif
    #endif
#endif

#if MC_VERSION >= 11900
    if(blindness > .01 || darknessFactor > .01) {
        block_color.rgb = mix(block_color.rgb, vec3(0.0), max(blindness, darknessLightFactor) * gl_FogFragCoord * 0.24);
    }
#else
    if(blindness > .01) {
        block_color.rgb = mix(block_color.rgb, vec3(0.0), blindness * gl_FogFragCoord * 0.24);
    }
#endif
// END INLINE /src/finalcolor.glsl
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
// END INLINE /common/solid_blocks_fragment.glsl
