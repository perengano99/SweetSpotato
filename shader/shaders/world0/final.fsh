#version 120
/* MakeUp - final.fsh
Render: Final renderer

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define FINAL_SHADER
#define NO_SHADOWS

// BEGIN INLINE /common/final_fragment.glsl
#include "/lib/config.glsl"

// Do not remove comments. It works!
/*

noisetex - Water normals
colortex0 - Unused
colortex1 - Antialiasing auxiliar
colortex2 - Bluenoise 
colortex3 - TAA Averages history
gaux1 - Screen-Space-Reflection / Bloom auxiliar
gaux2 - Clouds texture
gaux3 - Exposure auxiliar
gaux4 - Fog auxiliar

const int noisetexFormat = RG8;
const int colortex0Format = R8;
*/
#ifdef DOF
/*
const int colortex1Format = RGBA16F;
*/
#else
/*
const int colortex1Format = R11F_G11F_B10F;
*/
#endif
/*
const int colortex2Format = R8;
*/
#ifdef DOF
/*
const int colortex3Format = RGBA16F;
*/
#else
/*
const int colortex3Format = R11F_G11F_B10F;
*/
#endif
/*
const int gaux1Format = R11F_G11F_B10F;
const int gaux2Format = R8;
const int gaux3Format = R16F;
const int gaux4Format = R11F_G11F_B10F;

const int shadowcolor0Format = RGBA8;
*/

// Buffers clear
const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex2Clear = false;
const bool colortex3Clear = false;
const bool gaux1Clear = false;
const bool gaux2Clear = false;
const bool gaux3Clear = false;
const bool gaux4Clear = false;

/* Uniforms */

#ifdef DEBUG_MODE
    uniform sampler2D shadowtex1;
    uniform sampler2D shadowcolor0;
    uniform sampler2D colortex3;
#endif

uniform sampler2D gaux3;
uniform sampler2D colortex1;
uniform float viewWidth;

#if AA_TYPE == 3
    uniform float pixel_size_x;
    uniform float pixel_size_y;
#endif

/* Ins / Outs */

varying vec2 texcoord;
varying float exposure;

/* Utility functions */

#if AA_TYPE == 3
    // #include "/lib/post.glsl"
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
// BEGIN INLINE /lib/fxaa.glsl
/* MakeUp Ultra Fast - fxaa_intel.glsl
FXAA 3.11 from Simon Rodriguez
http://blog.simonrodriguez.fr/articles/30-07-2016_implementing_fxaa.html

*/

const float quality[12] = float[12] (1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.5f, 2.0f, 2.0f, 2.0f, 2.0f, 4.0f, 8.0f);

