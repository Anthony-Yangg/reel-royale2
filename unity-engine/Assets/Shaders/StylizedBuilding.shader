// =================================================================================
// PokemonGo/StylizedBuilding
// Pastel-shaded extruded buildings with procedural window grid that lights
// up at night. Roof faces and walls share the shader but UV.y carries height
// so we can detect wall vs roof procedurally.
// =================================================================================
Shader "PokemonGo/StylizedBuilding"
{
    Properties
    {
        _BaseColor        ("Base Color",     Color) = (0.92, 0.90, 0.96, 1)
        _RoofColor        ("Roof Color",     Color) = (0.82, 0.84, 0.92, 1)
        _ShadowColor      ("Shadow Color",   Color) = (0.62, 0.62, 0.74, 1)
        _WindowColor      ("Window Color",   Color) = (1.0, 0.85, 0.55, 1)
        _WindowDensity    ("Window Density", Vector) = (0.5, 1.2, 0, 0)
        _WindowGlow       ("Window Glow",    Range(0, 4)) = 1.6
        _RimLightStrength ("Rim Light Strength", Range(0, 2)) = 0.6
        _CurvatureStrength("Curvature Strength", Range(0, 4)) = 1.0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry+5" }
        LOD 100

        Pass
        {
            Name "ForwardBuilding"
            Tags { "LightMode"="UniversalForward" }
            Cull Back

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "PoGoCommon.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 color      : COLOR;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 worldPos   : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float2 uv         : TEXCOORD2;
                float4 color      : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;
            float4 _RoofColor;
            float4 _ShadowColor;
            float4 _WindowColor;
            float4 _WindowDensity;
            float  _WindowGlow;
            float  _RimLightStrength;
            float  _CurvatureStrength;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                float3 wp = TransformObjectToWorld(IN.positionOS.xyz);
                wp = PoGoApplyCurvature(wp, _CurvatureStrength);
                OUT.worldPos = wp;
                OUT.positionCS = TransformWorldToHClip(wp);
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv         = IN.uv;
                OUT.color      = IN.color;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Roofs face up. Distinguish via normal.y to apply roof tint.
                float roofMask = saturate(IN.normalWS.y - 0.5) * 2.0;
                float3 baseCol = lerp(_BaseColor.rgb, _RoofColor.rgb, roofMask) * IN.color.rgb;

                // Procedural window grid on walls. UV.x is around perimeter,
                // UV.y is wall height in meters.
                float2 cell = float2(IN.uv.x * _WindowDensity.x, IN.uv.y * _WindowDensity.y);
                float2 cellId = floor(cell);
                float2 cellUv = frac(cell);
                float windowMask =
                    step(0.15, cellUv.x) * step(cellUv.x, 0.85) *
                    step(0.15, cellUv.y) * step(cellUv.y, 0.85);

                // Random per-cell on/off + flicker.
                float r = PoGoHash21(cellId);
                windowMask *= step(0.45, r);
                windowMask *= 0.65 + 0.35 * sin(_Time.y * 0.5 + r * 6.28);
                windowMask *= (1.0 - roofMask); // walls only

                float3 lit = PoGoWrapLambert(IN.normalWS, baseCol);

                // Subtle rim light to read silhouettes against atmosphere.
                float3 V = normalize(GetCameraPositionWS() - IN.worldPos);
                float rim = pow(1.0 - saturate(dot(V, IN.normalWS)), 3.0);
                lit += rim * _RimLightStrength * _PoGo_SunColor.rgb * 0.5;

                // Night window glow.
                float night = PoGoNightFactor();
                lit += _WindowColor.rgb * windowMask * _WindowGlow * night;

                lit = PoGoApplyFog(lit, IN.worldPos);
                return half4(lit, 1.0);
            }
            ENDHLSL
        }
    }
}
