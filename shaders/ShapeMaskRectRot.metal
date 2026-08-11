#include "metalShaderTypes.h"
#include "alpha.h"

// Rectangular alpha mask with rotation. Same as Shape Mask (Rectangle) plus a
// Rotation control that turns the rectangle rigidly about its center, aspect-
// corrected so it stays a true rectangle on non-square layers. Center X/Y position
// it; Scale X/Y are half-width/half-height in UV; Fade feathers the edge; Invert
// flips inside/outside. Rotation in degrees. No radians().
typedef struct
{
    float centerX;
    float centerY;
    float scaleX;
    float scaleY;
    float rotation;
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

    float aspect = input.texSize.x / max(input.texSize.y, 1.0);

    // Delta from center in aspect-corrected (square) space, then inverse-rotate.
    vec2 d = fsTexture - vec2(vars.centerX, vars.centerY);
    d.x *= aspect;
    float th = -vars.rotation * 0.0174532925199433;
    float cs = cos(th), sn = sin(th);
    vec2 dr = vec2(d.x * cs - d.y * sn, d.x * sn + d.y * cs);

    // Half-extents in the same square space (scaleX is a fraction of width).
    vec2 half2 = max(vec2(vars.scaleX * aspect, vars.scaleY), vec2(1e-4));
    vec2 q = abs(dr) / half2;
    float dist = max(q.x, q.y);            // 1.0 on the nearest edge, >1 outside

    float fade = max(vars.fade, 1e-4);
    float mask = 1.0 - smoothstep(1.0 - fade, 1.0, dist);
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
