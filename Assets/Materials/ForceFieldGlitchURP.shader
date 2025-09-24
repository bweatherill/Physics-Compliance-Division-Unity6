Shader "FX/ForcefieldGlitchURP_NoDepth"
{
    Properties
    {
        _Tint ("Tint (RGBA)", Color) = (0.15,0.5,1,0.25)
        _NoiseScale ("Noise Scale", Range(0.1,10)) = 2
        _NoiseIntensity ("Noise Intensity", Range(0,1)) = 0.35
        _GlitchLines ("Glitch Lines", Range(0,2)) = 0.8
        _GlitchSpeed ("Glitch Speed", Range(0,5)) = 1.5
        _PulseSpeed ("Pulse Speed", Range(0,5)) = 0.5
        _PulseAmount ("Pulse Amount", Range(0,1)) = 0.2

        // Depthless soft-contact controls:
        _GroundY ("Ground Y (world)", Float) = 0.0
        _HeightFadeDistance ("Height Fade Distance", Range(0.01,3)) = 0.7
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off

        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float4 screenPos  : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Tint;
                float _NoiseScale;
                float _NoiseIntensity;
                float _GlitchLines;
                float _GlitchSpeed;
                float _PulseSpeed;
                float _PulseAmount;
                float _GroundY;
                float _HeightFadeDistance;
            CBUFFER_END

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionCS = TransformWorldToHClip(positionWS);
                OUT.positionWS = positionWS;
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                OUT.screenPos  = ComputeScreenPos(OUT.positionCS);
                return OUT;
            }

            // tiny value noise (cheap)
            float hash21(float2 p){
                p = frac(p*float2(123.34, 345.45));
                p += dot(p, p+34.345);
                return frac(p.x*p.y);
            }
            float noise(float2 uv) {
                float2 i = floor(uv);
                float2 f = frac(uv);
                float a = hash21(i);
                float b = hash21(i+float2(1,0));
                float c = hash21(i+float2(0,1));
                float d = hash21(i+float2(1,1));
                float2 u = f*f*(3.0-2.0*f);
                return lerp(lerp(a,b,u.x), lerp(c,d,u.x), u.y);
            }

            // Depthless "contact" fade: soften near a world-space Y plane
            float HeightFade(float3 positionWS, float groundY, float dist)
            {
                // How far above the ground plane are we?
                float h = positionWS.y - groundY;
                // Fade from 0 (at ground) to 1 (dist and above)
                return saturate(h / max(dist, 1e-4));
            }

            float4 frag (Varyings IN) : SV_Target
            {
                // Base blue
                float3 col = _Tint.rgb;

                // Procedural noise in world space (two planes + time)
                float t = _Time.y;
                float n1 = noise(IN.positionWS.xy * _NoiseScale + float2(t*0.15, 0.0));
                float n2 = noise(IN.positionWS.zy * (_NoiseScale*1.3) + float2(0.0, t*0.11));
                float n  = saturate(lerp(n1, n2, 0.5)) * _NoiseIntensity;

                // Screen-space glitch lines (horizontal bands)
                float2 uv = IN.screenPos.xy / IN.screenPos.w;
                float bands = frac(uv.y * 300.0 + sin(t * _GlitchSpeed) * 3.0);
                float lines = smoothstep(0.9, 1.0, bands) * _GlitchLines;

                // Global pulse
                float pulse = (sin(t * _PulseSpeed) * 0.5 + 0.5) * _PulseAmount;

                // Depthless contact fade against a ground plane
                float fade = HeightFade(IN.positionWS, _GroundY, _HeightFadeDistance);

                // Final alpha (no rim)
                float alpha = saturate(_Tint.a * (n + lines + pulse) * fade);

                return float4(col, alpha);
            }
            ENDHLSL
        }
    }
}
