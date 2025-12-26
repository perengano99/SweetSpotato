#version 120
/* MakeUp - dh_water.vsh
Render: DH Water

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define DH_WATER
#define THE_END

// BEGIN INLINE /common/solid_dh_water_vertex.glsl
#include "/lib/config.glsl"

/* Color utils */

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
#else
// BEGIN INLINE /lib/color_utils.glsl
/* MakeUp - color_utils.glsl
Usefull data for color manipulation.

Javier Garduño - GNU Lesser General Public License v3.0
*/

uniform float day_moment;
uniform float day_mixer;
uniform float night_mixer;
uniform int moonPhase;

#ifdef UNKNOWN_DIM
uniform vec3 fogColor;
uniform vec3 skyColor;
#endif

#define NIGHT_BRIGHT_PHASE (NIGHT_BRIGHT + (NIGHT_BRIGHT * (abs(4.0 - moonPhase) * 0.25)))

#if COLOR_SCHEME == 0  // Ethereal
#define OMNI_TINT 0.4
#define LIGHT_SUNSET_COLOR vec3(0.887528, 0.443394, 0.301044)
#define LIGHT_DAY_COLOR vec3(0.90, 0.84, 0.79)
#define LIGHT_NIGHT_COLOR vec3(0.0317353, 0.0467353, 0.0637353) * NIGHT_BRIGHT_PHASE

#define ZENITH_SUNSET_COLOR vec3(0.2617647, 0.33529412, 0.52352941)
#define ZENITH_DAY_COLOR vec3(0.0785098, 0.24352941, 0.54901961)
#define ZENITH_NIGHT_COLOR vec3(0.0168, 0.0228, 0.03) * NIGHT_BRIGHT_PHASE

#define HORIZON_SUNSET_COLOR vec3(1.0, 0.6, 0.394)
#define HORIZON_DAY_COLOR vec3(0.65, 0.91, 1.3)
#define HORIZON_NIGHT_COLOR vec3(0.02556, 0.03772, 0.05244) * NIGHT_BRIGHT_PHASE

#define WATER_COLOR vec3(0.05, 0.1, 0.11)
#elif COLOR_SCHEME == 1  // New shoka
#define OMNI_TINT 0.25
#define LIGHT_SUNSET_COLOR vec3(1.0, 0.588, 0.3555)
#define LIGHT_DAY_COLOR vec3(0.90, 0.84, 0.79)
#define LIGHT_NIGHT_COLOR vec3(0.04786874, 0.05175001, 0.06112969) * NIGHT_BRIGHT_PHASE

#define ZENITH_SUNSET_COLOR vec3(0.143, 0.24394118, 0.36450981)
#define ZENITH_DAY_COLOR vec3(0.143, 0.24394118, 0.36450981)
#define ZENITH_NIGHT_COLOR vec3(0.014, 0.019, 0.025) * NIGHT_BRIGHT_PHASE

#define HORIZON_SUNSET_COLOR vec3(1.0, 0.648, 0.37824)
#define HORIZON_DAY_COLOR vec3(0.65, 0.91, 1.3)
#define HORIZON_NIGHT_COLOR vec3(0.0213, 0.0306, 0.0387) * NIGHT_BRIGHT_PHASE

#define WATER_COLOR vec3(0.05, 0.1, 0.11)
#elif COLOR_SCHEME == 2  // Shoka
#define OMNI_TINT 0.5
#define LIGHT_SUNSET_COLOR vec3(0.70656, 0.44436, 0.2898)
#define LIGHT_DAY_COLOR vec3(0.91640625, 0.91640625, 0.635375)
#define LIGHT_NIGHT_COLOR vec3(0.04786874, 0.05175001, 0.06112969) * NIGHT_BRIGHT_PHASE

#define ZENITH_SUNSET_COLOR vec3(0.104, 0.17741177, 0.26509804)
#define ZENITH_DAY_COLOR vec3(0.13, 0.22176471, 0.33137255)
#define ZENITH_NIGHT_COLOR vec3(0.014, 0.019, 0.025) * NIGHT_BRIGHT_PHASE

