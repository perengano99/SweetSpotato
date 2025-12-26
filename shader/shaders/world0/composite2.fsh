#version 120
/* MakeUp - composite1.fsh
Render: Antialiasing and motion blur

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define COMPOSITE2_SHADER
#define NO_SHADOWS

// BEGIN INLINE /common/composite2_fragment.glsl
#include "/lib/config.glsl"

#if MC_VERSION < 11300
    const bool colortex0Clear = false;
    const bool colortex1Clear = false;
    const bool colortex2Clear = false;
    const bool colortex3Clear = false;
    const bool gaux1Clear = false;
    const bool gaux2Clear = false;
    const bool gaux3Clear = false;
    const bool gaux4Clear = false;
#endif

/* Uniforms */

uniform sampler2D colortex1;

#if AA_TYPE > 0 || defined MOTION_BLUR
    uniform sampler2D colortex3;  // TAA past averages
    uniform float pixel_size_x;
    uniform float pixel_size_y;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferProjection;
    uniform mat4 gbufferModelViewInverse;
    uniform vec3 cameraPosition;
    uniform vec3 previousCameraPosition;
    uniform mat4 gbufferPreviousProjection;
    uniform mat4 gbufferPreviousModelView;
    uniform sampler2D depthtex1;
    uniform float frameTime;
#endif

/* Ins / Outs */

varying vec2 texcoord;

/* Utility functions */

#if AA_TYPE > 0 || defined MOTION_BLUR
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
#endif

#ifdef MOTION_BLUR
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
// BEGIN INLINE /lib/motion_blur.glsl
/* MakeUp - motion_blur.glsl
Motion blur functions.

Javier Garduño - GNU Lesser General Public License v3.0
*/

vec3 motion_blur(vec3 color, float the_depth, vec2 blur_velocity, sampler2D image) {
    if (the_depth > 0.7) {  // No hand
        vec2 double_pixels = 2.0 * vec2(pixel_size_x, pixel_size_y);
        vec3 m_blur = vec3(0.0);

        blur_velocity =
            (MOTION_BLUR_STRENGTH * blur_velocity) / ((1.0 + length(blur_velocity)) * (frameTime * 500.0)) ;

        #if AA_TYPE > 0
        vec2 coord =
            texcoord - blur_velocity * (1.5 + shifted_r_dither(gl_FragCoord.xy));
        #else
        vec2 coord =
            texcoord - blur_velocity * (1.5 + eclectic_r_dither(gl_FragCoord.xy));
        #endif

        float weight = 0.0;
        float mask;
        vec2 sample_coord;
        vec3 b_sample;
        for(int i = 0; i < MOTION_BLUR_SAMPLES; i++, coord += blur_velocity) {
            sample_coord = clamp(coord, double_pixels, 1.0 - double_pixels);
            b_sample = texture2DLod(image, sample_coord, 0.0).rgb;
            m_blur += b_sample;
            weight++;
        }
        m_blur /= max(weight, 1.0);

        return m_blur;
    } else {
        return color.rgb;
    }
}
// END INLINE /lib/motion_blur.glsl
#endif

#if AA_TYPE > 0
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
// BEGIN INLINE /lib/fast_taa.glsl
/* MakeUp - fast_taa.glsl
Temporal antialiasing functions.

Javier Garduño - GNU Lesser General Public License v3.0
*/

// vec3 selective_blur(vec3 neighborhood[9], float hueThreshold) {
//     // El píxel central está en el índice 4
//     vec3 centerColor = neighborhood[4];
//     vec3 centerHSV = rgb2hsv(centerColor);

//     vec3 accumulatedColor = centerColor;
//     float count = 1.0;

//     // Itera sobre todo el array de vecinos
//     for (int i = 0; i < 9; i++) {
//         // Salta el píxel central, ya que ya está incluido
//         if (i == 4) {
//             continue;
//         }

//         vec3 neighborColor = neighborhood[i];
//         vec3 neighborHSV = rgb2hsv(neighborColor);

//         // Compara la diferencia de tono
//         float hueDiff = abs(centerHSV.x - neighborHSV.x);

//         // Considera la naturaleza cíclica del tono
//         if (hueDiff > 0.5) {
//             hueDiff = 1.0 - hueDiff;
//         }

