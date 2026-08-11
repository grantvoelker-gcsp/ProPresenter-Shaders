#include "metalShaderTypes.h"
#include "alpha.h"

// Box / block digital glitch. Fires in brief random bursts; frequency is set as an
// expected number of glitches per 60 seconds. While active it quantizes the image
// into blocks, randomly displaces a subset of them, and splits the RGB channels.
// (Standard ShaderToy-style block/RGB glitch, gated by a time-based trigger.)
typedef struct
{
    float frequency;   // expected glitches per 60 seconds
    float amount;      // fraction of blocks glitched + displacement strength
    float blockSize;   // number of blocks across the frame
    float duration;    // how long each glitch lasts (seconds)
    float seed;        // decorrelates instances: different seed -> different timing + pattern
} fxVars;

// Precision-robust hashes (Dave Hoskins). The old sin(x*large) hash collapses for
// large arguments (e.g. seed offsets), which biased the trigger toward always-on.
float hash11(float p){ p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float hash21(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

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

    float t = u.globalTime;
    float seed = vars.seed;   // per-instance offset applied to every hash

    // --- Trigger: random chance expressed as glitches per 60 seconds. ---
    // Each 1-second bucket independently fires with probability frequency/60.
    float chancePerSec = clamp(vars.frequency / 60.0, 0.0, 1.0);
    float sec = floor(t);
    // Seed is a hash dimension (not a large additive offset), so probability stays
    // uniform and correct for every seed.
    float fire = step(hash21(vec2(sec, seed)), chancePerSec);
    float dur = clamp(vars.duration, 0.02, 1.0);
    float active = fire * step(fract(t), dur);

    // Displacement / block-fraction strength while a glitch is active.
    float amt = vars.amount * active;

    // Per-frame random (flickers ~24/s), decorrelated by Seed and kept bounded so
    // the block hashes stay precise.
    float frame = floor(t * 24.0);
    float fRand = hash21(vec2(frame, seed + 1.0));
    vec2 fo = vec2(fRand * 311.0, fRand * 173.0);

    // --- Box glitch ---
    float blocks = max(vars.blockSize, 1.0);
    vec2 bidx = floor(uv * vec2(blocks, blocks));
    float rBlock = hash21(bidx + fo);
    float glitchBlock = step(1.0 - amt, rBlock);        // more Amount -> more blocks glitch

    float ox = (hash21(bidx * 1.31 + fo + 5.0) - 0.5) * amt * 0.20;   // horizontal shove
    float oy = (hash21(bidx * 2.17 + fo + 9.0) - 0.5) * amt * 0.05;   // small vertical
    vec2 guv = uv + vec2(ox, oy) * glitchBlock;

    // RGB channel split, scaled by Amount and only on glitched blocks.
    float rgb = amt * glitchBlock * 0.01;
    vec4 cr = getColor(inputTex, guv + vec2(rgb, 0.0));
    vec4 cg = getColor(inputTex, guv);
    vec4 cb = getColor(inputTex, guv - vec2(rgb, 0.0));
    vec4 glitched = vec4(cr.r, cg.g, cb.b, cg.a);

    // Passthrough when inactive (amt=0 -> guv=uv, rgb=0 -> glitched==texColor).
    vec4 res = mix(texColor, glitched, active);

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif
    float4 outColor;
    outColor.rgb = mix(texColor.rgb, res.rgb, blendValue);
    outColor.a   = mix(texColor.a, res.a, blendValue);
    return outColor;
}