vec3 fxaa311(vec3 color, int iterations){
  vec3 aa = color;

  float edgeThresholdMin = 0.03125f;
  float edgeThresholdMax = 0.0625f;
  float subpixelQuality = 0.75f;

  // Luma at the current fragment
  float lumaCenter = luma(color);
  // Luma at the four direct neighbours of the current fragment.
  float lumaDown = luma(texture2DLod(colortex1, texcoord.xy + vec2(0.0,-pixel_size_y), 0.0).rgb);
  float lumaUp = luma(texture2DLod(colortex1, texcoord.xy + vec2(0.0,pixel_size_y), 0.0).rgb);
  float lumaLeft = luma(texture2DLod(colortex1, texcoord.xy + vec2(-pixel_size_x, 0.0), 0.0).rgb);
  float lumaRight = luma(texture2DLod(colortex1, texcoord.xy + vec2(pixel_size_x, 0.0), 0.0).rgb);

  // Find the maximum and minimum luma around the current fragment.
  float lumaMin = min(lumaCenter, min(min(lumaDown, lumaUp), min(lumaLeft, lumaRight)));
  float lumaMax = max(lumaCenter, max(max(lumaDown, lumaUp), max(lumaLeft, lumaRight)));

  // Compute the delta.
  float lumaRange = lumaMax - lumaMin;

  // If the luma variation is lower that a threshold (or if we are in a really dark area), we are not on an edge, don't perform any FXAA.
  if (lumaRange > max(edgeThresholdMin, lumaMax * edgeThresholdMax)) {
    // Query the 4 remaining corners lumas.
    float lumaDownLeft = luma(texture2DLod(colortex1, texcoord.xy + vec2(-pixel_size_x, -pixel_size_y), 0.0).rgb);
    float lumaUpRight = luma(texture2DLod(colortex1, texcoord.xy + vec2(pixel_size_x, pixel_size_y), 0.0).rgb);
    float lumaUpLeft = luma(texture2DLod(colortex1, texcoord.xy + vec2(-pixel_size_x, pixel_size_y), 0.0).rgb);
    float lumaDownRight = luma(texture2DLod(colortex1, texcoord.xy + vec2(pixel_size_x, -pixel_size_y), 0.0).rgb);

    // Combine the four edges lumas (using intermediary variables for future computations with the same values).
    float lumaDownUp = lumaDown + lumaUp;
    float lumaLeftRight = lumaLeft + lumaRight;

    // Same for corners
    float lumaLeftCorners = lumaDownLeft + lumaUpLeft;
    float lumaDownCorners = lumaDownLeft + lumaDownRight;
    float lumaRightCorners = lumaDownRight + lumaUpRight;
    float lumaUpCorners = lumaUpRight + lumaUpLeft;

    // Compute an estimation of the gradient along the horizontal and vertical axis.
    float edgeHorizontal = abs(-2.0f * lumaLeft + lumaLeftCorners) + abs(-2.0f * lumaCenter + lumaDownUp ) * 2.0f + abs(-2.0f * lumaRight + lumaRightCorners);
    float edgeVertical = abs(-2.0f * lumaUp + lumaUpCorners) + abs(-2.0f * lumaCenter + lumaLeftRight) * 2.0f + abs(-2.0f * lumaDown + lumaDownCorners);

    // Is the local edge horizontal or vertical ?
    bool isHorizontal = (edgeHorizontal >= edgeVertical);

    // Select the two neighboring texels lumas in the opposite direction to the local edge.
    float luma1 = isHorizontal ? lumaDown : lumaLeft;
    float luma2 = isHorizontal ? lumaUp : lumaRight;
    // Compute gradients in this direction.
    float gradient1 = luma1 - lumaCenter;
    float gradient2 = luma2 - lumaCenter;

    // Which direction is the steepest ?
    bool is1Steepest = abs(gradient1) >= abs(gradient2);
    // Gradient in the corresponding direction, normalized.
    float gradientScaled = 0.25f*max(abs(gradient1), abs(gradient2));

    // Choose the step size (one pixel) according to the edge direction.
    float stepLength = isHorizontal ? pixel_size_y : pixel_size_x;

    // Average luma in the correct direction.
    float lumaLocalAverage = 0.0;

    if (is1Steepest){
      // Switch the direction
      stepLength = - stepLength;
      lumaLocalAverage = 0.5f*(luma1 + lumaCenter);
    } else {
      lumaLocalAverage = 0.5f*(luma2 + lumaCenter);
    }

    // Shift UV in the correct direction by half a pixel.
    vec2 currentUv = texcoord.xy;
    if (isHorizontal){
      currentUv.y += stepLength * 0.5f;
    } else {
      currentUv.x += stepLength * 0.5f;
    }

    // Compute offset (for each iteration step) in the right direction.
    vec2 offset = isHorizontal ? vec2(pixel_size_x, 0.0) : vec2(0.0, pixel_size_y);

    // Compute UVs to explore on each side of the edge, orthogonally. The QUALITY allows us to step faster.
    vec2 uv1 = currentUv - offset;
    vec2 uv2 = currentUv + offset;

    // Read the lumas at both current extremities of the exploration segment, and compute the delta wrt to the local average luma.
    float lumaEnd1 = luma(texture2DLod(colortex1, uv1, 0.0).rgb);
    float lumaEnd2 = luma(texture2DLod(colortex1, uv2, 0.0).rgb);
    lumaEnd1 -= lumaLocalAverage;
    lumaEnd2 -= lumaLocalAverage;

    // If the luma deltas at the current extremities are larger than the local gradient, we have reached the side of the edge.
    bool reached1 = abs(lumaEnd1) >= gradientScaled;
    bool reached2 = abs(lumaEnd2) >= gradientScaled;
    bool reachedBoth = reached1 && reached2;

    // If the side is not reached, we continue to explore in this direction.
    if (!reached1){
      uv1 -= offset;
    }
    if (!reached2){
      uv2 += offset;
    }

    // If both sides have not been reached, continue to explore.
    if (!reachedBoth) {
      for(int i = 2; i < iterations; i++) {
        // If needed, read luma in 1st direction, compute delta.
        if (!reached1) {
          lumaEnd1 = luma(texture2DLod(colortex1, uv1, 0.0).rgb);
          lumaEnd1 = lumaEnd1 - lumaLocalAverage;
        }
        // If needed, read luma in opposite direction, compute delta.
        if (!reached2) {
          lumaEnd2 = luma(texture2DLod(colortex1, uv2, 0.0).rgb);
          lumaEnd2 = lumaEnd2 - lumaLocalAverage;
        }

        // If the luma deltas at the current extremities is larger than the
        // local gradient, we have reached the side of the edge.
        reached1 = abs(lumaEnd1) >= gradientScaled;
        reached2 = abs(lumaEnd2) >= gradientScaled;
        reachedBoth = reached1 && reached2;

        // If the side is not reached, we continue to explore in this direction,
        // with a variable quality.
        if (!reached1) {
          uv1 -= offset * quality[i];
        }
        if (!reached2) {
          uv2 += offset * quality[i];
        }

        // If both sides have been reached, stop the exploration.
        if (reachedBoth) {
          break;
        }
      }
    }

    // Compute the distances to each extremity of the edge.
    float distance1 = isHorizontal ? (texcoord.x - uv1.x) : (texcoord.y - uv1.y);
    float distance2 = isHorizontal ? (uv2.x - texcoord.x) : (uv2.y - texcoord.y);

    // In which direction is the extremity of the edge closer ?
    bool isDirection1 = distance1 < distance2;
    float distanceFinal = min(distance1, distance2);

    // Length of the edge.
    float edgeThickness = (distance1 + distance2);

    // UV offset: read in the direction of the closest side of the edge.
    float pixelOffset = - distanceFinal / edgeThickness + 0.5f;


    // Is the luma at center smaller than the local average ?
    bool isLumaCenterSmaller = lumaCenter < lumaLocalAverage;

    // If the luma at center is smaller than at its neighbour, the delta luma at
    // each end should be positive (same variation).
    // (in the direction of the closer side of the edge.)
    bool correctVariation = ((isDirection1 ? lumaEnd1 : lumaEnd2) < 0.0) != isLumaCenterSmaller;

    // If the luma variation is incorrect, do not offset.
    float finalOffset = correctVariation ? pixelOffset : 0.0f;

    // Sub-pixel shifting
    // Full weighted average of the luma over the 3x3 neighborhood.
    float lumaAverage = (1.0f/12.0f) * (2.0f * (lumaDownUp + lumaLeftRight) + lumaLeftCorners + lumaRightCorners);
    // Ratio of the delta between the global average and the center luma, over
    // the luma range in the 3x3 neighborhood.
    float subPixelOffset1 = clamp(abs(lumaAverage - lumaCenter)/lumaRange,0.0f,1.0f);
    float subPixelOffset2 = (-2.0f * subPixelOffset1 + 3.0f) * subPixelOffset1 * subPixelOffset1;
    // Compute a sub-pixel offset based on this delta.
    float subPixelOffsetFinal = subPixelOffset2 * subPixelOffset2 * subpixelQuality;

    // Pick the biggest of the two offsets.
    finalOffset = max(finalOffset, subPixelOffsetFinal);

    // Compute the final UV coordinates.
    vec2 finalUv = texcoord.xy;
    if (isHorizontal){
      finalUv.y += finalOffset * stepLength;
    } else {
      finalUv.x += finalOffset * stepLength;
    }

    // Read the color at the new UV coordinates, and use it.
    aa = texture2DLod(colortex1, finalUv, 0.0).rgb;
  }

  return aa;
}
// END INLINE /lib/fxaa.glsl
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
// BEGIN INLINE /lib/tone_maps.glsl
/* MakeUp - tone_maps.glsl
Tonemap functions.

Javier Garduño - GNU Lesser General Public License v3.0
*/