#define HORIZON_SUNSET_COLOR vec3(0.715 , 0.5499, 0.416)
#define HORIZON_DAY_COLOR vec3(0.364 , 0.6825, 0.91)
#define HORIZON_NIGHT_COLOR vec3(0.0213, 0.0306, 0.0387) * NIGHT_BRIGHT_PHASE

#define WATER_COLOR vec3(0.01647059, 0.13882353, 0.16470588)
#elif COLOR_SCHEME == 3  // Legacy
#define OMNI_TINT 0.5
#define LIGHT_SUNSET_COLOR vec3(0.96876, 0.4356254, 0.26002448)
#define LIGHT_DAY_COLOR vec3(0.88504, 0.88504, 0.8372)
#define LIGHT_NIGHT_COLOR vec3(0.04693014, 0.0507353 , 0.05993107) * NIGHT_BRIGHT_PHASE

#define ZENITH_SUNSET_COLOR vec3(0.09410295, 0.20145588, 0.34905882)
#define ZENITH_DAY_COLOR vec3(0.182, 0.351, 0.754)
#define ZENITH_NIGHT_COLOR vec3(0.00841175, 0.01651763, 0.025) * NIGHT_BRIGHT_PHASE

#define HORIZON_SUNSET_COLOR vec3(0.81, 0.44165647, 0.25293529)
#define HORIZON_DAY_COLOR vec3(0.572, 1.014, 1.248)
#define HORIZON_NIGHT_COLOR vec3(0.01078431, 0.02317647, 0.035) * NIGHT_BRIGHT_PHASE

#define WATER_COLOR vec3(0.01647059, 0.13882353, 0.16470588)
#elif COLOR_SCHEME == 4  // Captain
#define OMNI_TINT 0.5
#define LIGHT_SUNSET_COLOR vec3(0.84456, 0.52992, 0.26496001)
#define LIGHT_DAY_COLOR vec3(0.83064961, 0.93448079, 1.1032065)
#define LIGHT_NIGHT_COLOR vec3(0.02597646, 0.05195295, 0.069) * NIGHT_BRIGHT_PHASE

#define ZENITH_SUNSET_COLOR vec3(0.18135 , 0.230256, 0.332592)
#define ZENITH_DAY_COLOR vec3(0.104, 0.26, 0.507)
#define ZENITH_NIGHT_COLOR vec3(0.004 ,0.01, 0.0195) * NIGHT_BRIGHT_PHASE

#define HORIZON_SUNSET_COLOR vec3(1.3, 0.8632, 0.3952)
#define HORIZON_DAY_COLOR vec3(0.65, 0.91, 1.3)
#define HORIZON_NIGHT_COLOR vec3(0.025, 0.035, 0.05) * NIGHT_BRIGHT_PHASE

#define WATER_COLOR vec3(0.05, 0.1, 0.11)
#elif COLOR_SCHEME == 5  // Psychedelic
#define OMNI_TINT 0.45
#define LIGHT_SUNSET_COLOR vec3(0.85 , 0.47058824, 0.17921569)
#define LIGHT_DAY_COLOR vec3(0.91021875, 0.95771875, 0.6)
#define LIGHT_NIGHT_COLOR vec3(0.04223712, 0.04566177, 0.05393796) * NIGHT_BRIGHT_PHASE

#define ZENITH_SUNSET_COLOR vec3(0.18135 , 0.230256, 0.332592)
#define ZENITH_DAY_COLOR vec3(0.104, 0.26, 0.507)
#define ZENITH_NIGHT_COLOR vec3(0.004 ,0.01, 0.0195) * NIGHT_BRIGHT_PHASE

#define HORIZON_SUNSET_COLOR vec3(1.3, 0.8632, 0.3952)
#define HORIZON_DAY_COLOR vec3(0.65, 0.91, 1.3)
#define HORIZON_NIGHT_COLOR vec3(0.025, 0.035, 0.05) * NIGHT_BRIGHT_PHASE

#define WATER_COLOR vec3(0.018, 0.12 , 0.18)
#elif COLOR_SCHEME == 6  // Cocoa
#define OMNI_TINT 0.4
#define LIGHT_SUNSET_COLOR vec3(0.918528, 0.5941728, 0.2712528)
#define LIGHT_DAY_COLOR vec3(0.897, 0.897, 0.5718375)
#define LIGHT_NIGHT_COLOR vec3(0.04693014, 0.0507353, 0.05993107) * NIGHT_BRIGHT_PHASE

