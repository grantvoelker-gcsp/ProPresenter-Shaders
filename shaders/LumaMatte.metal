#include "metalShaderTypes.h"
#include "alpha.h"

// Alpha matte from luminance (luma key). Derives alpha from the image's brightness
// so a luma-encoded source (e.g. white-on-black) becomes real transparency. Keeps
// the RGB and multiplies the keyed alpha with any existing alpha. Threshold sets
// the cutoff, Softness feathers it, Invert flips which side stays opaque.
typedef struct
{
    float threshold;   // luminance cutoff
    float softness;    // feather half-width around the cutoff
    float invert;      // 0 bright = opaque, 1 dark = opaque
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

    float luma = dot(texColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    float thr = clamp(vars.threshold, 0.0, 1.0);
    float soft = max(vars.softness, 1e-4);

    float key = smoothstep(thr - soft, thr + soft, luma);   // bright -> 1
    key = mix(key, 1.0 - key, step(0.5, vars.invert));

    float keyedA = texColor.a * key;

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif
    // Intensity crossfades between the original alpha and the keyed alpha.
    float4 outColor = texColor;
    outColor.a = mix(texColor.a, keyedA, blendValue);
#ifdef PRE_MULT
    multiplyAlpha(outColor);
#endif
    return outColor;
}
