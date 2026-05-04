Shader "Custom/TestingShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        _ShadowColor("Shadow Color", Color) = (0.2, 0.2, 0.35, 1)
        [Header(Toon)]
        _ToonSteps("Toon Steps", float) = 3
        _StepSmoothness("Step Smoothness", float) = 0.02
        [Header(Specular)]
        _SpecularSteps("Specular Steps", float) = 2
        _SpecularSmoothness("Specular Smoothness", float) = 0.02
        //_SpecularStrength("Specular Strength", float) = 0.5
        [HDR] _SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
        _Gloss("Gloss", float) = 4

        [Header(Outline)]
        _OutlineColor("Outline Color", Color) = (0.05, 0.05, 0.1, 1)
        _OutlineWidth("Outline Width", float) = 0.03
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        // OUTLINE
        Pass
        {
            Name "Outline"
            //Cull Front // TODO: Uncomment and check others
            Tags { "LightMode" = "UniversalForward" }

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _OutlineColor;
            float _OutlineWidth;
            CBUFFER_END
        }

        // TOON
        Pass
        {
            Name "ToonForward"
            Tags { "LightMode" = "UniversalForward" }
            Cull Back // Default - Does not render the back faces

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
                float3 positionWS : TEXCOORD2;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float4 _ShadowColor;
                float _ToonSteps;
                float _StepSmoothness;
                float _SpecularSteps;
                float _SpecularSmoothness;
                float _Gloss;
                //float _SpecularStrength;
                float4 _SpecularColor;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            float ToonRamp(float value, float steps, float smoothness)
            {
                // The stepped increases in segments as value increases. The example below shows how value changes the stepped value
                // we assume step = 4
                // VALUE  STEPPED
                // 3.0  = 3
                // 3.1  = 3
                // 3.2  = 3
                // 3.25 = 3.25
                // 3.3  = 3.25
                // 3.4  = 3.25
                // 3.5  = 3.5
                // This just buckets a few values together so that we get some hard steps
                float stepped = floor(value * steps) / steps;
                // We get the next value by adding the segment to it
                float next    = stepped + (1.0 / steps);

                // Basically Smoothstep is 
                // float smoothstep(float edge0, float edge1, float x) 
                // {
                //   t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
                //   return t * t * (3.0 - 2.0 * t);
                // }
                // In the above function t denotes value of x between both the edges and is clamped between 0 and 1. For lerp we generally need t to be between 0 and 1.
                // The return value is hermite interpolation so smooth between 0 and 1
                // If the value of Smoothness is 0 then it Basically becomes a step function
                // t = step(next,value); <-- t = 1 if value > next and t = 0 if value < next
                // WHY IS IT IMPORTANT?
                // It helps to create that edge transition a bit smooth or hard. In the lerp equation we use this t value that we get from smoothstep. If smoothness is 0 then t value would be either 0 or 1 hence not interpolating between next and stepped value. But if smoothness is a bit high then t would have values between 0 and 1 and when the lerp function gets those values it interpolates between stepped and next hence giving a smooth feel
                // SIDENOTE
                // Don't keep smoothness to 0 otherwise you'll see jagged edges
                float t       = smoothstep(next - smoothness, next, value);
                return lerp(stepped, next, t);
            }

            float4 frag(Varyings IN) : SV_Target
            {
                //float4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;

                Light mainLight = GetMainLight();

                float3 N = normalize(IN.normal);
                float3 L = mainLight.direction;

                // Normal Diffuse - We don't have negative values
                //float diffuse = max(0, dot(N,L)); 

                // We *0.5 + 0.5 to elevate those negative values. 
                float diffuse = dot(N, L) * 0.5 + 0.5; // LAMBERT
                float toonDiff = ToonRamp(diffuse, _ToonSteps, _StepSmoothness);

                float3 color = mainLight.color * toonDiff;

                // SPECULAR LIGHT - BLINN - PHONG
                float3 view_Vector = normalize(GetWorldSpaceViewDir(IN.positionWS)); // GetWorldSpaceViewDir = _WorldSpaceCameraPos - IN.positionWS
                float3 half_Vector = normalize(view_Vector + L); // Vector between view and light vector
                float blinnPhong = max(0, dot(N,half_Vector));

                float specularLight = pow(blinnPhong, _Gloss);
                float toonSpec = ToonRamp(specularLight, _SpecularSteps, _SpecularSmoothness);
                float3 specColor = toonSpec * _SpecularColor;
                //return(toonSpec);
                return float4(color + specColor, 1.0);
            }
            ENDHLSL
        }
    }
}
