#include "metalShaderTypes.h"
#include "alpha.h"

// Rectangular alpha mask. Keeps pixels inside the rectangle, fades to transparent
// across the edge. Center X/Y positions it and Scale X/Y are the half-width and
// half-height in 0..1 UV space; Edge Fade feathers the border; Invert flips
// inside/outside.
typedef struct
{
    float centerX;
    float centerY;
    float scaleX;
    float scaleY;
    float fade;
    float invert;
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

    vec2 uv = fsTexture;
    vec2 center = vec2(vars.centerX, vars.centerY);
    vec2 halfsize = max(vec2(vars.scaleX, vars.scaleY), vec2(1e-4));

    // Box distance: 1.0 exactly on the nearest rectangle edge, >1 outside.
    vec2 q = abs(uv - center) / halfsize;
    float dist = max(q.x, q.y);

    float fade = max(vars.fade, 1e-4);
    float mask = 1.0 - smoothstep(1.0 - fade, 1.0, dist);

    // Invert: keep outside instead of inside.
    mask = mix(mask, 1.0 - mask, step(0.5, vars.invert));

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif

    float4 outColor = texColor;
    outColor.a = mix(texColor.a, texColor.a * mask, blendValue);

#ifdef PRE_MULT
    multiplyAlpha(outColor);
#endif
    return outColor;
}
