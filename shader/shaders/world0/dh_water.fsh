#version 120
/* MakeUp - dh_water.fsh
Render: DH Water

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define DH_WATER

// BEGIN INLINE /common/solid_dh_water_fragment.glsl
#include "/lib/config.glsl"

/* Color utils */

#ifdef THE_END
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

uniform sampler2D tex;
uniform float pixel_size_x;
uniform float pixel_size_y;
uniform float near;
uniform float far;
uniform sampler2D gaux1;
uniform sampler2D gaux4;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D dhDepthTex1;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform float nightVision;
uniform float rainStrength;
uniform float light_mix;
uniform ivec2 eyeBrightnessSmooth;
uniform float viewWidth;
uniform float viewHeight;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform vec3 cameraPosition;
uniform int dhRenderDistance;

#if V_CLOUDS != 0
    uniform sampler2D gaux2;
#endif

#ifdef NETHER
    uniform vec3 fogColor;
#endif

#if defined SHADOW_CASTING && !defined NETHER
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

// BEGIN INLINE /lib/projection_utils.glsl
/* MakeUp - projection_utils.glsl
Projection generic functions.

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec3 camera_to_screen(vec3 fragpos) {
    vec4 pos  = gbufferProjection * vec4(fragpos, 1.0);
    pos /= pos.w;

    return pos.xyz * 0.5 + 0.5;
}
// END INLINE /lib/projection_utils.glsl
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
// BEGIN INLINE /lib/water_dh.glsl
/* MakeUp - water_dh.glsl
Water reflection and refraction related functions (dh).
*/

#if SUN_REFLECTION == 1
    #if !defined NETHER && !defined THE_END
        float sun_reflection(vec3 fragpos) {
        vec3 astro_pos = worldTime > 12900 ? moonPosition : sunPosition;
        float astro_vector =
            max(dot(normalize(fragpos), normalize(astro_pos)), 0.0);

        return smoothstep(0.995, 1.0, astro_vector) *
            clamp(lmcoord.y, 0.0, 1.0) *
            (1.0 - rainStrength) * 3.0;
        }

    #endif
#endif

vec3 normal_waves_dh(vec3 pos) {
    vec2 wave_2 =
        texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.03125) - (frameTimeCounter * .025)).rg;
    wave_2 = wave_2 - .5;
    vec2 partial_wave = wave_2;
    vec3 final_wave = vec3(partial_wave, WATER_TURBULENCE);

    return normalize(final_wave);
}

vec3 refraction(vec3 fragpos, vec3 color, vec3 refraction) {
    vec2 pos = gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y);

    #if REFRACTION == 1
        pos = pos + refraction.xy * (0.075 / (1.0 + length(fragpos) * 0.4));
    #endif

    float water_absortion;
    if (isEyeInWater == 0) {
        float water_distance =
            2.0 * dhNearPlane * dhFarPlane / (dhFarPlane + dhNearPlane - (2.0 * gl_FragCoord.z - 1.0) * (dhFarPlane - dhNearPlane));

        float earth_distance = texture2D(dhDepthTex1, pos.xy).r;
        earth_distance =
            2.0 * dhNearPlane * dhFarPlane / (dhFarPlane + dhNearPlane - (2.0 * earth_distance - 1.0) * (dhFarPlane - dhNearPlane));

        water_absortion = (earth_distance - water_distance) * 0.5;
        water_absortion *= water_absortion;
        water_absortion = (1.0 / -((water_absortion * WATER_ABSORPTION) + 1.125)) + 1.0;
    } else {
        water_absortion = 0.0;
    }

    return mix(texture2D(gaux1, pos.xy).rgb, color, water_absortion);
}

vec3 get_normals(vec3 bump, vec3 fragpos) {
    float NdotE = abs(dot(water_normal, normalize(fragpos)));

    bump *= vec3(NdotE) + vec3(0.0, 0.0, 1.0 - NdotE);

    mat3 tbn_matrix = mat3(
        tangent.x, binormal.x, water_normal.x,
        tangent.y, binormal.y, water_normal.y,
        tangent.z, binormal.z, water_normal.z
    );

    return normalize(bump * tbn_matrix);
}

