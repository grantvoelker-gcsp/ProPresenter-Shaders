// DIAGNOSTIC build of AlphaCurve — paints the whole slide a flat color equal to
// (darkOpacity, midOpacity, lightOpacity) so uniform delivery is visible without
// depending on image content. Default (1,1,1)=white; Dark0=cyan, Mid0=magenta,
// Light0=yellow. Restore the real shader with `install.sh` when done.
#include "metalShaderTypes.h"
#include "alpha.h"

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
    // Ignore image content entirely; show the raw uniforms as an opaque color.
    return float4(vars.darkOpacity, vars.midOpacity, vars.lightOpacity, 1.0);
}
