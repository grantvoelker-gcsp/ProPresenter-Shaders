#include "metalShaderTypes.h"
#include "alpha.h"

// Sheen shimmer: an animated fractal-noise (fbm) highlight that drifts along a
// given Angle at a Speed, masked by the layer's alpha and added over the image
// (clips to white for glints). Uses 3D value noise with time as the third axis, so
// the pattern morphs/evolves over time rather than only translating. Scale sets the
// shimmer size. Robust hashing, no sin-hash, no radians.
typedef struct
{
    float angle;       // direction the shimmer moves (degrees)
    float speed;       // drift + morph speed
    float intensity;   // sheen brightness
    float scale;       // shimmer size (frequency)
} fxVars;

float hash31(vec3 p3){ p3 = fract(p3 * 0.1031); p3 += dot(p3, p3.zyx + 31.32); return fract((p3.x + p3.y) * p3.z); }

float vnoise3(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 uu = f * f * (3.0 - 2.0 * f);
    float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
    float nx00 = mix(n000, n100, uu.x);
    float nx10 = mix(n010, n110, uu.x);
    float nx01 = mix(n001, n101, uu.x);
    float nx11 = mix(n011, n111, uu.x);
    return mix(mix(nx00, nx10, uu.y), mix(nx01, nx11, uu.y), uu.z);
}

float fbm3(vec3 p)
{
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++)
    {
        v += amp * vnoise3(p);
        p = p * 2.0 + vec3(37.0, 17.0, 7.0);   // scale + offset each octave
        amp *= 0.5;
    }
    return v;
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

    float aspect = input.texSize.x / max(input.texSize.y, 1.0);
    vec2 c = fsTexture - 0.5;
    c.x *= aspect;

    float ang = vars.angle * 0.0174532925199433;
    vec2 dir = vec2(cos(ang), sin(ang));
    vec2 perp = vec2(-dir.y, dir.x);
    float along = dot(c, dir);
    float across = dot(c, perp);

    float sc = max(vars.scale, 0.1);
    float tm = u.globalTime;
    // x = scroll along the direction; y = streak-stretched across; z = time -> morph.
    vec3 nc = vec3(along * sc + tm * vars.speed, across * sc * 0.4, tm * vars.speed * 0.5);

    float n = fbm3(nc);
    float sheen = smoothstep(0.45, 0.85, n);   // sparse bright glints
    sheen *= texColor.a;                        // mask by the layer's alpha

    vec3 lit = saturate(texColor.rgb + sheen * vars.intensity);

    float blendValue = u.blendValue;
#ifdef USE_MASK
    blendValue *= getColor(inputTexMask, input.texMask).a;
#endif

    float4 outColor;
    outColor.rgb = mix(texColor.rgb, lit, blendValue);
    outColor.a   = texColor.a;
#ifdef PRE_MULT
    multiplyAlpha(outColor);
#endif
    return outColor;
}
