#include "metalShaderTypes.h"
#include "alpha.h"

// Fake 3D extrusion / long-shadow. Marches backward along Angle up to Size pixels;
// wherever the source shape covers, it fills an extruded body that darkens with
// depth (Shade), with the original object composited on top. Angle in degrees
// (0 = right, 90 = down in UV space); Size in pixels; Shade 0..1 depth darkening.
typedef struct
{
    float angle;
    float size;
    float shade;
} fxVars;

// 2x1 hash for per-pixel jitter (same as the stock blur shaders use).
float hash( vec2 p ){ return fract(sin(dot(p, vec2(41, 289)))*45758.5453); }

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

    // Extrusion direction (degrees -> radians via explicit constant; no radians()).
    float ang = vars.angle * 0.0174532925199433;
    vec2 dir = vec2(cos(ang), sin(ang));

    int steps = int(clamp(vars.size, 0.0, 128.0));

    // Per-pixel sub-pixel jitter dithers the depth quantization so the shading
    // gradient and the diagonal silhouette read as smooth instead of striped.
    float jitter = hash(fsTexture * input.texSize);

    // March backward toward the source; a pixel is part of the extrusion if the
    // source shape lies within Size pixels along the direction. Depth is weighted
    // by the source's smooth alpha (no hard threshold) to keep edges clean.
    float body = 0.0;    // extruded coverage
    float nearT = 1.0;   // normalized distance (0..1) to the nearest source hit
    for (int i = 1; i <= steps; i++)
    {
        float dd = float(i) - jitter;
        float a = getColor(inputTex, fsTexture - dir * (dd / input.texSize)).a;
        body = max(body, a);
        nearT = min(nearT, mix(1.0, dd / float(steps), a));
    }

    // Tint the extrusion with the color at the nearest source hit, darkened by depth.
    vec3 hitCol = getColor(inputTex, fsTexture - dir * (nearT * float(steps) / input.texSize)).rgb;
    vec3 extCol = hitCol * (1.0 - nearT * vars.shade);

    // Composite: original object OVER the extruded body (straight alpha).
    float outA = texColor.a + body * (1.0 - texColor.a);
    vec3 outRGB = (texColor.rgb * texColor.a + extCol * body * (1.0 - texColor.a)) / max(outA, 1e-4);

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif

    float4 outColor;
    outColor.rgb = mix(texColor.rgb, outRGB, blendValue);
    outColor.a   = mix(texColor.a, outA, blendValue);

#ifdef PRE_MULT
    multiplyAlpha(outColor);
#endif
    return outColor;
}