//         if (hueDiff <= hueThreshold) {
//             accumulatedColor += neighborColor;
//             count++;
//         }
//     }

//     return accumulatedColor / count;
// }

vec4 convex_hull(
    vec3 c, vec3 previous, vec3 up, vec3 down, vec3 left, vec3 right, 
    vec3 ul, vec3 ur, vec3 dl, vec3 dr) {

    // Cálculo de varianza
    vec3 sum = c + up + down + left + right + ul + ur + dl + dr;
    vec3 sum_sq =
        c*c +
        up*up +
        down*down +
        left*left +
        right*right +
        ul*ul +
        ur*ur +
        dl*dl +
        dr*dr;

    vec3 mean = sum * 0.1111111111111111; // 1 / 9
    vec3 variance = abs(sum_sq * 0.1111111111111111 - mean * mean); // Varianza = E[x^2] - E[x]^2

    // 2. Definir el rango de clamping
    vec3 std_dev = sqrt(variance);
    vec3 min_valid = mean - std_dev;
    vec3 max_valid = mean + std_dev;

    // 3. Aplicar el clamping
    return vec4(clamp(previous, min_valid, max_valid), distance(min_valid, max_valid));

    // Clip 2
    // float radio = length(max_valid - mean);

    // vec3 color_vector = previous - mean;
    // float color_dist = length(color_vector);

    // float factor = 1.0;
    // if (color_dist > radio) {
    //     factor = (radio / color_dist);
    // }
    // previous = mean + (color_vector * factor);

    // return vec4(previous, distance(min_valid, max_valid));
}

// float edge_detector(
//     vec3 c, vec3 up, vec3 down, vec3 left, vec3 right, 
//     vec3 ul, vec3 ur, vec3 dl, vec3 dr) {
//     // --- Parámetros de Control Relativos ---
//     const float epsilon = 0.0001;
//     const float relative_threshold = 0.4;
//     const float smoothness = 0.5;

//     // --- Conversión a Luminancia ---
//     float l_c = luma(c);
//     float l_up = luma(up);
//     float l_down = luma(down);
//     float l_left = luma(left);
//     float l_right = luma(right);
//     float l_ul = luma(ul);
//     float l_ur = luma(ur);
//     float l_dl = luma(dl);
//     float l_dr = luma(dr);

//     // --- Optimización: Calcular diferencias de luminancia una sola vez ---
//     float d_up = abs(l_c - l_up);
//     float d_down = abs(l_c - l_down);
//     float d_left = abs(l_c - l_left);
//     float d_right = abs(l_c - l_right);
//     float d_ul = abs(l_c - l_ul);
//     float d_ur = abs(l_c - l_ur);
//     float d_dl = abs(l_c - l_dl);
//     float d_dr = abs(l_c - l_dr);
    
//     // --- Optimización: Pre-calcular el inverso para los cálculos de consistencia ---
//     // Esto reemplaza 4 divisiones por 1 división y 4 multiplicaciones.
//     float inv_l_c = 1.0 / (l_c + epsilon);

//     // --- Cálculo de "Linealidad" Relativa de forma eficiente ---

//     // 1. Línea Horizontal
//     // ridge_h utiliza las diferencias perpendiculares (arriba, abajo).
//     // La consistencia se mide con las diferencias paralelas (izquierda, derecha).
//     float ridge_h = d_up / (l_up + epsilon) + d_down / (l_down + epsilon);
//     float lineness_h = ridge_h - (d_left + d_right) * inv_l_c;

//     // 2. Línea Vertical
//     float ridge_v = d_left / (l_left + epsilon) + d_right / (l_right + epsilon);
//     float lineness_v = ridge_v - (d_up + d_down) * inv_l_c;

//     // 3. Línea Diagonal (Top-Left a Bottom-Right)
//     float ridge_d1 = d_ur / (l_ur + epsilon) + d_dl / (l_dl + epsilon);
//     float lineness_d1 = ridge_d1 - (d_ul + d_dr) * inv_l_c;

//     // 4. Línea Diagonal (Top-Right a Bottom-Left)
//     float ridge_d2 = d_ul / (l_ul + epsilon) + d_dr / (l_dr + epsilon);
//     float lineness_d2 = ridge_d2 - (d_ur + d_dl) * inv_l_c;
    
//     // --- Puntuación final y color de salida (sin cambios) ---
    