#define ZENITH_SUNSET_COLOR vec3(0.117, 0.26, 0.494)
#define ZENITH_DAY_COLOR vec3(0.234, 0.403, 0.676)
#define ZENITH_NIGHT_COLOR vec3(0.014, 0.019, 0.031) * NIGHT_BRIGHT_PHASE

#define HORIZON_SUNSET_COLOR vec3(1.183, 0.858, 0.611)
#define HORIZON_DAY_COLOR vec3(0.52, 0.975, 1.3)
#define HORIZON_NIGHT_COLOR vec3(0.022, 0.029, 0.049) * NIGHT_BRIGHT_PHASE

#define WATER_COLOR vec3(0.0196, 0.1804, 0.3216)
#elif COLOR_SCHEME == 7  // Testigo
#define OMNI_TINT 0.65
#define LIGHT_SUNSET_COLOR vec3(0.70656, 0.44436, 0.2898)
#define LIGHT_DAY_COLOR vec3(0.88504, 0.88504, 0.8372)
#define LIGHT_NIGHT_COLOR vec3(0.04786874, 0.05175001, 0.06112969) * NIGHT_BRIGHT_PHASE

#define ZENITH_SUNSET_COLOR vec3(0.104, 0.17741177, 0.26509804)
#define ZENITH_DAY_COLOR vec3(0.05098, 0.25990, 0.44313)
#define ZENITH_NIGHT_COLOR vec3(0.004 ,0.01, 0.0195) * NIGHT_BRIGHT_PHASE

#define HORIZON_SUNSET_COLOR vec3(0.715 , 0.5499, 0.416)
#define HORIZON_DAY_COLOR vec3(0.65, 0.91, 1.3)
#define HORIZON_NIGHT_COLOR vec3(0.025, 0.035, 0.05) * NIGHT_BRIGHT_PHASE

#define WATER_COLOR vec3(0.0118, 0.1098, 0.1922)
#elif COLOR_SCHEME == 99 // Custom
#define OMNI_TINT OMNI_TINT_CUSTOM
#define LIGHT_SUNSET_COLOR vec3(LIGHT_SUNSET_COLOR_R, LIGHT_SUNSET_COLOR_G, LIGHT_SUNSET_COLOR_B)
#define LIGHT_DAY_COLOR vec3(LIGHT_DAY_COLOR_R, LIGHT_DAY_COLOR_G, LIGHT_DAY_COLOR_B)
#define LIGHT_NIGHT_COLOR vec3(LIGHT_NIGHT_COLOR_R, LIGHT_NIGHT_COLOR_G, LIGHT_NIGHT_COLOR_B) * NIGHT_BRIGHT_PHASE

#define ZENITH_SUNSET_COLOR vec3(ZENITH_SUNSET_COLOR_R, ZENITH_SUNSET_COLOR_G, ZENITH_SUNSET_COLOR_B)
#define ZENITH_DAY_COLOR vec3(ZENITH_DAY_COLOR_R, ZENITH_DAY_COLOR_G, ZENITH_DAY_COLOR_B)
#define ZENITH_NIGHT_COLOR vec3(ZENITH_NIGHT_COLOR_R, ZENITH_NIGHT_COLOR_G, ZENITH_NIGHT_COLOR_B) * NIGHT_BRIGHT_PHASE

#define HORIZON_SUNSET_COLOR vec3(HORIZON_SUNSET_COLOR_R, HORIZON_SUNSET_COLOR_G, HORIZON_SUNSET_COLOR_B)
#define HORIZON_DAY_COLOR vec3(HORIZON_DAY_COLOR_R, HORIZON_DAY_COLOR_G, HORIZON_DAY_COLOR_B)
#define HORIZON_NIGHT_COLOR vec3(HORIZON_NIGHT_COLOR_R, HORIZON_NIGHT_COLOR_G, HORIZON_NIGHT_COLOR_B) * NIGHT_BRIGHT_PHASE

