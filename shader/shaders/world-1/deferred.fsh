#version 120
/* MakeUp - deferred.fsh
Render: Ambient occlusion, volumetric clouds

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define NETHER
#define DEFERRED_SHADER
#define NO_SHADOWS
#define NO_CLOUDY_SKY

// BEGIN INLINE /common/deferred_fragment.glsl
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

uniform sampler2D colortex1;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform sampler2D depthtex0;
uniform float far;
uniform float near;
uniform float blindness;
uniform float rainStrength;
uniform sampler2D gaux3;
uniform int frameCounter;

#if V_CLOUDS != 0
    uniform sampler2D gaux2;
#endif

#ifdef NETHER
    uniform vec3 fogColor;
#endif

#if AO == 1
    uniform float inv_aspect_ratio;
    uniform float fov_y_inv;
#endif

#if V_CLOUDS != 0 && !defined UNKNOWN_DIM
    uniform sampler2D noisetex;
    uniform vec3 cameraPosition;
    uniform vec3 sunPosition;

    #if defined DISTANT_HORIZONS
        uniform sampler2D dhDepthTex0;
        uniform float dhNearPlane;
        uniform float dhFarPlane;
        uniform float viewWidth;
        uniform float viewHeight;
    #endif
#endif

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float pixel_size_x;
uniform float pixel_size_y;

#if AO == 1 || (V_CLOUDS != 0 && !defined UNKNOWN_DIM)
    uniform mat4 gbufferProjection;
    uniform float frameTimeCounter;
    uniform sampler2D colortex2;
#endif

/* Ins / Outs */

varying vec2 texcoord;
varying vec3 up_vec;  // Flat

#if (V_CLOUDS != 0 && !defined UNKNOWN_DIM) && !defined NO_CLOUDY_SKY
    varying float umbral;
    varying vec3 cloud_color;
    varying vec3 dark_cloud_color;
#endif

#if AO == 1
    varying float fog_density_coeff;
#endif

/* Utility functions */ 

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

#ifdef DISTANT_HORIZONS
// BEGIN INLINE /lib/depth_dh.glsl
/* MakeUp - depth_hd.glsl
Depth utilities (dh).

Javier Garduño - GNU Lesser General Public License v3.0
*/

float ld_dh(float depth) {
    return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - depth * (dhFarPlane - dhNearPlane));
}
// END INLINE /lib/depth_dh.glsl
#endif

#if AO == 1 || (V_CLOUDS != 0 && !defined UNKNOWN_DIM)
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

#if AO == 1
// BEGIN INLINE /lib/ao.glsl
/* MakeUp - ao.glsl
Based on old Capt Tatsu's ambient occlusion functions.

*/

float dbao(float dither) {
    float ao = 0.0;

    float inv_steps = 1.0 / AOSTEPS;
    vec2 offset;
    float n;
    float dither_x;

    float d = texture2DLod(depthtex0, texcoord.xy, 0.0).r;
    float hand_check = d < 0.56 ? 1024.0 : 1.0;
    d = ld(d);

    float sd = 0.0;
    float angle = 0.0;
    float dist = 0.0;
    float far_and_check = hand_check * 2.0 * far;
    vec2 scale = vec2(inv_aspect_ratio, 1.0) * (fov_y_inv / (d * far));
    vec2 scale_factor = scale * inv_steps;
    float sample_d;

    for (int i = 0; i < AOSTEPS; i++) {
        dither_x = (i + dither);
        n = fract(dither_x * 1.6180339887) * 3.141592653589793;
        offset = vec2(cos(n), sin(n)) * dither_x * scale_factor;

        sd = ld(texture2DLod(depthtex0, texcoord.xy + offset, 0.0).r);
        sample_d = (d - sd) * far_and_check;
        angle = clamp(0.5 - sample_d, 0.0, 1.0);
        dist = clamp(0.25 * sample_d - 1.0, 0.0, 1.0);

        sd = ld(texture2DLod(depthtex0, texcoord.xy - offset, 0.0).r);
        sample_d = (d - sd) * far_and_check;
        angle += clamp(0.5 - sample_d, 0.0, 1.0);
        dist += clamp(0.25 * sample_d - 1.0, 0.0, 1.0);

        ao += clamp(angle + dist, 0.0, 1.0);
    }
    ao /= AOSTEPS;

    return sqrt((ao * AO_STRENGTH) + (1.0 - AO_STRENGTH));
}
// END INLINE /lib/ao.glsl
#endif