//     // Se toma la máxima puntuación de las 4 direcciones (asegurando que no sea negativa).
//     float max_lineness = max(0.0, max(lineness_h, max(lineness_v, max(lineness_d1, lineness_d2))));

//     // `smoothstep` ahora usa los umbrales relativos.
//     return smoothstep(relative_threshold, relative_threshold + smoothness, max_lineness);
// }

// float fast_edge_detector(vec3 current_color, vec3 left, vec3 right, vec3 up, vec3 down) {
//     vec3 edge_color = -left;
//     edge_color -= right;
//     edge_color += current_color * 4.0;
//     edge_color -= down;
//     edge_color -= up;
//     edge_color = edge_color / (current_color * 2.0);
    
//     float edge = clamp(length(edge_color) * 0.5773502691896258, 0.0, 1.0);  // 1/sqrt(3)
//     return smoothstep(0.25, 0.75, edge);
// }

vec3 fast_taa(vec3 current_color, vec2 texcoord_past) {
    // Verificamos si proyección queda fuera de la pantalla actual
    if (clamp(texcoord_past, 0.0, 1.0) != texcoord_past) {
        return current_color;
    } else {
        // Previous color
        vec3 previous = texture2DLod(colortex3, texcoord_past, 0.0).rgb;

        vec3 left = texture2DLod(colortex1, texcoord + vec2(-pixel_size_x, 0.0), 0.0).rgb;
        vec3 right = texture2DLod(colortex1, texcoord + vec2(pixel_size_x, 0.0), 0.0).rgb;
        vec3 down = texture2DLod(colortex1, texcoord + vec2(0.0, -pixel_size_y), 0.0).rgb;
        vec3 up = texture2DLod(colortex1, texcoord + vec2(0.0, pixel_size_y), 0.0).rgb;
        vec3 ul = texture2DLod(colortex1, texcoord + vec2(-pixel_size_x, pixel_size_y), 0.0).rgb;
        vec3 ur = texture2DLod(colortex1, texcoord + vec2(pixel_size_x, pixel_size_y), 0.0).rgb;
        vec3 dl = texture2DLod(colortex1, texcoord + vec2(-pixel_size_x, -pixel_size_y), 0.0).rgb;
        vec3 dr = texture2DLod(colortex1, texcoord + vec2(pixel_size_x, -pixel_size_y), 0.0).rgb;

        vec3 c_max = max(max(max(left, right), down),max(up, max(ul, max(ur, max(dl, max(dr, current_color))))));
	    vec3 c_min = min(min(min(left, right), down),min(up, min(ul, min(ur, min(dl, min(dr, current_color))))));

        // float edge = edge_detector(
        //     current_color,
        //     up,
        //     down,
        //     left,
        //     right,
        //     ul,
        //     ur,
        //     dl,
        //     dr
        // );

        // Clip 1
        // previous = clamp(previous, nmin, nmax);

        // Clip 2
        // vec3 center = (c_min + c_max) * 0.5;
        // float radio = length(nmax - center);

        // vec3 color_vector = previous - center;
        // float color_dist = length(color_vector);

        // float factor = 1.0;
        // if (color_dist > radio) {
        //     factor = (radio / color_dist);
        // }
        // previous = center + (color_vector * factor);

        // Clip 3
        vec4 previous_cliped = convex_hull(
            current_color,
            previous,
            up,
            down,
            left,
            right,
            ul,
            ur,
            dl,
            dr
        );

        float ponderation = clamp((distance(c_max, c_min) - previous_cliped.a) / previous_cliped.a, 0.0, 1.0);
        return mix(current_color, previous_cliped.rgb, 0.99 - (smoothstep(0.0, 1.0, ponderation) * 0.44));
    }
}

