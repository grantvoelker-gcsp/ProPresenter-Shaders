#include "metalShaderTypes.h"
#include "alpha.h"

// Alpha Curve: remaps a pixel's opacity based on its luminance, using three
// control points — dark (luma 0), midtone (luma 0.5), light (luma 1) — with
// piecewise-linear interpolation between them. RGB is untouched; only alpha
// is scaled. The effect's Intensity (blendValue) crossfades the whole thing.
typedef struct
{
    float darkOpacity;
    float midOpacity;
    float lightOpacity;
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
    vec4 texColor = getColor(inputTex, fsTexture);
#ifdef PRE_MULT
    divideAlpha(texColor);
#endif

    // Rec.709 luma of the straight-alpha color.
    float luma = dot(texColor.rgb, vec3(0.2126, 0.7152, 0.0722));

    // Piecewise-linear opacity curve through the three control points.
    float lo = mix(vars.darkOpacity, vars.midOpacity, saturate(luma * 2.0));
    float hi = mix(vars.midOpacity, vars.lightOpacity, saturate((luma - 0.5) * 2.0));
    float opacity = (luma < 0.5) ? lo : hi;

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif

    float4 outColor = texColor;
    outColor.a = mix(texColor.a, texColor.a * opacity, blendValue);

#ifdef PRE_MULT
    multiplyAlpha(outColor);
#endif
    return outColor;
}