#if (V_CLOUDS != 0 && !defined UNKNOWN_DIM)
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

    #ifdef THE_END
// BEGIN INLINE /lib/volumetric_clouds_end.glsl
/* MakeUp - volumetric_clouds_end.glsl
Fast volumetric clouds (for The End) - MakeUp implementation
*/

vec3 get_end_cloud(vec3 view_vector, vec3 block_color, float bright, float dither, vec3 base_pos, int samples) {
    block_color.rgb *= clamp(bright + ((dither - .5) * .1), 0.0, 1.0) * .3 + 1.0;

    #if defined DISTANT_HORIZONS && defined DEFERRED_SHADER
        float d_dh = texture2DLod(dhDepthTex0, gl_FragCoord.xy / vec2(viewWidth, viewHeight), 0.0).r;
        float linear_d_dh = ld_dh(d_dh);
        if (linear_d_dh < 0.9999) {
            return block_color;
        }
    #endif

    if (view_vector.y > 0.0) {  // Vista sobre el horizonte
        float umbral = 0.25;
        vec3 cloud_color = block_color * 1.75;
        vec3 dark_cloud_color = block_color * 0.9;

        float view_y_inv = 1.0 / view_vector.y;

        float plane_distance_inf = (CLOUD_PLANE - base_pos.y) * view_y_inv;
        vec3 intersection_pos = (view_vector * plane_distance_inf) + base_pos;

        float plane_distance_sup = (CLOUD_PLANE_SUP - base_pos.y) * view_y_inv;
        vec3 intersection_pos_sup = (view_vector * plane_distance_sup) + base_pos;

        vec3 increment = (intersection_pos_sup - intersection_pos) / samples;
        float increment_dist = length(increment);

        float dif_sup = CLOUD_PLANE_SUP - CLOUD_PLANE_CENTER;
        float dif_inf = CLOUD_PLANE_CENTER - CLOUD_PLANE;
        float dist_aux_coeff = (CLOUD_PLANE_SUP - CLOUD_PLANE) * 0.075;
        float dist_aux_coeff_blur = dist_aux_coeff * 0.4;
        float opacity_dist = dist_aux_coeff * 2.5 * view_y_inv;

        float cloud_value = 0.0;
        float density = 0.0; // Inicializar
        bool first_contact = true;

        intersection_pos += (increment * dither);

        for (int i = 0; i < samples; i++) {
            float current_value = texture2D(gaux2, (intersection_pos.xz * .0008) + (frameTimeCounter * CLOUD_HI_FACTOR * 3.0)).r;

            #if V_CLOUDS == 2 && CLOUD_VOL_STYLE == 0
                current_value += texture2D(gaux2, (intersection_pos.zx * .0008) + (frameTimeCounter * CLOUD_LOW_FACTOR * 3.0)).r;
                current_value = smoothstep(0.05, 0.95, current_value * 0.5);
            #endif

            current_value = (current_value - umbral) / (1.0 - umbral);

            float surface_inf = CLOUD_PLANE_CENTER - (current_value * dif_inf);
            float surface_sup = CLOUD_PLANE_CENTER + (current_value * dif_sup);

            // --- OPTIMIZACIÓN: Reestructurar la lógica del bucle ---
            float current_opacity = 0.0;
            float cloud_thickness = surface_sup - surface_inf;

            if (intersection_pos.y > surface_inf && intersection_pos.y < surface_sup) {
                // Dentro de la nube
                current_opacity = min(increment_dist, cloud_thickness);
            }
            else if (cloud_thickness > 0.0 && i > 0) {
                // Cerca del borde de la nube (desenfoque)
                float distance_aux = min(abs(intersection_pos.y - surface_inf), abs(intersection_pos.y - surface_sup));
                if (distance_aux < dist_aux_coeff_blur) {
                    // El cálculo original se simplifica a esto, que es más rápido.
                    float blur_factor = 1.0 - (distance_aux / dist_aux_coeff_blur);
                    current_opacity = min(blur_factor * increment_dist, cloud_thickness);
                }
            }
            
            // La lógica de acumulación y primer contacto se gestiona UNA SOLA VEZ.
            if (current_opacity > 0.0) {
                cloud_value += current_opacity;
                if (first_contact) {
                    first_contact = false;
                    density = (surface_sup - intersection_pos.y) / (CLOUD_PLANE_SUP - CLOUD_PLANE);
                }
            }

            intersection_pos += increment;
        }

        cloud_value = clamp(cloud_value / opacity_dist, 0.0, 1.0);
        density = clamp(density, 0.0001, 1.0);

        cloud_color = mix(cloud_color, dark_cloud_color, sqrt(density));
        cloud_color = mix(cloud_color, cloud_color * 2.0, (1.0 - cloud_value) * bright);

        block_color = mix(block_color, cloud_color, cloud_value * clamp((view_vector.y - 0.06) * 5.0, 0.0, 1.0));
        block_color = mix(block_color, vec3(1.0), clamp(bright * .04, 0.0, 1.0));
    }

    return block_color;
}
// END INLINE /lib/volumetric_clouds_end.glsl
    #else