vec4 fast_taa_depth(vec4 current_color, vec2 texcoord_past) {
    // Verificamos si proyección queda fuera de la pantalla actual
    if (clamp(texcoord_past, 0.0, 1.0) != texcoord_past) {
        return current_color;
    } else {
        // Muestra del pasado
        vec4 previous = texture2DLod(colortex3, texcoord_past, 0.0);

        vec4 left = texture2DLod(colortex1, texcoord + vec2(-pixel_size_x, 0.0), 0.0);
        vec4 right = texture2DLod(colortex1, texcoord + vec2(pixel_size_x, 0.0), 0.0);
        vec4 down = texture2DLod(colortex1, texcoord + vec2(0.0, -pixel_size_y), 0.0);
        vec4 up = texture2DLod(colortex1, texcoord + vec2(0.0, pixel_size_y), 0.0);
        vec4 ul = texture2DLod(colortex1, texcoord + vec2(-pixel_size_x, pixel_size_y), 0.0);
        vec4 ur = texture2DLod(colortex1, texcoord + vec2(pixel_size_x, pixel_size_y), 0.0);
        vec4 dl = texture2DLod(colortex1, texcoord + vec2(-pixel_size_x, -pixel_size_y), 0.0);
        vec4 dr = texture2DLod(colortex1, texcoord + vec2(pixel_size_x, -pixel_size_y), 0.0);

        vec3 c_max = max(max(max(left.rgb, right.rgb), down.rgb),max(up.rgb, max(ul.rgb, max(ur.rgb, max(dl.rgb, max(dr.rgb, current_color.rgb))))));
	    vec3 c_min = min(min(min(left.rgb, right.rgb), down.rgb),min(up.rgb, min(ul.rgb, min(ur.rgb, min(dl.rgb, min(dr.rgb, current_color.rgb))))));

        // Clip 3
        vec4 previous_cliped = convex_hull(
            current_color.rgb,
            previous.rgb,
            up.rgb,
            down.rgb,
            left.rgb,
            right.rgb,
            ul.rgb,
            ur.rgb,
            dl.rgb,
            dr.rgb
        );

        float ponderation = clamp((distance(c_max, c_min) - previous_cliped.a) / previous_cliped.a, 0.0, 1.0);
        return mix(current_color, vec4(previous_cliped.rgb, previous.a), 0.99 - (smoothstep(0.0, 1.0, ponderation) * 0.39));
    }
}
// END INLINE /lib/fast_taa.glsl
#endif

// MAIN FUNCTION ------------------

void main() {
    vec4 block_color = texture2DLod(colortex1, texcoord, 0);

    // Precalc past position and velocity
    #if AA_TYPE > 0 || defined MOTION_BLUR
        // Retrojection of previous frame
        float z_depth = texture2DLod(depthtex1, texcoord, 0).r;
        vec2 texcoord_past;
        vec3 curr_view_pos;
        vec3 curr_feet_player_pos;
        vec3 prev_feet_player_pos;
        vec3 prev_view_pos;
        vec2 final_pos;

        if(z_depth < 0.56) {
            texcoord_past = texcoord;
        } else {
            curr_view_pos =
                vec3(vec2(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y) * (texcoord * 2.0 - 1.0) + gbufferProjectionInverse[3].xy, gbufferProjectionInverse[3].z);
            curr_view_pos /= (gbufferProjectionInverse[2].w * (z_depth * 2.0 - 1.0) + gbufferProjectionInverse[3].w);
            curr_feet_player_pos = mat3(gbufferModelViewInverse) * curr_view_pos + gbufferModelViewInverse[3].xyz;

            prev_feet_player_pos =
                z_depth > 0.56 ? curr_feet_player_pos + cameraPosition - previousCameraPosition : curr_feet_player_pos;
            prev_view_pos = mat3(gbufferPreviousModelView) * prev_feet_player_pos + gbufferPreviousModelView[3].xyz;
            final_pos =
                vec2(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y) * prev_view_pos.xy + gbufferPreviousProjection[3].xy;
            texcoord_past = (final_pos / -prev_view_pos.z) * 0.5 + 0.5;
        }

    #endif

    #ifdef MOTION_BLUR
        // "Speed"
        vec2 velocity = texcoord - texcoord_past;
        block_color.rgb = motion_blur(block_color.rgb, z_depth, velocity, colortex1);
    #endif

    #if AA_TYPE > 0
        #ifdef DOF
            block_color = fast_taa_depth(block_color, texcoord_past);
        #else
            block_color.rgb = fast_taa(block_color.rgb, texcoord_past);
        #endif

        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        /* DRAWBUFFERS:13 */
        gl_FragData[0] = block_color;  // colortex1
        gl_FragData[1] = block_color;  // To TAA averages
    #else
        block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
        /* DRAWBUFFERS:1 */
        gl_FragData[0] = block_color;  // colortex1
    #endif
}
// END INLINE /common/composite2_fragment.glsl
