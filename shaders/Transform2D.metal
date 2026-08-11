#include "metalShaderTypes.h"
#include "alpha.h"

// 2D affine transform: X/Y translate, uniform Scale, horizontal Skew, Rotation.
// Inverse-mapped per output pixel, aspect-corrected so rotation stays true on
// non-square layers. Off-frame samples fall to transparent (clamp-to-border).
// Forward order is scale -> skew -> rotate -> translate; this applies the inverse.
typedef struct
{
    float x;         // translate X (fraction of width; + moves right)
    float y;         // translate Y (fraction of height; + moves up)
    float scale;     // uniform scale (>1 zooms in)
    float skew;      // horizontal shear
    float rotation;  // degrees
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
    float aspect = input.texSize.x / max(input.texSize.y, 1.0);

    // Centered, translation removed (Y flipped so + is up), then to square space.
    vec2 c = (fsTexture - 0.5) - vec2(vars.x, -vars.y);
    c.x *= aspect;

    // Inverse rotation.
    float th = -vars.rotation * 0.0174532925199433;
    float cs = cos(th), sn = sin(th);
    vec2 b = vec2(c.x * cs - c.y * sn, c.x * sn + c.y * cs);

    // Inverse horizontal skew, then inverse uniform scale.
    vec2 a = vec2(b.x - vars.skew * b.y, b.y);
    a /= max(vars.scale, 1e-4);

    // Back to UV space.
    a.x /= aspect;
    vec2 srcUV = a + 0.5;

    vec4 warped = getColor(inputTex, srcUV);

    vec4 texColor = getColor(inputTex, fsTexture);
    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif
    float4 outColor;
    outColor.rgb = mix(texColor.rgb, warped.rgb, blendValue);
    outColor.a   = mix(texColor.a, warped.a, blendValue);
    return outColor;
}