// BEGIN INLINE /lib/volumetric_clouds.glsl
/* MakeUp - volumetric_clouds.glsl
Fast volumetric clouds - MakeUp implementation
*/

vec3 get_cloud_old(vec3 view_vector, vec3 block_color, float bright, float dither, vec3 base_pos, int samples, float umbral, vec3 cloud_color, vec3 dark_cloud_color) {
    float plane_distance;
    float cloud_value;
    float density;
    vec3 intersection_pos;
    vec3 intersection_pos_sup;
    float dif_inf;
    float dif_sup;
    float dist_aux_coeff;
    float current_value;
    float surface_inf;
    float surface_sup;
    bool first_contact = true;
    float opacity_dist;
    vec3 increment;
    float increment_dist;
    float view_y_inv = 1.0 / view_vector.y;
    float distance_aux;
    float dist_aux_coeff_blur;

    #if VOL_LIGHT == 0
        block_color.rgb *=
            clamp(bright + ((dither - .5) * .1), 0.0, 1.0) * .3 + 1.0;
    #endif

    #if defined DISTANT_HORIZONS && defined DEFERRED_SHADER
        float d_dh = texture2D(dhDepthTex0, vec2(gl_FragCoord.x / viewWidth, gl_FragCoord.y / viewHeight)).r;
        float linear_d_dh = ld_dh(d_dh);
        if (linear_d_dh < 0.9999) {
            return block_color;
        }
    #endif

    if (view_vector.y > 0.0) {  // Over horizon
        plane_distance = (CLOUD_PLANE - base_pos.y) * view_y_inv;
        intersection_pos = (view_vector * plane_distance) + base_pos;

        plane_distance = (CLOUD_PLANE_SUP - base_pos.y) * view_y_inv;
        intersection_pos_sup = (view_vector * plane_distance) + base_pos;

        dif_sup = CLOUD_PLANE_SUP - CLOUD_PLANE_CENTER;
        dif_inf = CLOUD_PLANE_CENTER - CLOUD_PLANE;
        dist_aux_coeff = (CLOUD_PLANE_SUP - CLOUD_PLANE) * 0.075;
        dist_aux_coeff_blur = dist_aux_coeff * 0.3;

        opacity_dist = dist_aux_coeff * 2.0 * view_y_inv;

        increment = (intersection_pos_sup - intersection_pos) / samples;
        increment_dist = length(increment);

        cloud_value = 0.0;

        intersection_pos += (increment * dither);

        for (int i = 0; i < samples; i++) {
            current_value =
                texture2D(
                    gaux2,
                    (intersection_pos.xz * 0.0002777777777777778) + (frameTimeCounter * CLOUD_HI_FACTOR)
                ).r;


            #if V_CLOUDS == 2 && CLOUD_VOL_STYLE == 0
                current_value +=
                    texture2D(
                        gaux2,
                        (intersection_pos.zx * 0.0002777777777777778) + (frameTimeCounter * CLOUD_LOW_FACTOR)
                    ).r;

                current_value *= 0.5;
                current_value = smoothstep(0.05, 0.95, current_value);

            #endif

            // Ajuste por umbral
            current_value = (current_value - umbral) / (1.0 - umbral);

            // Superficies inferior y superior de nubes
            surface_inf = CLOUD_PLANE_CENTER - (current_value * dif_inf);
            surface_sup = CLOUD_PLANE_CENTER + (current_value * dif_sup);

            if (  // Dentro de la nube
                intersection_pos.y > surface_inf &&
                intersection_pos.y < surface_sup
                ) {
                    cloud_value += min(increment_dist, surface_sup - surface_inf);

                    if (first_contact) {
                        first_contact = false;
                        density =
                        (surface_sup - intersection_pos.y) /
                        (CLOUD_PLANE_SUP - CLOUD_PLANE);
                    }
            }
            else if (surface_inf < surface_sup && i > 0) {  // Fuera de la nube
                distance_aux = min(
                    abs(intersection_pos.y - surface_inf),
                    abs(intersection_pos.y - surface_sup)
                );

                if (distance_aux < dist_aux_coeff_blur) {
                    cloud_value += min(
                        (clamp(dist_aux_coeff_blur - distance_aux, 0.0, dist_aux_coeff_blur) / dist_aux_coeff_blur) * increment_dist,
                        surface_sup - surface_inf
                    );

                    if (first_contact) {
                        first_contact = false;
                        density =
                        (surface_sup - intersection_pos.y) /
                        (CLOUD_PLANE_SUP - CLOUD_PLANE);
                    }
                }
            }

            intersection_pos += increment;
        }

        cloud_value = clamp(cloud_value / opacity_dist, 0.0, 1.0);
        density = clamp(density, 0.0001, 1.0);

        float att_factor = mix(1.0, 0.75, bright * (1.0 - rainStrength));

        #if CLOUD_VOL_STYLE == 1
            cloud_color = mix(cloud_color * att_factor, dark_cloud_color * att_factor, pow(density, 0.3) * 0.85);
        #else
            cloud_color = mix(cloud_color * att_factor, dark_cloud_color * att_factor, pow(density, 0.4));
        #endif

        // Halo brillante de contra al sol
        cloud_color =
            mix(cloud_color, cloud_color * 13.0, (1.0 - pow(cloud_value, 0.2)) * bright * bright * (1.0 - rainStrength));

        block_color = mix(
            block_color,
            cloud_color,
            cloud_value * clamp((view_vector.y - 0.06) * 5.0, 0.0, 1.0)
        );
    }

    return block_color;
}

