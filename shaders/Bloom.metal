#include "metalShaderTypes.h"
#include "alpha.h"

// Additive bloom with overbright. Extracts the over-threshold brightness from a
// soft neighborhood (7x7 disk-weighted taps), adds it back to the original scaled
// by Amount, and saturates -- so bright cores + their glow exceed 1.0 and clip to
// white (true overexposure look, not a screen blend). Single pass because bloom
// must keep the original, which this framework does not preserve across passes.
typedef struct
{
    float threshold;   // brightness cutoff that blooms
    float amount;      // overbright strength (can push past 1 -> clips white)
    float radius;      // glow spread, in pixels
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
    vec2 uv = fsTexture;
    vec4 texColor = getColor(inputTex, uv);

    float thr = clamp(vars.threshold, 0.0, 0.999);
    float rad = max(vars.radius, 0.0);

    const int K = 3;                       // 7x7 kernel
    vec3 bloom = vec3(0.0);
    float wsum = 0.0;
    for (int j = -K; j <= K; j++)
    {
        for (int i = -K; i <= K; i++)
        {
            float rr = length(vec2(float(i), float(j))) / float(K + 1);
            float w = smoothstep(1.0, 0.0, rr);     // soft round falloff
            vec2 off = vec2(float(i), float(j)) * (rad / float(K)) / input.texSize;
            vec3 s = getColor(inputTex, uv + off).rgb;
            vec3 bright = max(s - thr, vec3(0.0)) / (1.0 - thr);  // over-threshold part
            bloom += bright * w;
            wsum += w;
        }
    }
    bloom /= max(wsum, 1e-4);

    // Additive overbright, clipped to white.
    vec3 lit = saturate(texColor.rgb + bloom * vars.amount);
    // Let the glow extend into transparent areas around bright edges.
    float bloomA = saturate(dot(bloom, vec3(0.2126, 0.7152, 0.0722)) * vars.amount);
    float litA = max(texColor.a, bloomA);

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif
    float4 outColor;
    outColor.rgb = mix(texColor.rgb, lit, blendValue);
    outColor.a   = mix(texColor.a, litA, blendValue);
    return outColor;
}
