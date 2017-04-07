Shader "Tianyu Shaders/Character/Hair/HairAlphaPass"
{
    Properties
    {
        _Color("Main Color", Color) = (1,1,1,1)
        _MixedColor("Mixed Color", Color) = (1, 1, 1, 1)
        _MainTex("Diffuse (RG)", 2D) = "white" {}
		[HideIninspector]_HairAlphaTex("Hair Alpha (8 bit Alpha)", 2D) = "white" {}
        _SpecularTex("Specular (R) Spec Shift (G) Spec Mask (B)", 2D) = "gray" {}
        _SpecularMultiplier("Specular Multiplier", float) = 1.0
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _SpecularMultiplier2("Secondary Specular Multiplier", float) = 1.0
        _SpecularColor2("Secondary Specular Color", Color) = (1,1,1,1)
        _PrimaryShift("Specular Primary Shift", float) = .5
        _SecondaryShift("Specular Secondary Shift", float) = .7
    }

    SubShader
    {
        Tags { "Queue" = "Transparent" }

        Pass {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" "RenderType" = "Transparent"}
            ZWrite Off
            ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert_surf
            #pragma fragment frag_surf
            #pragma target 3.5
            #pragma multi_compile_fwdbasealpha nodynlightmap nolightmap noshadow
            #include "HLSLSupport.cginc"
            #include "UnityShaderVariables.cginc"

            #define UNITY_PASS_FORWARDBASE
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            #define INTERNAL_DATA
            #define WorldReflectionVector(data,normal) data.worldRefl
            #define WorldNormalVector(data,normal) normal

            #include "HairInclude.cginc"

            // vertex-to-fragment interpolation data
            // no lightmaps:
            #ifndef LIGHTMAP_ON
            struct v2f_surf {
                float4 pos : SV_POSITION;
                float2 pack0 : TEXCOORD0; // _MainTex
                half3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                half3 custompack0 : TEXCOORD3; // tangent_input
                fixed3 vlight : TEXCOORD4; // ambient/SH/vertexlights
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            #endif
            // with lightmaps:
            #ifdef LIGHTMAP_ON
            struct v2f_surf {
                float4 pos : SV_POSITION;
                float2 pack0 : TEXCOORD0; // _MainTex
                half3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                half3 custompack0 : TEXCOORD3; // tangent_input
                float4 lmap : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            #endif
            float4 _MainTex_ST;

            // vertex shader
            v2f_surf vert_surf (appdata_full v) {
                UNITY_SETUP_INSTANCE_ID(v);
                v2f_surf o;
                UNITY_INITIALIZE_OUTPUT(v2f_surf,o);
                UNITY_TRANSFER_INSTANCE_ID(v,o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                Input customInputData;
                vert (v, customInputData);
                o.custompack0.xyz = customInputData.tangent_input;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                #if defined(LIGHTMAP_ON) && defined(DIRLIGHTMAP_COMBINED)
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                fixed tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
                #endif
                #if defined(LIGHTMAP_ON) && defined(DIRLIGHTMAP_COMBINED)
                o.tSpace0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.tSpace1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.tSpace2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
                #endif
                o.worldPos = worldPos;
                o.worldNormal = worldNormal;
                #ifdef LIGHTMAP_ON
                o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif

                // SH/ambient and vertex lights
                #ifndef LIGHTMAP_ON
                #if UNITY_SHOULD_SAMPLE_SH
                float3 shlight = ShadeSH9 (float4(worldNormal,1.0));
                o.vlight = shlight;
                #else
                o.vlight = 0.0;
                #endif
                #ifdef VERTEXLIGHT_ON
                o.vlight += Shade4PointLights (
                    unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                    unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                    unity_4LightAtten0, worldPos, worldNormal );
                #endif // VERTEXLIGHT_ON
                #endif // !LIGHTMAP_ON

                return o;
            }

            // fragment shader
            fixed4 frag_surf (v2f_surf IN) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(IN);
                // prepare and unpack data
                Input surfIN;
                UNITY_INITIALIZE_OUTPUT(Input,surfIN);
                surfIN.uv_MainTex.x = 1.0;
                surfIN.tangent_input.x = 1.0;
                surfIN.uv_MainTex = IN.pack0.xy;
                surfIN.tangent_input = IN.custompack0.xyz;
                float3 worldPos = IN.worldPos;
                #ifndef USING_DIRECTIONAL_LIGHT
                    fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                #else
                    fixed3 lightDir = _WorldSpaceLightPos0.xyz;
                #endif
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                #ifdef UNITY_COMPILER_HLSL
                SurfaceOutputHair o = (SurfaceOutputHair)0;
                #else
                SurfaceOutputHair o;
                #endif
                o.Albedo = 0.0;
                o.Emission = 0.0;
                o.Specular = 0.0;
                o.Alpha = 0.0;
                fixed3 normalWorldVertex = fixed3(0,0,1);
                o.Normal = IN.worldNormal;
                normalWorldVertex = IN.worldNormal;

                // call surface function
                surf (surfIN, o);

                // compute lighting & shadowing factor
                UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)
                fixed4 c = 0;
                #ifndef LIGHTMAP_ON
                c.rgb += o.Albedo * IN.vlight;
                #endif // !LIGHTMAP_ON

                // lightmaps
                #ifdef LIGHTMAP_ON
                    #if DIRLIGHTMAP_COMBINED
                    // directional lightmaps
                    fixed4 lmtex = UNITY_SAMPLE_TEX2D(unity_Lightmap, IN.lmap.xy);
                    half3 lm = DecodeLightmap(lmtex);
                    #elif DIRLIGHTMAP_SEPARATE
                    // directional with specular - no support
                    half4 lmtex = 0;
                    half3 lm = 0;
                    #else
                    // single lightmap
                    fixed4 lmtex = UNITY_SAMPLE_TEX2D(unity_Lightmap, IN.lmap.xy);
                    fixed3 lm = DecodeLightmap (lmtex);
                    #endif

                #endif // LIGHTMAP_ON

                // realtime lighting: call lighting function
                #ifndef LIGHTMAP_ON
                    c += LightingHair (o, lightDir, worldViewDir, atten);
                #else
                    c.a = o.Alpha;
                #endif

                return c;
            }
            ENDCG
        }

        Pass {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardAdd" }

            ZWrite Off
            Blend SrcAlpha One

            CGPROGRAM
            // compile directives
            #pragma vertex vert_surf
            #pragma fragment frag_surf
            #pragma target 3.5
            #pragma multi_compile_fwdadd nodynlightmap nolightmap noshadow
            #pragma skip_variants INSTANCING_ON
            #include "HLSLSupport.cginc"
            #include "UnityShaderVariables.cginc"

            #define UNITY_PASS_FORWARDADD
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            #define INTERNAL_DATA
            #define WorldReflectionVector(data,normal) data.worldRefl
            #define WorldNormalVector(data,normal) normal

            #include "HairInclude.cginc"

            struct v2f_surf {
                float4 pos : SV_POSITION;
                float2 pack0 : TEXCOORD0; // _MainTex
                half3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                half3 custompack0 : TEXCOORD3; // tangent_input
            };
            float4 _MainTex_ST;

            // vertex shader
            v2f_surf vert_surf (appdata_full v) {
                v2f_surf o;
                UNITY_INITIALIZE_OUTPUT(v2f_surf,o);
                Input customInputData;
                vert (v, customInputData);
                o.custompack0.xyz = customInputData.tangent_input;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = worldPos;
                o.worldNormal = worldNormal;
                return o;
            }

            // fragment shader
            fixed4 frag_surf (v2f_surf IN) : SV_Target {
                // prepare and unpack data
                Input surfIN;
                UNITY_INITIALIZE_OUTPUT(Input,surfIN);
                surfIN.uv_MainTex.x = 1.0;
                surfIN.tangent_input.x = 1.0;
                surfIN.uv_MainTex = IN.pack0.xy;
                surfIN.tangent_input = IN.custompack0.xyz;
                float3 worldPos = IN.worldPos;
                #ifndef USING_DIRECTIONAL_LIGHT
                    fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                #else
                    fixed3 lightDir = _WorldSpaceLightPos0.xyz;
                #endif
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                #ifdef UNITY_COMPILER_HLSL
                SurfaceOutputHair o = (SurfaceOutputHair)0;
                #else
                SurfaceOutputHair o;
                #endif
                o.Albedo = 0.0;
                o.Emission = 0.0;
                o.Specular = 0.0;
                o.Alpha = 0.0;
                fixed3 normalWorldVertex = fixed3(0,0,1);
                o.Normal = IN.worldNormal;
                normalWorldVertex = IN.worldNormal;

                // call surface function
                surf (surfIN, o);
                UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)
                fixed4 c = 0;
                c += LightingHair (o, lightDir, worldViewDir, atten);
                return c;
            }
            ENDCG
        }
    }
}