vec4 reflection_calc_dh(vec3 fragpos, vec3 normal, vec3 reflected, vec3 infinite_color, float dither) {
    vec3 pos = camera_to_screen(fragpos + reflected * 768.0);

    float border =
        clamp((1.0 - (max(0.0, abs(pos.y - 0.5)) * 2.0)) * 50.0, 0.0, 1.0);

    border = clamp(border - pow(pos.y, 10.0), 0.0, 1.0);

    pos.x = abs(pos.x);
    if (pos.x > 1.0) {
        pos.x = 1.0 - (pos.x - 1.0);
    }

    vec4 final_reflex;
    if (texture2D(depthtex0, pos.xy).r < 0.999) {
        final_reflex = vec4(infinite_color, border);
    } else {
        final_reflex = vec4(texture2D(gaux1, pos.xy).rgb, border);
    }
    return final_reflex;
}

vec3 water_shader_dh(
    vec3 fragpos,
    vec3 normal,
    vec3 color,
    vec3 sky_reflect,
    vec3 reflected,
    float fresnel,
    float visible_sky,
    float dither,
    vec3 light_color
) {
    vec4 reflection = vec4(0.0);
    float infinite = 1.0;

    #if REFLECTION == 1
        reflection =
            reflection_calc_dh(fragpos, normal, reflected, sky_reflect, dither);
    #endif

    reflection.rgb = mix(
        sky_reflect * visible_sky,
        reflection.rgb,
        reflection.a
    );

    #ifdef VANILLA_WATER
        fresnel *= 0.8;
    #endif

    #if SUN_REFLECTION == 1
        #ifndef NETHER
            #ifndef THE_END
                return mix(color, reflection.rgb, fresnel * REFLEX_INDEX) +
                    vec3(sun_reflection(reflect(normalize(fragpos), normal))) * light_color * infinite * visible_sky;          
            #else
                return mix(color, reflection.rgb, fresnel * REFLEX_INDEX);
            #endif
        #else
            return mix(color, reflection.rgb, fresnel * REFLEX_INDEX);
        #endif
    #else
        return mix(color, reflection.rgb, fresnel * REFLEX_INDEX);
    #endif
}
// END INLINE /lib/water_dh.glsl
// BEGIN INLINE /lib/depth.glsl
/* MakeUp - depth_dh.glsl
Depth utilities.

Javier Garduño - GNU Lesser General Public License v3.0
*/

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}
// END INLINE /lib/depth.glsl
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

