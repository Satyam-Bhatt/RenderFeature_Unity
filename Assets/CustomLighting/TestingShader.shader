Shader "Custom/TestingShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        _ShadowColor("Shadow Color", Color) = (0.2, 0.2, 0.35, 1)
        _ToonSteps("Toon Steps", Range(1, 8)) = 3
        _StepSmoothness("Step Smoothness", Range(0.00, 0.2)) = 0.02
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float4 _ShadowColor;
                float _ToonSteps;
                float _StepSmoothness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                return OUT;
            }

            float ToonRamp(float value, float steps, float smoothness)
            {
                // The stepped increases in segments as value increases. The example below shows how value changes the stepped value
                // step = 4
                // VALUE  STEPPED
                // 3.0  = 3
                // 3.1  = 3
                // 3.2  = 3
                // 3.25 = 3.25
                // 3.3  = 3.25
                // 3.4  = 3.25
                // 2.5  = 3.5
                float stepped = floor(value * steps) / steps;
                float next    = stepped + (1.0 / steps);
                //float t       = smoothstep(next - smoothness, next, value);
                float t = clamp((value - (next - smoothness)) / (next - (next - smoothness)), 0.0, 1.0);
                // t = step(next,value); // If smoothness is 0 then above line becomes this. t = 1 if value > next and t = 0 if value < next
                return lerp(stepped, next, t);
            }

            float4 frag(Varyings IN) : SV_Target
            {
                //float4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;

                Light mainLight = GetMainLight();

                float3 N = IN.normal;
                float3 L = mainLight.direction;

                // Normal Diffuse - We don't have negative values
                //float diffuse = max(0, dot(N,L)); 

                // We *0.5 + 0.5 to elevate those negative values. 
                float diffuse = dot(N, L) * 0.5 + 0.5;
                float toonDiff = ToonRamp(diffuse, _ToonSteps, _StepSmoothness);

                float3 color = mainLight.color * toonDiff;

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
