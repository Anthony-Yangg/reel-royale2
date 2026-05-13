// =================================================================================
// PokemonGo/EmissiveRoad
// Roads with subtle vertex-color tint, soft edge fade and a night-time
// emissive sodium glow. Vertex color comes from RoadMeshGenerator and
// encodes the road class tint. UV.x is across (0=left edge, 1=right edge),
// UV.y is along the ribbon so we can fade dashes / texture along length.
// =================================================================================
Shader "PokemonGo/EmissiveRoad"
{
    Properties
    {
        _BaseColor       ("Base Color", Color) = (1, 0.95, 0.82, 1)
        _EdgeColor       ("Edge Color", Color) = (0.85, 0.78, 0.65, 1)
        _EdgeWidth       ("Edge Width", Range(0, 0.5)) = 0.18
        _NightColor      ("Night Emissive Color", Color) = (1.0, 0.85, 0.55, 1)
        _NightIntensity  ("Night Intensity", Range(0, 4)) = 1.4
        _CenterStripe    ("Center Stripe Intensity", Range(0, 1)) = 0.35
        _CurvatureStrength("Curvature Strength", Range(0, 4)) = 1.0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry+1" }
        LOD 100

        Pass
        {
            Name "ForwardRoad"
            Tags { "LightMode"="UniversalForward" }
            Cull Back
            Offset -1, -1

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
            float4 _EdgeColor;
            float  _EdgeWidth;
            float4 _NightColor;
            float  _NightIntensity;
            float  _CenterStripe;
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
                float across = abs(IN.uv.x - 0.5) * 2.0; // 0=center, 1=edge
                float edgeMask = smoothstep(1.0 - _EdgeWidth, 1.0, across);

                float3 baseCol = _BaseColor.rgb * IN.color.rgb;
                float3 col = lerp(baseCol, _EdgeColor.rgb * IN.color.rgb, edgeMask);

                // Center dashed stripe based on length (uv.y).
                float dash = step(0.5, frac(IN.uv.y));
                float centerMask = (1.0 - smoothstep(0.0, 0.06, across)) * dash;
                col += centerMask * _CenterStripe;

                col = PoGoWrapLambert(IN.normalWS, col);

                // Emissive night glow (lights up roads at night).
                float night = PoGoNightFactor();
                float3 emissive = _NightColor.rgb * _NightIntensity * night;
                col += emissive * (1.0 - edgeMask * 0.5);

                col = PoGoApplyFog(col, IN.worldPos);
                return half4(col, 1.0);
            }
            ENDHLSL
        }
    }
}
