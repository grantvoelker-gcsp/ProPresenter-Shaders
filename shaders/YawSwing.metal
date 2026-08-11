#include "metalShaderTypes.h"
#include "alpha.h"

// Fake-3D yaw swing. Rotates the layer about its vertical axis with perspective,
// oscillating angle * sin(time * speed) so it swings +angle -> 0 (middle) -> -angle
// and back. Speed sets the rate, Angle the extent (degrees), Perspective the depth.
// Inverse perspective map (per output pixel, find the source point on the rotated
// plane). No radians(); degrees -> radians via an explicit constant.
typedef struct
{
    float speed;
    float angle;
    float perspective;
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
    vec2 p = uv - 0.5;                                   // screen-centered

    float maxAng = vars.angle * 0.0174532925199433;      // degrees -> radians
    float yaw = maxAng * sin(u.globalTime * vars.speed);  // +A -> 0 -> -A oscillation
    float c = cos(yaw);
    float s = sin(yaw);

    // Camera distance: higher = flatter, lower = stronger perspective.
    float D = mix(6.0, 1.6, clamp(vars.perspective, 0.0, 1.0));

    // Inverse map screen -> source on the plane rotated about the vertical axis.
    float denom = c * D - p.x * s;
    float x = (p.x * D) / denom;
    float w = D / (D + x * s);
    float y = p.y / w;
    vec2 srcUV = vec2(x, y) + 0.5;

    // Front-facing / on-card validity: denom must stay positive; off-card samples
    // fall outside 0..1 and the clamp-to-border sampler returns transparent.
    float valid = step(0.02, denom);
    vec4 warped = getColor(inputTex, srcUV) * valid;

    vec4 texColor = getColor(inputTex, uv);
    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif
    float4 outColor;
    outColor.rgb = mix(texColor.rgb, warped.rgb, blendValue);
    outColor.a   = mix(texColor.a, warped.a, blendValue);
    return outColor;
}