void main() {
    vec2 eye_bright_smooth = vec2(eyeBrightnessSmooth);
    vec3 real_light;

    #if AA_TYPE > 0 
        float dither = shifted_r_dither(gl_FragCoord.xy);
    #else
        float dither = r_dither(gl_FragCoord.xy);
        // dither = 1.0;
    #endif
    
    // Avoid render unnecessary DH
    float t = far - dhNearPlane;
    float inf = t * TRANSITION_DH_INF;
    float view_dist = length(position.xyz);
    float d = texture2DLod(depthtex0, vec2(gl_FragCoord.x / viewWidth, gl_FragCoord.y / viewHeight), 0.0).r;
    float linear_d = ld(d);

    if(linear_d < 0.9999 || view_dist < dhNearPlane + inf) {
        discard;
        return;
    }

    #ifdef VANILLA_WATER
        vec3 water_normal_base = vec3(0.0, 0.0, 1.0);
    #else
        vec3 world_pos = position.xyz + cameraPosition;
        vec3 water_normal_base = normal_waves_dh(world_pos.xzy);
    #endif

    vec3 surface_normal;
    if(block_type < DH_BLOCK_WATER + 0.5 && block_type > DH_BLOCK_WATER - 0.5) {  // Water
        surface_normal = get_normals(water_normal_base, fragposition);
    } else {
        surface_normal = get_normals(vec3(0.0, 0.0, 1.0), fragposition);
    }

    float normal_dot_eye = dot(surface_normal, normalize(fragposition));
    float fresnel = square_pow(1.0 + normal_dot_eye);

    vec3 reflect_water_vec = reflect(fragposition, surface_normal);
    vec3 norm_reflect_water_vec = normalize(reflect_water_vec);

    vec3 sky_color_reflect;
    if(isEyeInWater == 0 || isEyeInWater == 2) {
        sky_color_reflect = mix(low_sky_color, hi_sky_color, smoothstep(0.0, 1.0, pow(clamp(dot(norm_reflect_water_vec, up_vec), 0.0001, 1.0), 0.333)));
    } else {
        sky_color_reflect = hi_sky_color * .5 * ((eye_bright_smooth.y * .8 + 48) * 0.004166666666666667);
    }

    sky_color_reflect = xyz_to_rgb(sky_color_reflect);

    #if !defined VANILLA_WATER && WATER_TEXTURE == 1
        vec4 block_color = vec4(0.1);
        // Synthetic water texture
        vec3 synth_pos = (position.xyz + cameraPosition) * 8.0;
        synth_pos = floor(synth_pos + 0.01);
        float noise = hash13(synth_pos);
        noise *= noise;
        noise *= noise;
        noise *= noise;
        float synth_noise = (noise * 0.3) + 0.5;
        block_color.rgb += vec3(synth_noise);
    #elif defined VANILLA_WATER
        // Synthetic water texture
        vec3 synth_pos = (position.xyz + cameraPosition) * 8.0;
        synth_pos = floor(synth_pos + 0.01);
        float noise = hash13(synth_pos);
        noise *= noise;
        noise *= noise;
        float synth_noise = (noise * 0.227) + 0.773;
        vec4 block_color = vec4(vec3(synth_noise), tint_color.a);
    #else
        vec4 block_color;
    #endif

    if(block_type < DH_BLOCK_WATER + 0.5 && block_type > DH_BLOCK_WATER - 0.5) {  // Water
    #ifdef VANILLA_WATER
        float shadow_c = abs((light_mix * 2.0) - 1.0);

        float fresnel_tex = luma(block_color.rgb);

        real_light = omni_light +
            (direct_light_strength * shadow_c * direct_light_color) * (1.0 - rainStrength * 0.75) +
            candle_color;

        real_light *= (fresnel_tex * 2.0) - 0.25;

        block_color.rgb *= mix(real_light, vec3(1.0), nightVision * .125) * tint_color.rgb;

        block_color.rgb = water_shader_dh(fragposition, surface_normal, block_color.rgb, sky_color_reflect, norm_reflect_water_vec, fresnel, visible_sky, dither, direct_light_color);

        block_color.a = sqrt(block_color.a);
    #else
        #if WATER_TEXTURE == 1
            float water_texture = luma(block_color.rgb);
        #else
            float water_texture = 1.0;
        #endif

            real_light = omni_light +
                (direct_light_strength * visible_sky * direct_light_color) * (1.0 - rainStrength * 0.75) +
                candle_color;

        #if WATER_COLOR_SOURCE == 0
                block_color.rgb = water_texture * real_light * WATER_COLOR;
        #elif WATER_COLOR_SOURCE == 1
            block_color.rgb = 0.3 * water_texture * real_light * tint_color.rgb;
        #endif

            block_color = vec4(refraction(fragposition, block_color.rgb, water_normal_base), 1.0);

        #if WATER_TEXTURE == 1
            fresnel = clamp(fresnel * (water_texture * water_texture + 0.5), 0.0, 1.0);
        #endif

        block_color.rgb = water_shader_dh(fragposition, surface_normal, block_color.rgb, sky_color_reflect, norm_reflect_water_vec, fresnel, visible_sky, dither, direct_light_color);

    #endif

    } else {  // Otros translúcidos

        block_color = tint_color;

        float shadow_c = abs((light_mix * 2.0) - 1.0);

        real_light = omni_light +
            (direct_light_strength * shadow_c * direct_light_color) * (1.0 - rainStrength * 0.75) +
            candle_color;

        block_color.rgb *= mix(real_light, vec3(1.0), nightVision * .125);
    }

// BEGIN INLINE /src/finalcolor_dh.glsl
#if defined DH_WATER
    if(isEyeInWater == 0) {
        vec3 fog_texture = texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb;
        block_color.rgb = mix(block_color.rgb, fog_texture, frog_adjust);
    }
#elif defined NETHER
    #if NETHER_FOG_DISTANCE == 1
        block_color.rgb = mix(fogColor * 0.1, vec3(1.0), 0.04);
    #else
        block_color.rgb = mix(block_color.rgb, mix(fogColor * 0.1, vec3(1.0), 0.04), frog_adjust);
    #endif
#else
    vec3 fog_texture = texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), 0.0).rgb;
    block_color.rgb = mix(block_color.rgb, fog_texture, frog_adjust);
#endif
// END INLINE /src/finalcolor_dh.glsl
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
// END INLINE /common/solid_dh_water_fragment.glsl