#define WATER_COLOR vec3(WATER_COLOR_R, WATER_COLOR_G, WATER_COLOR_B)
#endif

#define NV_COLOR vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B)

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
#if VOL_LIGHT == 1 || (VOL_LIGHT == 2 && defined SHADOW_CASTING) || defined UNKNOWN_DIM
#define FOG_DENSITY 3.0
#else
#define FOG_DAY 3.0
#define FOG_SUNSET 2.0
#define FOG_NIGHT 3.0
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

// --- NEW OPTIMIZATION HELPERS ---
// Added at the end to avoid breaking existing structure

// Get water color based on current scheme (WATER_COLOR macro)
// This ensures consistency with the selected scheme.
vec3 getUnderwaterColor() {
    return WATER_COLOR;
}

// Helper to calculate fog density based on surface opacity slider
// Ensures "if surface is thick, underwater is thick" logic.
float getUnderwaterFogDensity() {
    // Base density + extra density from the opacity slider
    // Multiplied by 0.5 to keep it playable but dense.
    float baseDensity = 0.05 + (WATER_OPACITY * 0.5);

    // Multiplier slider allows tweaking distance/density
    return baseDensity * UNDERWATER_FOG_DENSITY_MULT;
}
// END INLINE /lib/color_utils.glsl
#endif

/* Uniforms */

uniform ivec2 eyeBrightnessSmooth;
uniform mat4 dhProjection;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform int isEyeInWater;
uniform float light_mix;
uniform float far;
uniform float rainStrength;
uniform mat4 gbufferProjectionInverse;

#ifdef DISTANT_HORIZONS
    uniform int dhRenderDistance;
#endif

#ifdef UNKNOWN_DIM
    uniform sampler2D lightmap;
#endif

#if defined IS_IRIS && defined THE_END && MC_VERSION >= 12109
    uniform float endFlashIntensity;
#endif

/* Ins / Outs */

varying vec2 texcoord;
varying vec4 tint_color;
varying vec3 direct_light_color;
varying vec3 candle_color;
varying float direct_light_strength;
varying vec3 omni_light;
varying vec4 position;
varying vec3 fragposition;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 water_normal;
varying vec3 hi_sky_color;
varying vec3 low_sky_color;
varying vec3 up_vec;
varying float visible_sky;
varying vec2 lmcoord;
varying float block_type;
varying float frog_adjust;

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

// BEGIN INLINE /lib/basic_utils.glsl
/* MakeUp - basic_utils.glsl
Misc utilities.

Javier Garduño - GNU Lesser General Public License v3.0
*/

float square_pow(float x) {
    return x * x;
}

float cube_pow(float x) {
    return x * x * x;
}

float fourth_pow(float x) {
    float temp_2 = x * x;
    return temp_2 * temp_2;
}

float fifth_pow(float x) {
    float temp_2 = x * x;
    return temp_2 * temp_2 * x;
}

float sixth_pow(float x) {
    float temp_2 = x * x;
    return temp_2 * temp_2 * temp_2;
}

vec3 vec3_square_pow(vec3 x) {
    return x * x;
}

vec3 vec3_cube_pow(vec3 x) {
    return x * x * x;
}

vec3 vec3_fourth_pow(vec3 x) {
    vec3 temp_2 = x * x;
    return temp_2 * temp_2;
}

vec3 vec3_fifth_pow(vec3 x) {
    vec3 temp_2 = x * x;
    return temp_2 * temp_2 * x;
}

vec3 vec3_sixth_pow(vec3 x) {
    vec3 temp_2 = x * x;
    return temp_2 * temp_2 * temp_2;
}

vec4 vec4_square_pow(vec4 x) {
    return x * x;
}

vec4 vec4_cube_pow(vec4 x) {
    return x * x * x;
}

vec4 vec4_fourth_pow(vec4 x) {
    return x * x * x * x;
}

vec4 vec3_fifth_pow(vec4 x) {
    vec4 temp_2 = x * x;
    return temp_2 * temp_2 * x;
}

vec4 vec3_sixth_pow(vec4 x) {
    vec4 temp_2 = x * x;
    return temp_2 * temp_2 * temp_2;
}
// END INLINE /lib/basic_utils.glsl
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

