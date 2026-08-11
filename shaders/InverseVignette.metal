#include "metalShaderTypes.h"
#include "alpha.h"

// Inverse vignette: darkens the CENTER and leaves the edges bright — the
// opposite of the stock Vignette. Radius sets the size of the dark region;
// the effect's Intensity (blendValue) controls how dark the center goes.
typedef struct
{
    float radius;
} fxVars;

vertex fxVertexOut vertexFunc(uint vertexID [[ vertex_id ]]
                              ,const device fxShaderVerts* in[[ buffer(0) ]]
                              ,texture2d<half> inputTex0 [[ texture(0) ]]
                              ,texture2d<half> inputTexMask [[ texture(1) ]]
                              ,constant fxGeneralUniforms& u[[ buffer(1) ]]
                              ,constant fxVars& vars[[ buffer(2)]])
{
    fxVertexOut out;

    out.normPos=in[vertexID].pos.xy*vec2(.5,-.5f);//+vec2(.5,.5);
    out.position=in[vertexID].pos;
    out.texSize=float2(inputTex0.get_width(),inputTex0.get_height());
    out.tex1=in[vertexID].tex1;
    out.texMask=in[vertexID].texMask;

    return out;
}

fragment float4 fragmentFunc(fxVertexOut input [[stage_in]]
                             ,texture2d<half> inputTex [[ texture(0) ]]
                             ,texture2d<half> inputTexMask [[ texture(1) ]]
                             ,constant fxGeneralUniforms& u[[ buffer(0) ]]
                             ,constant fxVars& vars[[ buffer(1)]])
{
    float4 texel = getColor(inputTex, fsTexture);
    float fsOuterRadius = vars.radius * 0.01;
    float fsInnerRadius = fsOuterRadius * 0.5;
    float dist = distance(input.normPos, vec2(0.0, 0.0));
    // Inverse falloff: 1 at the center, 0 out past the radius (stock drops the "1.0 -").
    float blend = (fsOuterRadius - dist) / (fsOuterRadius - fsInnerRadius);
    blend = clamp(blend, 0.0, 1.0);
    blend *= u.blendValue;
#ifdef USE_MASK
    blend *= float(inputTexMask.sample(linearSampler, input.texMask).a);
#endif
    float4 vignetteColor = float4(0.0, 0.0, 0.0, 1.0);
    float4 outColor;
    mixColor(outColor, texel, vignetteColor, blend);
    return outColor;
}
