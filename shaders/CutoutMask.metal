#include "metalShaderTypes.h"
#include "alpha.h"

// Soft black cutout matte. Ignores the input RGB and works from its alpha: blurs
// (feathers) the alpha edge over a radius, optionally inverts it, and outputs solid
// black with that alpha. Lay it over a background: black where alpha is high, the
// background where low. The effect's Intensity fades the whole matte.
typedef struct
{
    float invert;    // 1 = invert the input alpha (default), 0 = keep as-is
    float feather;   // edge blur radius in pixels
} fxVars;

vertex fxVertexOut vertexFunc(uint vertexID [[ vertex_id ]]
                              ,const device fxShaderVerts* in[[ buffer(0) ]]
                              ,texture2d<half> inputTex0 [[ texture(0) ]]
                              ,texture2d<half> inputTexMask [[ texture(1) ]]
                              ,constant fxGeneralUniforms& u[[ buffer(1) ]]
                              ,constant fxVars& vars[[ buffer(2)]])
{
    fxVertexOut out;
    out.normPos = in[vertexID].pos.xy * vec2(.5, .5f) + vec2(.5, .5);
    out.position = in[vertexID].pos;
    out.tex1 = in[vertexID].tex1;
    out.texMask = in[vertexID].texMask;
    out.texSize = float2(inputTex0.get_width(), inputTex0.get_height());
    return out;
}

fragment float4 fragmentFunc(fxVertexOut input [[stage_in]]
                             ,texture2d<half> inputTex [[ texture(0) ]]
                             ,texture2d<half> inputTexMask [[ texture(1) ]]
                             ,constant fxGeneralUniforms& u[[ buffer(0) ]]
                             ,constant fxVars& vars[[ buffer(1)]])
{
    float feather = max(vars.feather, 0.0);

    // Blur the alpha over a soft 7x7 disk so the 1<->0 edge becomes a gradient.
    // feather = 0 -> all taps coincide -> the original hard edge.
    const int K = 3;
    float aSum = 0.0;
    float wSum = 0.0;
    for (int j = -K; j <= K; j++)
    {
        for (int i = -K; i <= K; i++)
        {
            float rr = length(vec2(float(i), float(j))) / float(K + 1);
            float w = smoothstep(1.0, 0.0, rr);
            vec2 off = vec2(float(i), float(j)) * (feather / float(K)) / input.texSize;
            aSum += getColor(inputTex, fsTexture + off).a * w;
            wSum += w;
        }
    }
    float a = aSum / max(wSum, 1e-4);

    float maskA = mix(a, 1.0 - a, step(0.5, vars.invert));

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif
    maskA *= blendValue;

    float4 outColor = float4(0.0, 0.0, 0.0, maskA);   // black with feathered matte alpha
#ifdef PRE_MULT
    multiplyAlpha(outColor);
#endif
    return outColor;
}
