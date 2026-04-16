Shader "Custom/ColoredShadowLit"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _ShadowColor("Shadow Color", Color) = (1, 0, 0, 1)
        _ShadowColorStrength("Shadow Color Strength", Range(0, 1)) = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // URP shadow/light keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS       : SV_POSITION;
                float2 uv               : TEXCOORD0;
                float3 positionWS       : TEXCOORD1;
                float3 normalWS         : TEXCOORD2;
                float4 shadowCoord      : TEXCOORD3;
                float  fogFactor        : TEXCOORD4;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _ShadowColor;
                float  _ShadowColorStrength;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   normInputs = GetVertexNormalInputs(IN.normalOS);

                OUT.positionCS  = posInputs.positionCS;
                OUT.positionWS  = posInputs.positionWS;
                OUT.normalWS    = normInputs.normalWS;
                OUT.uv          = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.shadowCoord = GetShadowCoord(posInputs);
                OUT.fogFactor   = ComputeFogFactor(posInputs.positionCS.z);

                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // Base color
                float4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;

                // Main light + shadow attenuation
                Light mainLight = GetMainLight(IN.shadowCoord);
                float atten = mainLight.shadowAttenuation; // 1 = fully lit, 0 = fully shadowed

                // Tint: in shadow lerp toward _ShadowColor, in light stay white
                float3 shadowTint = lerp(_ShadowColor.rgb, float3(1,1,1), atten);

                // Blend tint by strength so you can dial it back
                float3 tintedAtten = lerp(float3(1,1,1), shadowTint, _ShadowColorStrength);

                // Diffuse NdotL
                float3 normalWS = normalize(IN.normalWS);
                float  NdotL    = saturate(dot(normalWS, mainLight.direction));

                // Final color: albedo * light color * NdotL * tinted shadow
                float3 color = albedo.rgb * mainLight.color * NdotL * tintedAtten;

                // Ambient/GI (keeps unlit faces from being pitch black)
                float3 ambient = SampleSH(normalWS) * albedo.rgb;
                color += ambient;

                // Fog
                color = MixFog(color, IN.fogFactor);

                return float4(color, albedo.a);
            }
            ENDHLSL
        }

        // Shadow caster pass so this object still casts shadows onto others
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}