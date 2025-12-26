#version 120
/* MakeUp - composite1.fsh
Render: Bloom and DoF

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define THE_END
#define COMPOSITE1_SHADER

// BEGIN INLINE /common/composite1_fragment.glsl
#include "/lib/config.glsl"

#ifdef DOF
    const bool colortex1MipmapEnabled = true;
#endif

#ifdef BLOOM
    const bool gaux1MipmapEnabled = true;
#endif

/* Uniforms */

uniform sampler2D colortex1;
uniform sampler2D gaux1;
uniform float inv_aspect_ratio;

#ifdef DOF
    uniform float centerDepthSmooth;
    uniform float pixel_size_x;
    uniform float pixel_size_y;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float fov_y_inv;
#endif

/* Ins / Outs */

varying vec2 texcoord;

// BEGIN INLINE /lib/bloom.glsl
/* MakeUp - bloom.glsl
Bloom functions.

Javier Garduño - GNU Lesser General Public License v3.0
*/

vec3 mipmap_bloom(sampler2D image, vec2 coords, float dither) {
    vec3 blur_sample = vec3(0.0);
    vec2 blur_radius_vec = vec2(0.1 * inv_aspect_ratio, 0.1);

    int sample_c = int(BLOOM_SAMPLES);

    vec2 blur_radios_factor = blur_radius_vec * (1.0 / BLOOM_SAMPLES);
    float n;
    vec2 offset;
    vec2 offset_2;
    float dither_x;

    for(int i = 0; i < sample_c; i++) {
        dither_x = i + dither;
        n = fract(dither_x * 1.6180339887) * 6.283185307179586;
        offset = vec2(cos(n), sin(n)) * dither_x * blur_radios_factor;
        offset_2 = vec2(-offset.y * 1.25, offset.x * 1.25);

        blur_sample += texture2D(image, coords + offset, -1.0).rgb;
        blur_sample += texture2D(image, coords - offset, -1.0).rgb;
        blur_sample += texture2D(image, coords + offset_2, -1.0).rgb;
        blur_sample += texture2D(image, coords - offset_2, -1.0).rgb;
    }

    blur_sample /= (BLOOM_SAMPLES * 4.0);

    return blur_sample;
}
// END INLINE /lib/bloom.glsl

/* Utility functions */

#if defined BLOOM || defined DOF
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

#ifdef DOF
// BEGIN INLINE /lib/blur.glsl
/* MakeUp - blur.glsl
Blur functions.

Javier Garduño - GNU Lesser General Public License v3.0
*/

vec3 noised_blur(vec4 color_depth, sampler2D image, vec2 coords, float force, float dither) {
    vec3 block_color = color_depth.rgb;
    float the_depth = color_depth.a;
    float blur_radius = 0.0;

    if (the_depth > 0.56) {  // Manos no
        blur_radius =
            max(abs(the_depth - centerDepthSmooth) - 0.000075, 0.0) * fov_y_inv;
        blur_radius = blur_radius * inversesqrt(0.1 + blur_radius * blur_radius) * force;
        blur_radius = min(blur_radius, 0.1);
    }

    if (blur_radius > min(pixel_size_x, pixel_size_y)) {
        vec3 blur_sample = vec3(0.0);
        vec2 blur_radius_vec = vec2(blur_radius * inv_aspect_ratio, blur_radius);

        float dither_base = dither;
        dither *= 6.283185307179586;

        float current_radius = (0.25 + dither_base);
        vec2 offset = vec2(cos(dither), sin(dither)) * blur_radius_vec * current_radius;

        blur_sample += texture2D(image, coords + offset, -2.0).rgb;
        blur_sample += texture2D(image, coords - offset, -2.0).rgb;

        block_color = blur_sample * 0.5;
    }

    return block_color;
}
// END INLINE /lib/blur.glsl
#endif

// MAIN FUNCTION ------------------

void main() {
    vec4 block_color = texture2DLod(colortex1, texcoord, 0);

    #if defined BLOOM || defined DOF
        #if AA_TYPE > 0
            float dither = shifted_dither_makeup(gl_FragCoord.xy);
        #else
            float dither = dither_makeup(gl_FragCoord.xy);
        #endif
    #endif

    #ifdef DOF
        block_color.rgb = noised_blur(block_color, colortex1, texcoord, DOF_STRENGTH, dither);
    #endif

    #ifdef BLOOM
        vec3 bloom = mipmap_bloom(gaux1, texcoord, dither);
        block_color.rgb += bloom;
    #endif

    block_color = clamp(block_color, vec4(0.0), vec4(vec3(50.0), 1.0));
    /* DRAWBUFFERS:1 */
    gl_FragData[0] = block_color;
}
// END INLINE /common/composite1_fragment.glsl
