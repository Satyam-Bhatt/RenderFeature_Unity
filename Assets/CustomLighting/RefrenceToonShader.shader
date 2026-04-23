Shader "Custom/ToonShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        [Header(Toon)]
        _AmbientColor("Ambient Color", Color) = (0.1, 0.1, 0.2, 1)
        _ShadowColor("Shadow Color", Color) = (0.2, 0.2, 0.35, 1)
        _ToonSteps("Toon Steps", Range(1, 8)) = 3
        _StepSmoothness("Step Smoothness", Range(0.001, 0.2)) = 0.02

        [Header(Rim)]
        _RimColor("Rim Color", Color) = (0.8, 0.9, 1.0, 1)
        _RimPower("Rim Power", Range(0.5, 8.0)) = 3.0
        _RimThreshold("Rim Threshold", Range(0.0, 1.0)) = 0.6
        _RimSmoothness("Rim Smoothness", Range(0.001, 0.2)) = 0.05

        [Header(Outline)]
        _OutlineColor("Outline Color", Color) = (0.05, 0.05, 0.1, 1)
        _OutlineWidth("Outline Width", Range(0.0, 0.1)) = 0.03
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        // ── Pass 1: Outline ─────────────────────────────────────────────────
        Pass
        {
            Name "Outline"
            Cull Front

            HLSLPROGRAM
            #pragma vertex vertOutline
            #pragma fragment fragOutline

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                half4 _AmbientColor;
                half4 _ShadowColor;
                float _ToonSteps;
                float _StepSmoothness;
                half4 _RimColor;
                float _RimPower;
                float _RimThreshold;
                float _RimSmoothness;
                half4 _OutlineColor;
                float _OutlineWidth;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
            struct Varyings   { float4 positionHCS : SV_POSITION; };

            Varyings vertOutline(Attributes IN)
            {
                Varyings OUT;
                float3 posWS  = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normWS = TransformObjectToWorldNormal(IN.normalOS);
                posWS += normWS * _OutlineWidth;
                OUT.positionHCS = TransformWorldToHClip(posWS);
                return OUT;
            }

            half4 fragOutline(Varyings IN) : SV_Target { return _OutlineColor; }
            ENDHLSL
        }

        // ── Pass 2: Toon Lit ────────────────────────────────────────────────
        Pass
        {
            Name "ToonForward"
            Tags { "LightMode" = "UniversalForward" }
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Shadow receiving keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                half4 _AmbientColor;
                half4 _ShadowColor;
                float _ToonSteps;
                float _StepSmoothness;
                half4 _RimColor;
                float _RimPower;
                float _RimThreshold;
                float _RimSmoothness;
                half4 _OutlineColor;
                float _OutlineWidth;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float3 positionWS  : TEXCOORD2;
                // Stores the shadow map lookup coords
                float4 shadowCoord : TEXCOORD3;
            };

            float ToonRamp(float value, float steps, float smoothness)
            {
                float stepped = floor(value * steps) / steps;
                float next    = stepped + (1.0 / steps);
                float t       = smoothstep(next - smoothness, next, value);
                return lerp(stepped, next, t);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv          = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.normalWS    = TransformObjectToWorldNormal(IN.normalOS);
                OUT.positionWS  = TransformObjectToWorld(IN.positionOS.xyz);

                // Compute shadow coord from world position
                OUT.shadowCoord = TransformWorldToShadowCoord(OUT.positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 texColor  = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half4 baseColor = texColor * _BaseColor;

                float3 N = normalize(IN.normalWS);

                // Pass shadow coord into GetMainLight so it samples the shadow map
                Light mainLight = GetMainLight(IN.shadowCoord);
                float3 L = normalize(mainLight.direction);

                float NdotL    = dot(N, L) * 0.5 + 0.5;
                float toonDiff = ToonRamp(NdotL, _ToonSteps, _StepSmoothness);

                // Multiply toon diffuse by shadowAttenuation (0 = fully shadowed)
                toonDiff *= mainLight.shadowAttenuation;

                half3 diffuse = lerp(_ShadowColor.rgb, mainLight.color, toonDiff);

                float3 V      = normalize(GetCameraPositionWS() - IN.positionWS);
                float  NdotV  = 1.0 - saturate(dot(N, V));
                float  rimVal = pow(NdotV, _RimPower);
                float  rimMask = smoothstep(
                    _RimThreshold - _RimSmoothness,
                    _RimThreshold + _RimSmoothness,
                    NdotL
                );
                half3 rim = _RimColor.rgb * step(_RimThreshold, rimVal) * rimMask;

                half3 ambient    = _AmbientColor.rgb;
                half3 finalColor = baseColor.rgb * (ambient + diffuse) + rim;

                return half4(finalColor, baseColor.a);
            }
            ENDHLSL
        }
    }
}