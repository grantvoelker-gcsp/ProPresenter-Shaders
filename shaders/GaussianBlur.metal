#include "metalShaderTypes.h"

// True Gaussian blur. Same 2-pass separable structure as the stock Blur (which is
// known-good), but the 15 taps are weighted with a Gaussian kernel (sigma ~3)
// instead of the stock's uniform 1/15 average -- that uniform average is a box
// blur, which is why the stock one looks flat/hard. Pass 0 = horizontal, pass 1 =
// vertical; each pass reads the previous pass output.
typedef struct
{
    float blurAmount;
} fxVars;

typedef struct
{
    float4 position [[position]];
    float2 tex1;
    float2 texMask;
    float2 normPos;
    float2 texSize;
    float2 texCoords0;
    float2 texCoords1;
    float2 texCoords2;
    float2 texCoords3;
    float2 texCoords4;
    float2 texCoords5;
    float2 texCoords6;
    float2 texCoords7;
    float2 texCoords8;
    float2 texCoords9;
    float2 texCoords10;
    float2 texCoords11;
    float2 texCoords12;
    float2 texCoords13;
    float2 texCoords14;
} fsVertexOut;

vertex fsVertexOut vertexFunc(uint vertexID [[ vertex_id ]]
                              ,const device fxShaderVerts* in[[ buffer(0) ]]
                              ,texture2d<half> inputTex0 [[ texture(0) ]]
                              ,texture2d<half> inputTexMask [[ texture(1) ]]
                              ,constant fxGeneralUniforms& u[[ buffer(1) ]]
                              ,constant fxVars& vars[[ buffer(2)]])
{
    fsVertexOut out;

    out.normPos=in[vertexID].pos.xy*vec2(.5,.5f)+vec2(.5,.5);
    out.position=in[vertexID].pos;

    out.tex1=in[vertexID].tex1;
    out.texMask=in[vertexID].texMask;
    out.texSize=float2(inputTex0.get_width(),inputTex0.get_height());

    float fsScale=vars.blurAmount*3.0;
    if(fsScale==0.0)
        fsScale=0.1;

    float2 direction;
    float pass=u.pass;
    if(pass>1)
        pass-=2;
    if(pass==0)
    {
        direction=vec2((fsScale+fsScale*.5)/out.texSize.x,0.0);
    }
    else
    {
        direction=vec2(0.0,(fsScale+fsScale*.5)/out.texSize.y);
    }

    out.texCoords0 = in[vertexID].tex1 + vec2(-7.0,-7.0)*direction;
    out.texCoords1 = in[vertexID].tex1 + vec2(-6.0,-6.0)*direction;
    out.texCoords2 = in[vertexID].tex1 + vec2(-5.0,-5.0)*direction;
    out.texCoords3 = in[vertexID].tex1 + vec2(-4.0,-4.0)*direction;
    out.texCoords4 = in[vertexID].tex1 + vec2(-3.0,-3.0)*direction;
    out.texCoords5 = in[vertexID].tex1 + vec2(-2.0,-2.0)*direction;
    out.texCoords6 = in[vertexID].tex1 + vec2(-1.0,-1.0)*direction;
    out.texCoords7 = in[vertexID].tex1 + vec2( 1.0, 1.0)*direction;
    out.texCoords8 = in[vertexID].tex1 + vec2( 2.0, 2.0)*direction;
    out.texCoords9 = in[vertexID].tex1 + vec2( 3.0, 3.0)*direction;
    out.texCoords10 = in[vertexID].tex1 + vec2( 4.0, 4.0)*direction;
    out.texCoords11 = in[vertexID].tex1 + vec2( 5.0, 5.0)*direction;
    out.texCoords12 = in[vertexID].tex1 + vec2( 6.0, 6.0)*direction;
    out.texCoords13 = in[vertexID].tex1 + vec2( 7.0, 7.0)*direction;
    out.texCoords14 = in[vertexID].tex1;
    return out;
}

constexpr sampler blurSampler(
                              mip_filter::nearest, mag_filter::linear, min_filter::linear, s_address::clamp_to_edge, t_address::clamp_to_edge);

#define getTexture(a,b) float4(a.sample(blurSampler,b))

fragment float4 fragmentFunc(fsVertexOut input [[stage_in]]
                             ,texture2d<half> inputTex [[ texture(0) ]]
                             ,texture2d<half> inputTexMask [[ texture(1) ]]
                             ,constant fxGeneralUniforms& u[[ buffer(0) ]]
                             ,constant fxVars& vars[[ buffer(1)]])
{
    vec4 texel = getColor(inputTex, fsTexture);

    // Normalized Gaussian weights (sigma ~3) for taps at offsets -7..+7; sum ~= 1.
    float4 outColor = vec4(0.0);
    outColor += getTexture(inputTex, input.texCoords0)  * 0.008860;  // -7
    outColor += getTexture(inputTex, input.texCoords1)  * 0.018158;  // -6
    outColor += getTexture(inputTex, input.texCoords2)  * 0.033522;  // -5
    outColor += getTexture(inputTex, input.texCoords3)  * 0.055344;  // -4
    outColor += getTexture(inputTex, input.texCoords4)  * 0.081720;  // -3
    outColor += getTexture(inputTex, input.texCoords5)  * 0.107798;  // -2
    outColor += getTexture(inputTex, input.texCoords6)  * 0.127315;  // -1
    outColor += getTexture(inputTex, input.texCoords14) * 0.134598;  //  0
    outColor += getTexture(inputTex, input.texCoords7)  * 0.127315;  // +1
    outColor += getTexture(inputTex, input.texCoords8)  * 0.107798;  // +2
    outColor += getTexture(inputTex, input.texCoords9)  * 0.081720;  // +3
    outColor += getTexture(inputTex, input.texCoords10) * 0.055344;  // +4
    outColor += getTexture(inputTex, input.texCoords11) * 0.033522;  // +5
    outColor += getTexture(inputTex, input.texCoords12) * 0.018158;  // +6
    outColor += getTexture(inputTex, input.texCoords13) * 0.008860;  // +7

    float blendValue=u.blendValue;
#ifdef USE_MASK
    blendValue*=float(inputTexMask.sample(linearSampler, input.texMask).a);
#endif
    outColor = mix(texel, outColor, blendValue);
    return outColor;
}
