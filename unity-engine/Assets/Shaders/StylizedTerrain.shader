// =================================================================================
// PokemonGo/StylizedTerrain
// Wraps the URP Lit pipeline with vertex-color tint, world curvature, soft
// wrap-lambert lighting, and global Pokémon-GO atmosphere fog. Used for the
// terrain base plane, parks, landuse and any flat fill.
// =================================================================================
Shader "PokemonGo/StylizedTerrain"
{
    Properties
    {
        _BaseColor       ("Base Color", Color) = (0.86, 0.92, 0.78, 1)
        _Saturation      ("Saturation", Range(0, 2)) = 1.05
        _CurvatureStrength("Curvature Strength", Range(0, 4)) = 1.0
        _EdgeSoftness    ("Edge Softness", Range(0, 1)) = 0.35
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Cull Back
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma target 3.0
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
                float4 color      : COLOR;
                float2 uv         : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;
            float  _Saturation;
            float  _CurvatureStrength;
            float  _EdgeSoftness;
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
                OUT.color      = IN.color;
                OUT.uv         = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                float3 baseCol = _BaseColor.rgb * IN.color.rgb;

                // Tiny per-tile micro variation to break up flat fills.
                float n = PoGoValueNoise(IN.uv * 32.0) * 0.06 - 0.03;
                baseCol = saturate(baseCol + n.xxx);

                // Soft wrap-lambert with global atmosphere.
                float3 lit = PoGoWrapLambert(IN.normalWS, baseCol);

                // Saturation push for Pokémon-GO pastel look.
                float lum = dot(lit, float3(0.299, 0.587, 0.114));
                lit = lerp(lum.xxx, lit, _Saturation);

                // Atmospheric fog blend.
                lit = PoGoApplyFog(lit, IN.worldPos);
                return half4(lit, 1.0);
            }
            ENDHLSL
        }
    }
}
