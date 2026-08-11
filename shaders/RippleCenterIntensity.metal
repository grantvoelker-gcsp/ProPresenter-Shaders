#include "metalShaderTypes.h"
#include "alpha.h"

// Ripple Center with an Intensity control that scales the ripple amplitude.
// Intensity 1.0 == stock (0.03 displacement); 0.0 == no ripple.
typedef struct
{
    float speed;
    float intensity;
} fxVars;


// 2x1 hash. Used to jitter the samples.
float hash( vec2 p ){ return fract(sin(dot(p, vec2(41, 289)))*45758.5453); }


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

    out.normPos=in[vertexID].pos.xy*vec2(.5,-.5f);//+vec2(.5,.5);
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
    float fsTime=u.localTime*vars.speed;

    float cLength = length(input.normPos.xy);

    vec2 uv=input.tex1+(input.normPos.xy/cLength)*cos(cLength*12.0-fsTime*4.0)*0.03*vars.intensity;

    vec4 texel=getColor(inputTex,fsTexture);
    float4 outColor=getColor(inputTex,uv);

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue*=getColor(inputTexMask,input.texMask).a;
#endif
    mixColor(outColor, texel, outColor, blendValue);

    return outColor;
}
