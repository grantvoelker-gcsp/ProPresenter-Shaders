#include "metalShaderTypes.h"
#include "alpha.h"

// Radial Blur driven by a fixed Angle (0-360) instead of Speed. Identical to the
// stock Radial Blur except: (1) no globalTime, so it holds still; (2) the angle is
// converted to radians with an explicit constant instead of radians(), which is
// unsupported here and caused a null-pipeline crash.
typedef struct
{
    float blendValue;
    float angle;
    float iterations;
    float decay;
} fxVars;


// 2x1 hash. Used to jitter the samples.
float hash( vec2 p ){ return fract(sin(dot(p, vec2(41, 289)))*45758.5453); }


// Rotates a base direction vector by the given angle (radians).
vec3 lOff(float fsTime)
{

    vec2 u = sin(vec2(1.57, 0) - fsTime/2.);
    mat2 a = mat2(u.x,u.y, -u.y, u.x);

    vec3 l = normalize(vec3(1.5, 1., -0.5));
    l.xz = a * l.xz;
    l.xy = a * l.xy;

    return l;

}



vertex fxVertexOut vertexFunc(uint vertexID [[ vertex_id ]]
                              ,const device fxShaderVerts* in[[ buffer(0) ]]
                              ,texture2d<half> inputTex0 [[ texture(0) ]]
                              ,texture2d<half> inputTexMask [[ texture(1) ]]
                              ,constant fxGeneralUniforms& u[[ buffer(1) ]]
                              ,constant fxVars& vars[[ buffer(2)]])
{
    fxVertexOut out;

    out.normPos=in[vertexID].pos.xy*vec2(.5,-.5f)+vec2(.5,.5);
    out.position=in[vertexID].pos;
    out.texSize=float2(inputTex0.get_width(),inputTex0.get_height());
    out.tex1=in[vertexID].tex1;
    out.texMask=in[vertexID].texMask;
    return out;
}

fragment float4 fragmentFunc(fxVertexOut input [[stage_in]]
                             ,texture2d<half> inputTex [[ texture(0) ]]
                             ,texture2d<half> inputTexMask [[ texture(1) ]]
                             ,constant fxGeneralUniforms& u[[ buffer(0) ]]
                             ,constant fxVars& vars[[ buffer(1)]])
{
    // Angle (degrees) -> lOff rotation. lOff rotates by fsTime/2, so fsTime = 2 * (angle in radians).
    // 2 * (PI/180) = 0.0349065850398866. No radians() call (unsupported here).
    float fsTime = vars.angle * 0.0349065850398866;

    // Screen coordinates.
    vec2 uv = input.tex1;

    // Radial blur factors.
    // Controls the sample density, which in turn, controls the sample spread.
    float density = 0.5;
    // Sample weight. Decays as we radiate outwards.
    float weight = 0.1;

    // Static direction vector from the angle.
    vec3 l = lOff(fsTime);

    vec2 tuv =  uv - .5 - l.xy*.45;

    vec2 dTuv = tuv*density/vars.iterations;

    vec4 col = getColor(inputTex, uv.xy);
    col = col*0.25;

    // Jittering, to get rid of banding. fsTime is constant now, so the jitter is
    // stable frame-to-frame (no shimmer).
    uv += dTuv*(hash(uv.xy + fract(fsTime))*2. - 1.);

    for(float i=0.; i < vars.iterations; i++)
    {
        uv -= dTuv;
        vec4 c = getColor(inputTex, uv);
        col += c * weight;
        weight *= vars.decay;
    }

    col *= (1. - dot(tuv, tuv)*.75);

    vec4 blurColor = sqrt(smoothstep(0., 1., col));

    float4 outColor=getColor(inputTex,fsTexture);

    float blendValue2=u.blendValue*vars.blendValue;
#ifdef USE_MASK
    blendValue2*=getColor(inputTexMask,input.texMask).a;
#endif
    mixColor(outColor, outColor, blurColor, blendValue2);

    return outColor;
}
