// =================================================================================
// PokemonGo/AtmosphereSkydome
// Inside-facing sky dome rendered after geometry. Draws a vertical gradient
// from _PoGo_SkyHorizon up to _PoGo_SkyTop with subtle banding to fake
// volumetric depth. Stars appear at night based on PoGoNightFactor().
// =================================================================================
Shader "PokemonGo/AtmosphereSkydome"
{
    Properties { }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Background" "Queue"="Background" }
        Pass
        {
            Name "Sky"
            Tags { "LightMode"="UniversalForward" }
            ZWrite Off
            Cull Front
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "PoGoCommon.hlsl"

            struct A { float4 pos : POSITION; float3 nrm : NORMAL; };
            struct V { float4 pos : SV_POSITION; float3 dir : TEXCOORD0; };

            V vert(A IN)
            {
                V OUT;
                OUT.pos = TransformObjectToHClip(IN.pos.xyz);
                OUT.dir = normalize(IN.pos.xyz);
                return OUT;
            }

            half4 frag(V IN) : SV_Target
            {
                float h = saturate(IN.dir.y * 0.5 + 0.5);
                float3 sky = lerp(_PoGo_SkyHorizon.rgb, _PoGo_SkyTop.rgb, smoothstep(0.05, 0.9, h));

                // Sun disk.
                float3 L = normalize(_PoGo_SunDir.xyz);
                float sun = pow(saturate(dot(IN.dir, -L)), 256.0);
                sky += _PoGo_SunColor.rgb * sun * 1.4;

                // Stars at night.
                float night = PoGoNightFactor();
                float2 sUV = IN.dir.xz / max(IN.dir.y, 0.1);
                float star = step(0.998, PoGoHash21(floor(sUV * 80.0)));
                sky += star * night * 0.8;

                return half4(sky, 1);
            }
            ENDHLSL
        }
    }
}
