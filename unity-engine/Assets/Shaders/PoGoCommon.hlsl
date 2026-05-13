// =================================================================================
// PoGoCommon.hlsl
// Shared HLSL helpers for the Pokémon-GO-style stylized terrain shader suite.
// Every custom shader (water, road, building, terrain) includes this file.
//
// The atmosphere service (AtmosphereService.cs) pushes these global params:
//   _PoGo_SunDir       float3   sun direction in world space (towards light)
//   _PoGo_SunColor     float3
//   _PoGo_AmbientColor float3
//   _PoGo_FogColor     float3
//   _PoGo_FogParams    float4   (start, end, density, exponent)
//   _PoGo_SkyTop       float3
//   _PoGo_SkyHorizon   float3
//   _PoGo_NightGlow    float    0..1 emissive boost for nighttime
//   _PoGo_TimeOfDay    float    0..1 (0 = midnight, 0.5 = noon)
//   _PoGo_WorldOrigin  float3
//
// Curvature: every vertex is bent downwards proportional to the squared
// planar distance from the camera anchor, giving the world the signature
// soft "globe horizon" look without actually projecting onto a sphere.
// =================================================================================
#ifndef POKEMON_GO_COMMON_HLSL_INCLUDED
#define POKEMON_GO_COMMON_HLSL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

CBUFFER_START(PoGoGlobals)
float4 _PoGo_SunDir;
float4 _PoGo_SunColor;
float4 _PoGo_AmbientColor;
float4 _PoGo_FogColor;
float4 _PoGo_FogParams;
float4 _PoGo_SkyTop;
float4 _PoGo_SkyHorizon;
float  _PoGo_NightGlow;
float  _PoGo_TimeOfDay;
float4 _PoGo_WorldOrigin;
CBUFFER_END

// World curvature: bend the world downwards quadratically with planar distance.
// We expose strength as a per-material property so artists can vary it.
float3 PoGoApplyCurvature(float3 worldPos, float strength)
{
    float2 d = worldPos.xz - _PoGo_WorldOrigin.xz;
    float dist2 = dot(d, d);
    worldPos.y -= dist2 * strength * 0.000004; // tuned for visible-only at distance
    return worldPos;
}

// Soft "wrap" lambert lighting biased to a brighter ambient base; gives the
// matte stylized terrain look without flat shading.
float3 PoGoWrapLambert(float3 normal, float3 baseColor)
{
    float3 L = normalize(_PoGo_SunDir.xyz);
    float nDotL = saturate(dot(normalize(normal), -L) * 0.6 + 0.4);
    float3 diff = baseColor * (_PoGo_SunColor.rgb * nDotL + _PoGo_AmbientColor.rgb);
    return diff;
}

// Exponential height fog that tints distant geometry into the sky color and
// fades the geometry's edge transitions cleanly.
float3 PoGoApplyFog(float3 color, float3 worldPos)
{
    float3 cam = GetCameraPositionWS();
    float d = distance(worldPos, cam);
    float t = saturate((d - _PoGo_FogParams.x) / max(_PoGo_FogParams.y - _PoGo_FogParams.x, 0.001));
    float f = 1.0 - exp(-pow(t, _PoGo_FogParams.w) * _PoGo_FogParams.z);
    return lerp(color, _PoGo_FogColor.rgb, saturate(f));
}

// Procedural emissive nighttime mask. Higher at night, zero at noon.
float PoGoNightFactor() { return saturate(_PoGo_NightGlow); }

// Simple noise/hash helpers used by water shader.
float PoGoHash11(float p) { p = frac(p * 0.1031); p *= p + 33.33; p *= p + p; return frac(p); }
float PoGoHash21(float2 p) { p = frac(p * float2(0.1031, 0.103)); p += dot(p, p.yx + 33.33); return frac((p.x + p.y) * p.x); }
float PoGoValueNoise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float a = PoGoHash21(i);
    float b = PoGoHash21(i + float2(1, 0));
    float c = PoGoHash21(i + float2(0, 1));
    float d = PoGoHash21(i + float2(1, 1));
    float2 u = f * f * (3.0 - 2.0 * f);
    return lerp(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

#endif // POKEMON_GO_COMMON_HLSL_INCLUDED
