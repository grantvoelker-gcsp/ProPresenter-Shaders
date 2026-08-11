#include "metalShaderTypes.h"
#include "alpha.h"

// Pen-and-ink cross-hatch shading. Darkness drives hatch density: light areas get
// one diagonal set, darker adds the crossing set, darkest adds interleaved lines.
// Line Spacing and Thickness are in pixels; Darkness biases how much gets hatched.
typedef struct
{
    float spacing;     // px between hatch lines
    float thickness;   // px line width
    float darkness;    // 0..1 bias: higher hatches lighter areas too
} fxVars;

// Anti-aliased hatch line: 1 on a line, 0 between. v is the coordinate projected
// along the line normal (e.g. x+y for 45 degrees), sp spacing, th width (px).
float hatchLine(float v, float sp, float th)
{
    float f = fract(v / sp);
    float d = min(f, 1.0 - f) * sp;              // px distance to nearest line
    return 1.0 - smoothstep(th * 0.5, th * 0.5 + 1.0, d);
}

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

    float lum = dot(texColor.rgb, vec3(0.2126, 0.7152, 0.0722));

    vec2 pos = fsTexture * input.texSize;       // pixel coordinates
    float sp = max(vars.spacing, 2.0);
    float th = clamp(vars.thickness, 0.25, sp);

    // Four luminance tiers; the Darkness control shifts them so more/less hatches.
    float bias = (clamp(vars.darkness, 0.0, 1.0) - 0.5) * 0.6;
    float t1 = clamp(0.80 + bias, 0.0, 1.0);
    float t2 = clamp(0.60 + bias, 0.0, 1.0);
    float t3 = clamp(0.40 + bias, 0.0, 1.0);
    float t4 = clamp(0.20 + bias, 0.0, 1.0);

    float g1 = 1.0 - smoothstep(t1 - 0.04, t1 + 0.04, lum);
    float g2 = 1.0 - smoothstep(t2 - 0.04, t2 + 0.04, lum);
    float g3 = 1.0 - smoothstep(t3 - 0.04, t3 + 0.04, lum);
    float g4 = 1.0 - smoothstep(t4 - 0.04, t4 + 0.04, lum);

    float ink = 0.0;
    ink = max(ink, hatchLine(pos.x + pos.y,             sp, th) * g1);   // 45 deg
    ink = max(ink, hatchLine(pos.x - pos.y,             sp, th) * g2);   // cross -45 deg
    ink = max(ink, hatchLine(pos.x + pos.y + sp * 0.5,  sp, th) * g3);   // interleaved
    ink = max(ink, hatchLine(pos.x - pos.y + sp * 0.5,  sp, th) * g4);   // interleaved cross

    vec3 drawing = mix(vec3(1.0), vec3(0.0), ink);   // black ink on white paper

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif

    float4 outColor;
    outColor.rgb = mix(texColor.rgb, drawing, blendValue);
    outColor.a   = texColor.a;
#ifdef PRE_MULT
    multiplyAlpha(outColor);
#endif
    return outColor;
}