// MAIN FUNCTION ------------------

void main() {
    vec2 eye_bright_smooth = vec2(eyeBrightnessSmooth);
    
// BEGIN INLINE /src/basiccoords_vertex_dh.glsl
texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

#ifdef DH_WATER
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy * 1.0323886639676114;
#else
    vec2 lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy * 1.0323886639676114;
#endif
// END INLINE /src/basiccoords_vertex_dh.glsl
// BEGIN INLINE /src/position_vertex_dh.glsl
position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

if(dhMaterialId == DH_BLOCK_WATER) {  // Water
    position.y -= 0.125;
}

gl_Position = dhProjection * gbufferModelView * position;

#if AA_TYPE > 1
    gl_Position.xy += taa_offset * gl_Position.w;
#endif

// Fog intensity calculation
#if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
    float fog_density_coeff = FOG_DENSITY * FOG_ADJUST;
#else
    float fog_density_coeff = day_blend_float(
        FOG_SUNSET,
        FOG_DAY,
        FOG_NIGHT
    ) * FOG_ADJUST;
#endif

gl_FogFragCoord = length(position.xyz);
// END INLINE /src/position_vertex_dh.glsl
// BEGIN INLINE /src/hi_sky.glsl
#ifdef UNKNOWN_DIM
    vec3 hi_sky_color_rgb = skyColor;
    hi_sky_color = rgb_to_xyz(hi_sky_color_rgb);
#else
    vec3 hi_sky_color_rgb = day_blend(
        ZENITH_SUNSET_COLOR,
        ZENITH_DAY_COLOR,
        ZENITH_NIGHT_COLOR
    );

    hi_sky_color_rgb = mix(
        hi_sky_color_rgb,
        ZENITH_SKY_RAIN_COLOR * luma(hi_sky_color_rgb),
        rainStrength
    );

    hi_sky_color = rgb_to_xyz(hi_sky_color_rgb);
#endif
// END INLINE /src/hi_sky.glsl
// BEGIN INLINE /src/low_sky.glsl
#ifdef UNKNOWN_DIM
    vec3 low_sky_color_rgb = fogColor;
    low_sky_color = rgb_to_xyz(low_sky_color_rgb);
#else
    vec3 low_sky_color_rgb = day_blend(
        HORIZON_SUNSET_COLOR,
        HORIZON_DAY_COLOR,
        HORIZON_NIGHT_COLOR
    );

    low_sky_color_rgb = mix(
        low_sky_color_rgb,
        HORIZON_SKY_RAIN_COLOR * luma(low_sky_color_rgb),
        rainStrength
    );

    low_sky_color = rgb_to_xyz(low_sky_color_rgb);
#endif
// END INLINE /src/low_sky.glsl
// BEGIN INLINE /src/light_vertex_dh.glsl
tint_color = gl_Color;

// Luz nativa (lmcoord.x: candela, lmcoord.y: cielo) ----
#if defined THE_END || defined NETHER
    vec2 illumination = vec2(lmcoord.x, 1.0);
#else
    vec2 illumination = lmcoord;
#endif

illumination.y = max(illumination.y - 0.065, 0.0) * 1.06951871657754;
visible_sky = clamp(illumination.y, 0.0, 1.0);

#if defined UNKNOWN_DIM
    visible_sky = (visible_sky * 0.6) + 0.4;
#endif

// Intensidad y color de luz de candelas
float candle_luma = illumination.x * sqrt(illumination.x);
candle_color = CANDLE_BASELIGHT * (candle_luma + sixth_pow(illumination.x * 1.17));
candle_color = clamp(candle_color, vec3(0.0), vec3(4.0));

// Atenuación por dirección de luz directa ===================================
#if defined THE_END || defined NETHER
    vec3 sun_vec = normalize(gbufferModelView * vec4(0.0, 0.89442719, 0.4472136, 0.0)).xyz;
#else
    vec3 sun_vec = normalize(sunPosition);
#endif

vec3 normal = gl_NormalMatrix * gl_Normal;
float sun_light_strength;

// Comprobar la longitud al cuadrado (dot product) es mucho más rápido que la longitud (sqrt).
if (dot(normal, normal) > 0.0001) {  // Workaround for undefined normals
    normal = normalize(normal);
    sun_light_strength = dot(normal, sun_vec);
} else {
    normal = vec3(0.0, 1.0, 0.0);
    sun_light_strength = 1.0;
}

#if defined THE_END || defined NETHER
    direct_light_strength = sun_light_strength;
#else
    direct_light_strength = mix(-sun_light_strength, sun_light_strength, light_mix);
#endif

// Intensidad por dirección
float omni_strength = (direct_light_strength * .125) + 1.0;     

// Calculamos color de luz directa
#ifdef UNKNOWN_DIM
    direct_light_color = texture2D(lightmap, vec2(0.0, lmcoord.y)).rgb;
#else
    direct_light_color = day_blend(LIGHT_SUNSET_COLOR, LIGHT_DAY_COLOR, LIGHT_NIGHT_COLOR);
    #if defined IS_IRIS && defined THE_END && MC_VERSION >= 12109
        direct_light_color += (endFlashIntensity * endFlashIntensity * 0.1);
    #endif
#endif

direct_light_strength = clamp(direct_light_strength, 0.0, 1.0);

#if defined THE_END || defined NETHER
    omni_light = LIGHT_DAY_COLOR;
#else
    direct_light_color = mix(direct_light_color, ZENITH_SKY_RAIN_COLOR * luma(direct_light_color) * 0.4, rainStrength);

    // Minimal light
    vec3 omni_color = mix(hi_sky_color_rgb, direct_light_color * 0.45, OMNI_TINT);
    float omni_color_luma = color_average(omni_color);
    
    // --- OPTIMIZACIÓN #3: Prevenir división por cero ---
    float luma_ratio = AVOID_DARK_LEVEL / max(omni_color_luma, 0.0001);
    
    vec3 omni_color_min = omni_color * luma_ratio;
    omni_color = max(omni_color, omni_color_min);
    
    omni_light = mix(omni_color_min, omni_color, visible_sky);
#endif

if (isEyeInWater == 0) {
    // Reemplazar pow(x, 10.0) con multiplicaciones ---
    // Esto es órdenes de magnitud más rápido. x^10 = (x^2)^2 * x^2
    float vis_sky_2 = visible_sky * visible_sky;     // x^2
    float vis_sky_4 = vis_sky_2 * vis_sky_2;       // x^4
    float vis_sky_8 = vis_sky_4 * vis_sky_4;       // x^8
    float vis_sky_10 = vis_sky_8 * vis_sky_2;      // x^10
    direct_light_strength = mix(0.0, direct_light_strength, vis_sky_10);
} else {
    direct_light_strength = mix(0.0, direct_light_strength, visible_sky);
}

if (dhMaterialId == DH_BLOCK_ILLUMINATED) {
    direct_light_strength = 10.0;
} else if (dhMaterialId == DH_BLOCK_LAVA) {
    direct_light_strength = 1.0;
}
// END INLINE /src/light_vertex_dh.glsl
// BEGIN INLINE /src/fog_vertex_dh.glsl
#if !defined THE_END && !defined NETHER
    float fog_intensity_coeff = max(eye_bright_smooth.y * 0.004166666666666667, visible_sky);
    frog_adjust = pow(
        clamp(gl_FogFragCoord / dhRenderDistance, 0.0, 1.0) * fog_intensity_coeff,
        mix(fog_density_coeff * 0.15, 0.5, rainStrength)
    );
#else
    frog_adjust = sqrt(clamp(gl_FogFragCoord / dhRenderDistance, 0.0, 1.0));
#endif
// END INLINE /src/fog_vertex_dh.glsl

    vec4 position2 = gl_ModelViewMatrix * gl_Vertex;
    fragposition = position2.xyz;

    binormal = normalize(gbufferModelView[2].xyz);
    tangent = normalize(gbufferModelView[0].xyz);
    water_normal = normal;

    up_vec = normalize(gbufferModelView[1].xyz);

    if(dhMaterialId == DH_BLOCK_WATER) {  // Water
        block_type = float(DH_BLOCK_WATER);
    }
}
// END INLINE /common/solid_dh_water_vertex.glsl
