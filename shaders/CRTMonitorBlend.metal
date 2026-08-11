#include "metalShaderTypes.h"
#include "alpha.h"
#include "blendModes.h"

typedef struct
{
    float strength;
    float pixelSize;
    float blendMode;
} fxVars;


vertex fxVertexOut vertexFunc(uint vertexID [[ vertex_id ]]
                              ,const device fxShaderVerts* in[[ buffer(0) ]]
                              ,texture2d<half> inputTex0 [[ texture(0) ]]
                              ,texture2d<half> inputTexMask [[ texture(1) ]]
                              ,constant fxGeneralUniforms& u[[ buffer(1) ]]
                              ,constant fxVars& vars[[ buffer(2)]])
{
    fxVertexOut out;

    out.normPos=in[vertexID].pos.xy*vec2(.5,.5f)+vec2(.5,.5);
    out.position=in[vertexID].pos;

    out.tex1=in[vertexID].tex1;
    out.texMask=in[vertexID].texMask;
    out.texSize=float2(inputTex0.get_width(),inputTex0.get_height());
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

    int psize=int(vars.pixelSize);
    float pixelSize=float(psize);
    vec2 cor;

    vec2 tmpTexture=input.tex1*input.texSize;
    cor.x =  tmpTexture.x/pixelSize;
    cor.y = (tmpTexture.y+pixelSize*1.5*mod(floor(cor.x),2.0))/(pixelSize*3.0);

    vec2 ico = floor( cor );
    vec2 fco = fract( cor );

    vec3 num=vec3(0.0,1.0,2.0) + ico.x;
    vec3 pix = step( 1.5, mod(num, vec3(3.0) ) );
    tmpTexture=pixelSize*ico*vec2(1.0,3.0);
    tmpTexture/=input.texSize;
    vec3 ima = getColor(inputTex, tmpTexture).rgb;

    vec3 col = pix*dot( pix, ima );

    col *= step( abs(fco.x-0.5), 0.4 );
    col *= step( abs(fco.y-0.5), 0.4 );

    col *= vars.strength;
    float4 outColor = vec4(col,texColor.a);

    float blendValue=u.blendValue;
#ifdef USE_MASK
    blendValue*=getColor(inputTexMask,input.texMask).a;
#endif
    int mode = int(vars.blendMode + 0.5);
    vec3 blended = applyBlend(mode, texColor.rgb, outColor.rgb);
    outColor.rgb = mix(texColor.rgb, blended, blendValue);
#ifdef PRE_MULT
    multiplyAlpha(outColor);
#endif
    return outColor;
}
