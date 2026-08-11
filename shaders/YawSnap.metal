#include "metalShaderTypes.h"
#include "alpha.h"

// Fake-3D yaw SNAP. Same perspective warp as Yaw Swing 3D, but the yaw jumps
// (holds) between +angle, 0 (middle), -angle, 0 instead of easing. Speed sets the
// rate, Angle the extent (degrees), Perspective the depth. No radians().
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
    vec2 p = uv - 0.5;

    float maxAng = vars.angle * 0.0174532925199433;   // degrees -> radians

    // Stepped oscillation: one cycle == same period as the Swing version, split
    // into 4 held quarters. cos(step * 90 degrees) yields +1, 0, -1, 0 -> snaps
    // +angle -> middle -> -angle -> middle, holding each until the next jump.
    float phase = fract(u.globalTime * vars.speed * 0.1591549430919);   // 0..1 per cycle
    float lvl = cos(floor(phase * 4.0) * 1.5707963267949);
    float yaw = maxAng * lvl;

    float c = cos(yaw);
    float s = sin(yaw);

    float D = mix(6.0, 1.6, clamp(vars.perspective, 0.0, 1.0));

    float denom = c * D - p.x * s;
    float x = (p.x * D) / denom;
    float w = D / (D + x * s);
    float y = p.y / w;
    vec2 srcUV = vec2(x, y) + 0.5;

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
