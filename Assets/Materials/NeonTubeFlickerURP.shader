Shader "Ben/NeonTubeFlickerURP"
{
    Properties
    {
        [HDR]_ColorA("Neon Color A", Color) = (0.2, 0.9, 1, 1)
        [HDR]_ColorB("Neon Color B", Color) = (1, 0.1, 0.6, 1)
        _UseTwoColors("Use Two Colors (0/1)", Float) = 1
        _GradientBias("Gradient Bias", Range(-1,1)) = 0
        _GradientSharpness("Gradient Sharpness", Range(0,4)) = 1

        _EmissionStrength("Emission Strength", Range(0,50)) = 5

        _FlickerAmount("Flicker Amount", Range(0,1)) = 0.2
        _FlickerSpeed("Flicker Speed (Hz)", Range(0,20)) = 3
        _JitterAmount("Jitter Amount", Range(0,1)) = 0.15
        _JitterSpeed("Jitter Speed (Hz)", Range(0,60)) = 30

        _Seed("Instance Seed", Float) = 0.0

        _MainTex("Optional Mask (R=A mix, G=width)", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline"="UniversalPipeline" }
        LOD 100
        Cull Back
        ZWrite On
        ZTest LEqual
        Blend One Zero // Opaque emission (use Transparent if you want additive)

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _ColorA;
                float4 _ColorB;
                float _UseTwoColors;
                float _GradientBias;
                float _GradientSharpness;

                float _EmissionStrength;

                float _FlickerAmount;
                float _FlickerSpeed;
                float _JitterAmount;
                float _JitterSpeed;

                float _Seed;
            CBUFFER_END

            Varyings vert (Attributes v)
            {
                Varyings o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;
                return o;
            }

            // Cheap hash for pseudo-random per-instance variation
            float hash(float n) { return frac(sin(n)*43758.5453); }

            float remap01(float x, float bias, float sharp)
            {
                // Center gradient by bias, sharpen with smoothstep power
                float t = saturate((x + bias) * 0.5 + 0.5);
                // sharpen
                t = pow(t, max(0.001, sharp));
                return t;
            }

            half4 frag (Varyings i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                // Neon color across V (tube length/width depends on UVs of your mesh).
                float t = remap01(i.uv.x, _GradientBias, _GradientSharpness);

                float4 mask = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                // If you provide a mask: R can mix colors, G can thin the tube, etc.
                t = lerp(t, mask.r, step(0.001, mask.r)); // use texture R if present

                float3 neon = lerp(_ColorA.rgb, _ColorB.rgb, (_UseTwoColors > 0.5) ? t : 0);

                // --- Flicker ---
                // Base gentle sine flicker (AC ballast vibe)
                float time = _Time.y; // seconds
                float seed = _Seed + hash(_Seed + 13.37);

                float baseWave = 0.5 + 0.5 * sin(6.28318 * (_FlickerSpeed * time + seed));
                // High-freq jitter (tiny brightness noise)
                float jitter = 0.5 + 0.5 * sin(6.28318 * (_JitterSpeed * time + seed*7.0));

                float flicker =
                    1.0 - _FlickerAmount +
                    _FlickerAmount * (0.7 * baseWave + 0.3 * jitter);

                float3 emissive = neon * _EmissionStrength * flicker;

                return half4(emissive, 1);
            }
            ENDHLSL
        }
    }

    FallBack Off
}