// vec3 custom_sigmoid(vec3 color) {
//     color = 1.4 * color;
//     color = color / pow(pow(color, vec3(3.0)) + 1.0, vec3(0.3333333333333));

//     return pow(color, vec3(1.15));
// }

vec3 custom_sigmoid(vec3 color) {
    color = 1.8 * color;
    color = color / pow(pow(color, vec3(2.5)) + 1.0, vec3(0.4));

    return pow(color, vec3(1.15));
}
// END INLINE /lib/tone_maps.glsl

#ifdef COLOR_BLINDNESS
// BEGIN INLINE /lib/color_blindness.glsl
/* MakeUp - color_blindness.glsl
The correction algorithm is taken from http://www.daltonize.org/search/label/Daltonize

Javier Garduño - GNU Lesser General Public License v3.0
*/

vec3 color_blindness(vec3 color) {	
    float L = (17.8824 * color.r) + (43.5161 * color.g) + (4.11935 * color.b);
    float M = (3.45565 * color.r) + (27.1554 * color.g) + (3.86714 * color.b);
    float S = (0.0299566 * color.r) + (0.184309 * color.g) + (1.46709 * color.b);

    float l, m, s;
    #if COLOR_BLIND_MODE == 0  // Protanopia
        l = 0.0 * L + 2.02344 * M + -2.52581 * S;
        m = 0.0 * L + 1.0 * M + 0.0 * S;
        s = 0.0 * L + 0.0 * M + 1.0 * S;
    #elif COLOR_BLIND_MODE == 1  // Deutranopia
        l = 1.0 * L + 0.0 * M + 0.0 * S;
        m = 0.494207 * L + 0.0 * M + 1.24827 * S;
        s = 0.0 * L + 0.0 * M + 1.0 * S;
    #elif COLOR_BLIND_MODE == 2  // Tritanopia
        l = 1.0 * L + 0.0 * M + 0.0 * S;
        m = 0.0 * L + 1.0 * M + 0.0 * S;
        s = -0.395913 * L + 0.801109 * M + 0.0 * S;
    #endif

    vec3 error;
    error.r = (0.0809444479 * l) + (-0.130504409 * m) + (0.116721066 * s);
    error.g = (-0.0102485335 * l) + (0.0540193266 * m) + (-0.113614708 * s);
    error.b = (-0.000365296938 * l) + (-0.00412161469 * m) + (0.693511405 * s);

    vec3 diff = color - error;
    vec3 correction;
    correction.r = 0.0;
    correction.g = (diff.r * 0.7) + (diff.g * 1.0);
    correction.b = (diff.r * 0.7) + (diff.b * 1.0);
    correction = color + correction;

    return correction;
}
// END INLINE /lib/color_blindness.glsl
#endif

