// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Tianyu Shaders/Character/EyeBall/Eyeball fastmode" {
	Properties{
	  _IrisScale("Scale", Range(.5, 1.5)) = 1
	  _Dilation("Dilation", Range(-.5, 2)) = 0
	  _SpecStr("Specular power", Range(0, 10)) = 2
      _SpecPower ("Specular Glossy", Range (32, 512)) = 256
      _Color ("Iris Tint", Color) = (1,1,1,1)
      _MainTex ("Eye Texture", 2D) = "white" {}
	  _BumpMap ("Iris Normal Map", 2D) = "bump" {}
	  _BumpMap2 ("Cornia Normal Map", 2D) = "bump" {}
	  _Masks ("IrisSpecMask(R)Iris CorniaSpecMask(G) EyeColorMask(B)", 2D) = "black" {}
	  [Space][Space][Space][Space][Space]
	  _Cube("Reflection Cubemap", Cube) = "" {  }
	  [IntRange]_RimFactor("Rim Factor", Range(1, 8)) = 4
	  _ReflectionScale("Reflecion Scale", Range(0, 10)) = 1
    }

    SubShader {
    	Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        Pass {
			Tags {"LightMode" = "ForwardBase"}
		    CGPROGRAM
		        #pragma vertex vert
		        #pragma fragment frag
				#include "../../PanguShaderCommon.cginc"
		        #include "HLSLSupport.cginc"
				#include "UnityShaderVariables.cginc"
		        #pragma multi_compile_fwdbase
		        #include "UnityCG.cginc"
		        #include "AutoLight.cginc"

		        struct v2f
		        {
		            float4 pos : SV_POSITION;
					float2 uv : TEXCOORD0;
					fixed3 lightDir : TEXCOORD1;
					fixed3 vlight : TEXCOORD2;
					float3 viewDir : TEXCOORD3;
					float3 viewDirW : TEXCOORD4;
					float3 tangent : TEXCOORD5;
					float3 binormal : TEXCOORD6;
					float3 normal : TEXCOORD7;
					LIGHTING_COORDS(8,9)

		        };

				fixed _IrisScale;

		        v2f vert (appdata_tan v)
		        {
		            v2f o;

					o.pos = UnityObjectToClipPos(v.vertex);


					float2 uv = v.texcoord.xy - .5;
					uv *= _IrisScale;
					o.uv = uv + .5;

					float3 viewDir = -ObjSpaceViewDir(v.vertex);
					float3 worldRefl = mul((float3x3)unity_ObjectToWorld, viewDir);

					TANGENT_SPACE_ROTATION;
					o.lightDir = mul (rotation, ObjSpaceLightDir(v.vertex));
					o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex));
					o.viewDirW = WorldSpaceViewDir(v.vertex);
					o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent).xyz);
					o.normal = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);
					o.binormal = cross(o.normal, o.tangent) * v.tangent.w;

					float3 worldN = mul((float3x3)unity_ObjectToWorld, SCALED_NORMAL);
				    float3 shlight = ShadeSH9 (float4(worldN,1.0));
				  	o.vlight = shlight;

		            TRANSFER_VERTEX_TO_FRAGMENT(o);
		            return o;
		        }

		        sampler2D _MainTex;
		        sampler2D _BumpMap;
		        sampler2D _BumpMap2;
		        sampler2D _Masks;
		        samplerCUBE _Cube;
				fixed _ReflectionScale;
		        fixed4 _Color;
		        fixed4 _LightColor0;
		        half _SpecStr;
		        half _SpecPower;
		        fixed _Dilation;
				fixed _RimFactor;


		        float4 frag(v2f i) : COLOR
		        {
		        	half3 nViewDirT = normalize(i.viewDir);
		            half3 h = normalize(i.lightDir + nViewDirT);


					half2 uv = i.uv - .5;
		            half pupil = saturate(length(uv)/ 0.14);
					uv *= lerp(1.0, pupil, _Dilation);
		            uv += .5;

					fixed4 albido = tex2D(_MainTex, uv);
					fixed4 masks = tex2D( _Masks, uv);

					albido.rgb *= (_Color * _Color.a * masks.b) + (1- masks.b);
		        	half3 n = UnpackNormal( tex2D(_BumpMap, uv));
		        	half3 n2 = UnpackNormal( tex2D(_BumpMap2, i.uv));
					float NdotL = max(0,dot(n, i.lightDir));
		            float NdotH = max(0,dot(n, h));
		            float N2dotH = max(0,dot(n2, h));
					float N2dotV = 1.0 - saturate(dot(normalize(i.viewDir), n2));
					half rim = fPow(N2dotV, _RimFactor);

		            float3 spec = fPow(NdotH, 40) * masks.r * _LightColor0.rgb;
		            spec += fPow(N2dotH, _SpecPower) * _SpecStr * _LightColor0.rgb;

					//float atten = LIGHT_ATTENUATION(i);

					float3 normalW = (i.tangent * n2.x) + (i.binormal * n2.y) + (i.normal * n2.z);
					float3 reflection = texCUBE(_Cube, reflect(-i.viewDirW, normalW)) * N2dotV;

		            fixed4 c;
		            c.rgb = ((albido * _LightColor0.rgb * NdotL)  + spec)  + ((reflection * _ReflectionScale + rim) * masks.g);
					c.rgb += albido * i.vlight;
		            c.a = 1;
		            return c;
		        }
		    ENDCG
		}
      }
    Fallback "Diffuse"
}