vec3 get_cloud(vec3 view_vector, vec3 block_color, float bright, float dither, vec3 base_pos, int samples, float umbral, vec3 cloud_color, vec3 dark_cloud_color) {
    #if VOL_LIGHT == 0
        block_color.rgb *= clamp(bright + ((dither - .5) * .1), 0.0, 1.0) * .3 + 1.0;
    #endif

    #if defined DISTANT_HORIZONS && defined DEFERRED_SHADER
        float d_dh = texture2D(dhDepthTex0, gl_FragCoord.xy / vec2(viewWidth, viewHeight)).r;
        float linear_d_dh = ld_dh(d_dh);
        if (linear_d_dh < 0.9999) {
            return block_color;
        }
    #endif

    if (view_vector.y > 0.0) {  // Over horizon
        float view_y_inv = 1.0 / view_vector.y;

        float plane_distance_inf = (CLOUD_PLANE - base_pos.y) * view_y_inv;
        vec3 intersection_pos = (view_vector * plane_distance_inf) + base_pos;

        float plane_distance_sup = (CLOUD_PLANE_SUP - base_pos.y) * view_y_inv;
        vec3 intersection_pos_sup = (view_vector * plane_distance_sup) + base_pos;

        float dif_sup = CLOUD_PLANE_SUP - CLOUD_PLANE_CENTER;
        float dif_inf = CLOUD_PLANE_CENTER - CLOUD_PLANE;

        vec3 increment = (intersection_pos_sup - intersection_pos) / samples;

        float increment_dist = length(increment);
        
        float dist_aux_coeff = (CLOUD_PLANE_SUP - CLOUD_PLANE) * 0.075;
        float dist_aux_coeff_blur = dist_aux_coeff * 0.3;
        float opacity_dist = dist_aux_coeff * 2.0 * view_y_inv;

        float cloud_value = 0.0;
        float density = 0.0; // Inicializar
        bool first_contact = true;

        intersection_pos += (increment * dither);

        for (int i = 0; i < samples; i++) {
            float current_value = texture2D(gaux2, (intersection_pos.xz * 0.0002777777777777778) + (frameTimeCounter * CLOUD_HI_FACTOR)).r;

            #if V_CLOUDS == 2 && CLOUD_VOL_STYLE == 0
                current_value += texture2D(gaux2, (intersection_pos.zx * 0.0002777777777777778) + (frameTimeCounter * CLOUD_LOW_FACTOR)).r;
                current_value = smoothstep(0.05, 0.95, current_value * 0.5);
            #endif

            current_value = (current_value - umbral) / (1.0 - umbral);

            float surface_inf = CLOUD_PLANE_CENTER - (current_value * dif_inf);
            float surface_sup = CLOUD_PLANE_CENTER + (current_value * dif_sup);
            
            float current_opacity = 0.0;
            float cloud_thickness = surface_sup - surface_inf;

            if (intersection_pos.y > surface_inf && intersection_pos.y < surface_sup) {
                // Dentro de la nube
                current_opacity = min(increment_dist, cloud_thickness);
            }
            else if (cloud_thickness > 0.0 && i > 0) {
                // Cerca del borde de la nube (desenfoque)
                float distance_aux = min(abs(intersection_pos.y - surface_inf), abs(intersection_pos.y - surface_sup));
                if (distance_aux < dist_aux_coeff_blur) {
                    float blur_factor = 1.0 - (distance_aux / dist_aux_coeff_blur);
                    current_opacity = min(blur_factor * increment_dist, cloud_thickness);
                }
            }

            if (current_opacity > 0.0) {
                cloud_value += current_opacity;
                if (first_contact) {
                    first_contact = false;
                    density = (surface_sup - intersection_pos.y) / (CLOUD_PLANE_SUP - CLOUD_PLANE);
                }
            }
            
            intersection_pos += increment;
        }

        cloud_value = clamp(cloud_value / opacity_dist, 0.0, 1.0);
        density = clamp(density, 0.0001, 1.0);

        float att_factor = mix(1.0, 0.75, bright * (1.0 - rainStrength));

        // --- OPTIMIZACIÓN: Reemplazar pow() por aproximaciones con sqrt() ---
        // pow(x, 0.25) es mucho más rápido y visualmente casi idéntico a pow(x, 0.3) o pow(x, 0.4)
        float density_approx = sqrt(sqrt(density)); // x^0.25
        
        #if CLOUD_VOL_STYLE == 1
            cloud_color = mix(cloud_color * att_factor, dark_cloud_color * att_factor, density_approx * 0.85);
        #else
            cloud_color = mix(cloud_color * att_factor, dark_cloud_color * att_factor, sqrt(density));
        #endif

        float cloud_value_approx = sqrt(sqrt(cloud_value));
        cloud_color = mix(cloud_color, cloud_color * 13.0, (1.0 - cloud_value_approx) * bright * bright * (1.0 - rainStrength));

        block_color = mix(block_color, cloud_color, cloud_value * clamp((view_vector.y - 0.06) * 5.0, 0.0, 1.0));
    }

    return block_color;
}
// END INLINE /lib/volumetric_clouds.glsl
    #endif
