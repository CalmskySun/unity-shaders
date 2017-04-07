Shader "Tianyu Shaders/Character/Hair/HairDepthPass"
{
    Properties
    {
        _MainTex("Diffuse (RGB)", 2D) = "white" {}
        _Cutoff("Alpha Cut-Off Threshold", float) = 0.95
    }

    SubShader
    {
        Tags { "Queue" = "AlphaTest" }

        Pass {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" "RenderType" = "Transparent" }
            ZWrite On
            Blend Zero One

            CGPROGRAM
            // compile directives
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #pragma multi_compile_fwdbase novertexlight nodynlightmap nolightmap

            #define UNITY_PASS_FORWARDBASE
            #include "UnityCG.cginc"

            struct Input
            {
                float2 uv_MainTex;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0; // _MainTex
            };

            uniform sampler2D _MainTex;
            uniform float4 _MainTex_ST;
            uniform fixed _Cutoff;

            // vertex shader
            v2f vert (appdata_base v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                return o;
            }

            // fragment shader
            fixed4 frag (v2f i) : SV_Target {
                fixed4 albedo = tex2D(_MainTex, i.uv);
                clip (albedo.b - _Cutoff);
                return albedo;
            }
            ENDCG
        }

	    Pass {
            Name "Caster"
            Tags { "LightMode" = "ShadowCaster" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2f {
                V2F_SHADOW_CASTER;
                float2  uv : TEXCOORD1;
            };

            uniform float4 _MainTex_ST;
            uniform sampler2D _MainTex;
            uniform fixed _Cutoff;

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                fixed4 albedo = tex2D(_MainTex, i.uv);
                clip(albedo.b - _Cutoff);

                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
}