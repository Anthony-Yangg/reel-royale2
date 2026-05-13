// =================================================================================
// PokemonGo/StylizedWater
// Animated stylized water: scrolling caustics, foam edge breakup,
// emissive shimmer at night, depth-based color gradient. Pure procedural
// — no textures required so it works out of the box and stays mobile-cheap.
// =================================================================================
Shader "PokemonGo/StylizedWater"
{
    Properties
    {
        _ShallowColor     ("Shallow Color", Color) = (0.65, 0.88, 0.97, 1)
        _DeepColor        ("Deep Color",    Color) = (0.20, 0.42, 0.70, 1)
        _FoamColor        ("Foam Color",    Color) = (1, 1, 1, 1)
        _CausticsStrength ("Caustics Strength", Range(0, 1)) = 0.6
        _FoamWidth        ("Foam Width",    Range(0, 1)) = 0.18
        _ScrollSpeed      ("Scroll Speed",  Vector) = (0.04, 0.025, 0, 0)
        _CurvatureStrength("Curvature Strength", Range(0, 4)) = 1.0
        _NightEmissive    ("Night Emissive", Color) = (0.25, 0.45, 0.85, 1)
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Geometry+10" }
        LOD 100

        Pass
        {
            Name "ForwardWater"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target 3.0
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
            float4 _ShallowColor;
            float4 _DeepColor;
            float4 _FoamColor;
            float  _CausticsStrength;
            float  _FoamWidth;
            float4 _ScrollSpeed;
            float  _CurvatureStrength;
            float4 _NightEmissive;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                float3 wp = TransformObjectToWorld(IN.positionOS.xyz);

                // Animate wave height subtly.
                float t = _Time.y;
                float wave = sin(wp.x * 0.05 + t * 0.7) * 0.04 +
                             cos(wp.z * 0.07 + t * 0.5) * 0.04;
                wp.y += wave;
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
                float t = _Time.y;
                float2 uv = IN.worldPos.xz * 0.04;

                // Two scrolling noise samples for caustics.
                float n1 = PoGoValueNoise(uv * 1.2 + _ScrollSpeed.xy * t);
                float n2 = PoGoValueNoise(uv * 2.4 - _ScrollSpeed.xy * t * 0.5);
                float caustics = pow(saturate(n1 * n2 * 2.0), 1.5) * _CausticsStrength;

                // Depth proxy: vertex color alpha encodes depth in builder.
                float depth = saturate(1.0 - IN.color.a);
                float3 baseCol = lerp(_DeepColor.rgb, _ShallowColor.rgb, depth);

                // Foam at low depth (shore).
                float foam = smoothstep(1.0 - _FoamWidth, 1.0, depth + caustics * 0.4);
                float3 col = lerp(baseCol, _FoamColor.rgb, foam);

                // Sun shimmer.
                float3 V = normalize(GetCameraPositionWS() - IN.worldPos);
                float3 H = normalize(V + normalize(-_PoGo_SunDir.xyz));
                float spec = pow(saturate(dot(IN.normalWS, H)), 80.0) * 0.7;
                col += spec * _PoGo_SunColor.rgb;

                col += caustics * 0.4;

                // Night emissive shimmer.
                float night = PoGoNightFactor();
                col += _NightEmissive.rgb * night * (0.4 + 0.4 * sin(uv.x * 3.0 + t));

                col = PoGoApplyFog(col, IN.worldPos);
                return half4(col, 0.95);
            }
            ENDHLSL
        }
    }
}
