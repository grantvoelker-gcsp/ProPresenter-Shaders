#include "metalShaderTypes.h"
#include "alpha.h"

// Elliptical (circle/oval) alpha mask. Keeps pixels inside the ellipse, fades to
// transparent across the edge. Center X/Y and Scale X/Y position and size it in
// 0..1 UV space; Edge Fade feathers the border; Invert flips inside/outside.
// Note: coordinates are in the object's UV space, so equal Scale X/Y is a true
// circle only on a square object; otherwise it reads as an oval (adjust to taste).
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
    vec2 radius = max(vec2(vars.scaleX, vars.scaleY), vec2(1e-4));

    // Normalized elliptical distance: 1.0 exactly on the ellipse edge.
    vec2 d = (uv - center) / radius;
    float dist = length(d);

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
