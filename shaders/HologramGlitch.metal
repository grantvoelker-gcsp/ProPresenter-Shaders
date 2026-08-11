#include "metalShaderTypes.h"
#include "alpha.h"

// Hologram Glitch: image-space sci-fi hologram look. Combines random band tearing
// (per-60s chance + seed), RGB split, scanlines, a scrolling roll bar, flicker, a
// light holo glow, and a color Tint. Time-driven off globalTime; precision-robust
// hashing; no radians(). Tint is a float4 color placed after the scalars.
typedef struct
{
    float scanAmount;    // scanline darkening
    float scanDensity;   // scanline count across height
    float rollAmount;    // rolling bar brightness
    float rollSpeed;     // rolling bar scroll speed
    float rgbSplit;      // chromatic aberration
    float glitchChance;  // band-tearing bursts per 60 seconds
    float glitchAmount;  // tearing strength
    float flicker;       // brightness flicker
    float noise;         // grain amplitude
    float glow;          // holo glow
    float tintAmount;    // how strongly to tint toward the holo color
    float seed;          // decorrelate instances
    float4 tintColor;    // holo color (RGBA; rgb used)
} fxVars;

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
    float t = u.globalTime;
    float seed = vars.seed;

    // --- Band-tearing burst trigger (chance per 60s). ---
    float chancePerSec = clamp(vars.glitchChance / 60.0, 0.0, 1.0);
    float sec = floor(t);
    float fire = step(hash21(vec2(sec, seed)), chancePerSec);
    float burst = fire * step(fract(t), 0.25);          // ~0.25s bursts
    float gAmt = vars.glitchAmount * burst;

    // Per-row horizontal tear during a burst (flickers within it).
    float rowSeed = floor(t * 20.0);
    float band = floor(uv.y * 40.0);
    float doTear = step(1.0 - gAmt, hash21(vec2(band, rowSeed + seed)));
    float tear = (hash21(vec2(band * 1.7, rowSeed + seed)) - 0.5) * gAmt * 0.10 * doTear;
    vec2 guv = uv + vec2(tear, 0.0);

    // --- RGB split (stronger during a burst). ---
    float split = vars.rgbSplit * 0.004 * (1.0 + burst * 3.0);
    vec4 cr = getColor(inputTex, guv + vec2(split, 0.0));
    vec4 cg = getColor(inputTex, guv);
    vec4 cb = getColor(inputTex, guv - vec2(split, 0.0));
    vec3 col = vec3(cr.r, cg.g, cb.b);
    float outA = cg.a;

    // --- Light holo glow: over-threshold brightness from 8 offset taps. ---
    vec3 glowSum = vec3(0.0);
    float gr = 3.0 + vars.glow * 6.0;   // px radius
    for (int i = 0; i < 8; i++)
    {
        float ang = float(i) * 0.7853981634;   // i * 45 deg
        vec2 dir = vec2(cos(ang), sin(ang)) * gr / input.texSize;
        glowSum += max(getColor(inputTex, uv + dir).rgb - 0.6, vec3(0.0));
    }
    glowSum *= vars.glow / 8.0;

    // --- Holo tint (push toward the tint color by luminance). ---
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, luma * vars.tintColor.rgb * 1.15, clamp(vars.tintAmount, 0.0, 1.0));
    col += glowSum * vars.tintColor.rgb;

    // --- Scanlines. ---
    float scan = 0.5 + 0.5 * sin(uv.y * max(vars.scanDensity, 1.0) * 6.2831853);
    col *= mix(1.0, scan, clamp(vars.scanAmount, 0.0, 1.0));

    // --- Scrolling roll bar. ---
    float rollCenter = fract(t * vars.rollSpeed);
    float dy = abs(uv.y - rollCenter);
    dy = min(dy, 1.0 - dy);
    col += smoothstep(0.05, 0.0, dy) * clamp(vars.rollAmount, 0.0, 1.0) * vars.tintColor.rgb;

    // --- Flicker + grain. ---
    float flk = hash11(floor(t * 18.0) + seed * 3.1);
    col *= 1.0 - vars.flicker * 0.5 * flk;
    col += (hash21(uv * input.texSize + floor(t * 24.0)) - 0.5) * max(vars.noise, 0.0);

    col = saturate(col);

    vec4 texColor = getColor(inputTex, uv);
    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif
    float4 outColor;
    outColor.rgb = mix(texColor.rgb, col, blendValue);
    outColor.a   = mix(texColor.a, outA, blendValue);
    return outColor;
}