#endif

// MAIN FUNCTION ------------------

void main() {
    vec4 block_color = texture2DLod(colortex1, texcoord, 0);
    float d = texture2DLod(depthtex0, texcoord, 0).r;
    float linear_d = ld(d);

    vec2 eye_bright_smooth = vec2(eyeBrightnessSmooth);

    vec3 view_vector = vec3(1.0);

    #if AO == 1 || (V_CLOUDS != 0 && !defined UNKNOWN_DIM)
        #if AA_TYPE > 0
            float dither = shifted_dither_makeup(gl_FragCoord.xy);
        #else
            float dither = dither_makeup(gl_FragCoord.xy);
        #endif
    #endif

    #if (V_CLOUDS != 0 && !defined UNKNOWN_DIM) && !defined NO_CLOUDY_SKY
        if(linear_d > 0.9999) {  // Only sky
            vec4 world_pos = gbufferModelViewInverse * gbufferProjectionInverse * (vec4(texcoord, 1.0, 1.0) * 2.0 - 1.0);
            view_vector = normalize(world_pos.xyz);

            #ifdef THE_END
                float bright = dot(view_vector, vec3(0.0, 0.89442719, 0.4472136));
                bright = clamp((bright * 2.0) - 1.0, 0.0, 1.0);
                bright *= bright * bright * bright;
            #else
                float bright = dot(view_vector, normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz));
                bright = clamp(bright * bright * bright, 0.0, 1.0);
            #endif

            #ifdef THE_END
                #ifdef END_CLOUDS
                    block_color.rgb = get_end_cloud(view_vector, block_color.rgb, bright, dither, cameraPosition, CLOUD_STEPS_AVG);
                #endif
            #else
                block_color.rgb = get_cloud(view_vector, block_color.rgb, bright, dither, cameraPosition, CLOUD_STEPS_AVG, umbral, cloud_color, dark_cloud_color);
            #endif
        }

    #else
        #if defined NETHER
            #if !defined DISTANT_HORIZONS
                if(linear_d > 0.9999) {  // Only sky
                    block_color = vec4(mix(fogColor * 0.1, vec3(1.0), 0.04), 1.0);
                }
            #endif
        #elif !defined NETHER && !defined THE_END
            if(linear_d > 0.9999 && isEyeInWater == 1) {  // Only sky and water
                vec4 screen_pos = vec4(gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), gl_FragCoord.z, 1.0);
                vec4 fragposition = gbufferProjectionInverse * (screen_pos * 2.0 - 1.0);

                vec4 world_pos = gbufferModelViewInverse * vec4(fragposition.xyz, 0.0);
                view_vector = normalize(world_pos.xyz);
            }
        #endif
    #endif

    #if AO == 1
        // AO distance attenuation
        #if defined NETHER
            if(NETHER_FOG_DISTANCE == 0) {
                linear_d = sqrt(linear_d);
            } else {
                float screen_distance = 2.0 * near * far / (far + near - (2.0 * d - 1.0) * (far - near));
                linear_d = screen_distance / NETHER_SIGHT;
            }
        #endif
        float ao_att =
            pow(clamp(linear_d * 1.6, 0.0, 1.0), mix(fog_density_coeff, 1.0, rainStrength));

        float final_ao = mix(dbao(dither), 1.0, ao_att);
        block_color.rgb *= final_ao;
    #endif

    #if defined THE_END || defined NETHER
        #define NIGHT_CORRECTION 1.0
    #else
        #define NIGHT_CORRECTION day_blend_float(1.0, 1.0, 0.1)
    #endif

    // Underwater sky
    if(isEyeInWater == 1) {
        if(linear_d > 0.9999) {
            block_color.rgb = mix(NIGHT_CORRECTION * WATER_COLOR * ((eye_bright_smooth.y * .8 + 48) * 0.004166666666666667), block_color.rgb, max(clamp(view_vector.y - 0.1, 0.0, 1.0), rainStrength));
        }
    }

    block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
    /* DRAWBUFFERS:14 */
    gl_FragData[0] = vec4(block_color.rgb, d);
    gl_FragData[1] = block_color;
}
// END INLINE /common/deferred_fragment.glsl
