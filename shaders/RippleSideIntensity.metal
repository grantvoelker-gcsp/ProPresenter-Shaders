#include "metalShaderTypes.h"
#include "alpha.h"

// Ripple Side with an Intensity control that scales the ripple displacement.
// Intensity 1.0 == stock; 0.0 == no ripple.
typedef struct
{
    float speed;
    float intensity;
} fxVars;


constant float PI = 3.1415926535897932;

//speed
constant float speed = 0.2;
constant float speed_x = 0.3;
constant float speed_y = 0.3;

// geometry
constant float intensity = 3.;
constant int steps = 8;
constant float frequency = 4.0;
constant int angle = 7; // better when a prime

// reflection and emboss
constant float delta = 20.;
constant float intence = 400.;
constant float emboss = 0.3;

//---------- crystals effect

float col(vec2 coord,float fsTime)
{
    float delta_theta = 2.0 * PI / float(angle);
    float col = 0.0;
    float theta = 0.0;

    for (int i = 0; i < steps; i++)
    {
        vec2 adjc = coord;
        theta = delta_theta*float(i);
        adjc.x += cos(theta)*fsTime*speed + fsTime * speed_x;
        adjc.y -= sin(theta)*fsTime*speed - fsTime * speed_y;
        col = col + cos( (adjc.x*cos(theta) - adjc.y*sin(theta))*frequency)*intensity;
    }

    return cos(col);
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

    vec2 c1 = input.tex1;
    vec2 c2 = input.tex1;
    float cc1 = col(c1,fsTime);

    c2.x += 64.0;
    float dx = emboss*(cc1-col(c2,fsTime))/delta;

    c2.x = input.tex1.x;
    c2.y += 39.0;
    float dy = emboss*(cc1-col(c2,fsTime))/delta;

    // Scale the ripple displacement by the Intensity control.
    dx *= vars.intensity;
    dy *= vars.intensity;

    c1.x += dx;
    c1.y += dy;
    //  c1.y = -c1.y;

    float alpha = 1.+dot(vec2(dx),vec2(dy))*intence;

    //    vec2 uv=clamp(c1,vec2(0.0,0.0),vec2(1.0,1.0))*fsTextureSize;
    vec2 uv=c1;

    vec4 texel=getColor(inputTex,fsTexture);
    vec4 texColor=getColor(inputTex,uv);

#ifdef PRE_MULT
    divideAlpha(texColor);
#endif
    float4 outColor;
    outColor.rgb = texColor.rgb * alpha;
    outColor.a = texColor.a;
#ifdef PRE_MULT
    multiplyAlpha(outColor);
#endif

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif
    mixColor(outColor, texel, outColor, blendValue);

    return outColor;
}
