// Copyright (c) Community mod. Traditional blend modes for ProPresenter Inspector filters.
// b = backdrop (original incoming pixel), s = source (effect result). Straight-alpha, 0..1 RGB.
#ifndef BlendModes_h
#define BlendModes_h

#if __METAL__ || __METAL_MACOS__ || __METAL_IOS__
#include <metal_stdlib>
using namespace metal;
#endif

inline float3 bmOverlay(float3 b, float3 s)
{
    float3 lo = 2.0 * b * s;
    float3 hi = 1.0 - 2.0 * (1.0 - b) * (1.0 - s);
    return mix(lo, hi, step(float3(0.5), b));
}

inline float3 bmSoftLight(float3 b, float3 s)
{
    float3 d = mix(2.0 * b * s + b * b * (1.0 - 2.0 * s),
                   sqrt(b) * (2.0 * s - 1.0) + 2.0 * b * (1.0 - s),
                   step(float3(0.5), s));
    return d;
}

// mode selector; b = backdrop, s = effect layer.
inline float3 applyBlend(int mode, float3 b, float3 s)
{
    s = saturate(s);   // effect layers (e.g. Dots) can exceed 1
    b = saturate(b);
    switch (mode)
    {
        case 1:  return b * s;                                   // Multiply
        case 2:  return b + s - b * s;                           // Screen
        case 3:  return bmOverlay(b, s);                         // Overlay
        case 4:  return min(b, s);                               // Darken
        case 5:  return max(b, s);                               // Lighten
        case 6:  return abs(b - s);                              // Difference
        case 7:  return b + s - 2.0 * b * s;                     // Exclusion
        case 8:  return saturate(b + s);                         // Add / Linear Dodge
        case 9:  return saturate(b - s);                         // Subtract
        case 10: return bmOverlay(s, b);                         // Hard Light
        case 11: return bmSoftLight(b, s);                       // Soft Light
        case 12: {                                               // Color Dodge
            float3 cd = saturate(b / max(float3(1.0) - s, float3(1e-5)));
            return select(cd, float3(1.0), s >= float3(1.0));
        }
        case 13: {                                               // Color Burn
            float3 cb = 1.0 - saturate((float3(1.0) - b) / max(s, float3(1e-5)));
            return select(cb, float3(0.0), s <= float3(0.0));
        }
        default: return s;                                       // 0 = Normal
    }
}

#endif  // BlendModes_h