#if CHROMA_ABER == 1
// BEGIN INLINE /lib/aberration.glsl
/* MakeUp - aberration.glsl
Color aberration effect.
*/

vec3 color_aberration() {
    vec2 offset = texcoord - 0.5;

    offset *= vec2(0.125) * CHROMA_ABER_STRENGTH;

    vec3 aberrated_color = vec3(0.0);

    aberrated_color.r = texture2DLod(colortex1, texcoord - offset, 0.0).r;
    aberrated_color.g = texture2DLod(colortex1, texcoord - (offset * 0.5), 0.0).g;
    aberrated_color.b = texture2DLod(colortex1, texcoord, 0.0).b;

    return aberrated_color;
}
// END INLINE /lib/aberration.glsl
#endif



// MAIN FUNCTION ------------------

void main() {
    #if CHROMA_ABER == 1
        vec3 block_color = color_aberration();
    #else
        vec3 block_color = texture2D(colortex1, texcoord).rgb;
        #if AA_TYPE == 3 && !defined DOF
            block_color = fxaa311(block_color, 5);
        #endif
    #endif
    
    // --- CORRECCIÓN CRÍTICA SWEETSPOTATO ---
    // El problema: 'exposure' sube demasiado en cuevas, matando el contraste.
    // Solución: Limitamos cuánto puede "abrirse" el ojo.
    
    // Ajusta este 1.5 a gusto. 
    // 1.0 = Sin visión nocturna automática (Cuevas muy oscuras).
    // 2.0 = Adaptación moderada.
    // >3.0 = El valor original que causaba el problema.
    float max_exposure = 1.3; 
    
    float clamped_exposure = min(exposure, max_exposure);
    block_color *= vec3(clamped_exposure);

    // Tone Mapping
    block_color = custom_sigmoid(block_color);

    // Color-grading -----
    // DEVELOPER: If your post processing effect only involves the current pixel,
    // it can be placed here. For example:

    // Saturation:
    // float actual_luma = luma(block_color);
    // block_color = mix(vec3(actual_luma), block_color, 1.5);

    // Color-blindness correction
    #ifdef COLOR_BLINDNESS
        block_color = color_blindness(block_color);
    #endif

    #ifdef DEBUG_MODE
        if(texcoord.x < 0.5 && texcoord.y < 0.5) {
            block_color = texture2D(shadowtex1, texcoord * 2.0).rrr;
        } else if(texcoord.x >= 0.5 && texcoord.y >= 0.5) {
            block_color = vec3(texture2D(gaux3, vec2(0.5)).r * 0.25);
        } else if(texcoord.x < 0.5 && texcoord.y >= 0.5) {
            block_color = texture2D(colortex1, ((texcoord - vec2(0.0, 0.5)) * 2.0)).rgb;
        } else if(texcoord.x >= 0.5 && texcoord.y < 0.5) {
            block_color = texture2D(shadowcolor0, ((texcoord - vec2(0.5, 0.0)) * 2.0)).rgb;
        } else {
            block_color = vec3(0.5);
        }

        gl_FragData[0] = vec4(block_color, 1.0);

    #else
        gl_FragData[0] = vec4(block_color, 1.0);
    #endif
}
// END INLINE /common/final_fragment.glsl
