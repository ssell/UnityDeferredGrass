//
// Copy of the Unity provided Internal-DeferredShading.shader
// This should be set as the default deferred shader for the project.
//
//    Editor > Project Settings > Graphics > Built-in Shader Settings > Deferred
//
// Last updated from internal source: 2019.3.0b9
// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
//

Shader "Realms/DeferredShadingPasses" 
{
    Properties 
    {
        _LightTexture0 ("", any) = "" {}
        _LightTextureB0 ("", 2D) = "" {}
        _ShadowMapTexture ("", any) = "" {}
        _SrcBlend ("", Float) = 1
        _DstBlend ("", Float) = 1
    }

    SubShader 
    {
        // ---------------------------------------------------------------------------------
        // Pass 1: Lighting pass
        //  LDR case - Lighting encoded into a subtractive ARGB8 buffer
        //  HDR case - Lighting additively blended into floating point buffer
        // ---------------------------------------------------------------------------------

        Pass 
        {
            ZWrite Off
            Blend [_SrcBlend] [_DstBlend]

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_deferred
            #pragma fragment frag
            #pragma multi_compile_lightpass
            #pragma multi_compile ___ UNITY_HDR_ON

            #pragma exclude_renderers nomrt

            #include "UnityCG.cginc"
            #include "UnityDeferredLibrary.cginc"
            #include "UnityPBSLighting.cginc"
            #include "UnityStandardUtils.cginc"
            #include "UnityGBuffer.cginc"
            #include "UnityStandardBRDF.cginc"

            sampler2D _CameraGBufferTexture0;
            sampler2D _CameraGBufferTexture1;
            sampler2D _CameraGBufferTexture2;

            /**
             * Helper function which builds the UnityIndirect structure.
             * Copy of the one found in RealmsStandardLightingCommon.cginc
             */
            UnityIndirect BuildIndirectLight(float3 normal, float roughness, float3 viewDir)
            {
                UnityIndirect indirectLight;

                #if defined (DIRECTIONAL)
                // Only apply ambient lighting for the (single) directional light in the scene.
                indirectLight.diffuse = max(0.0f, ShadeSH9(float4(normal, 1.0f)));
                #else
                indirectLight.diffuse = 0.0f;
                #endif

                float3 reflectionDir = reflect(-viewDir, normal);

                Unity_GlossyEnvironmentData envData;
                envData.roughness = roughness;
                envData.reflUVW = reflectionDir;

                indirectLight.specular = Unity_GlossyEnvironment(
                    UNITY_PASS_TEXCUBE(unity_SpecCube0), 
                    unity_SpecCube0_HDR, 
                    envData);

                return indirectLight;
            }

            half4 CalculateLight (unity_v2f_deferred i)
            {
                float3 wpos;
                float2 uv;
                float atten, fadeDist;
                
                UnityLight light;
                UNITY_INITIALIZE_OUTPUT(UnityLight, light);
                UnityDeferredCalculateLightParams (i, wpos, uv, light.dir, atten, fadeDist);

                light.color = _LightColor.rgb * atten;

                // unpack Gbuffer
                half4 gbuffer0 = tex2D (_CameraGBufferTexture0, uv);        // Diffuse Color RGB, Occlusion A
                half4 gbuffer1 = tex2D (_CameraGBufferTexture1, uv);        // Specular Color RGB, Roughness A
                half4 gbuffer2 = tex2D (_CameraGBufferTexture2, uv);        // World Normal RGB, Unused A
                UnityStandardData data = UnityStandardDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);

                float3 eyeVec = normalize(wpos - _WorldSpaceCameraPos);
                half oneMinusReflectivity = 1 - SpecularStrength(data.specularColor.rgb);

                UnityIndirect ind = BuildIndirectLight(data.normalWorld, (1.0f - data.smoothness), eyeVec);

                half4 res = UNITY_BRDF_PBS (data.diffuseColor, data.specularColor, oneMinusReflectivity, data.smoothness, data.normalWorld, -eyeVec, light, ind);

                return res;
            }

            #ifdef UNITY_HDR_ON
            half4
            #else
            fixed4
            #endif
            frag (unity_v2f_deferred i) : SV_Target
            {
                half4 c = CalculateLight(i);
                #ifdef UNITY_HDR_ON
                return c;
                #else
                return exp2(-c);
                #endif
            }

            ENDCG
        }

        // ---------------------------------------------------------------------------------
        // Pass 2: Final decode pass.
        // Used only with HDR off, to decode the logarithmic buffer into the main RT
        // ---------------------------------------------------------------------------------

        Pass 
        {
            ZTest Always Cull Off ZWrite Off
            Stencil 
            {
                ref [_StencilNonBackground]
                readmask [_StencilNonBackground]
                // Normally just comp would be sufficient, but there's a bug and only front face stencil state is set (case 583207)
                compback equal
                compfront equal
            }

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers nomrt

            #include "UnityCG.cginc"

            sampler2D _LightBuffer;
            struct v2f 
            {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
            };

            v2f vert (float4 vertex : POSITION, float2 texcoord : TEXCOORD0)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(vertex);
                o.texcoord = texcoord.xy;
            #ifdef UNITY_SINGLE_PASS_STEREO
                o.texcoord = TransformStereoScreenSpaceTex(o.texcoord, 1.0f);
            #endif
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return -log2(tex2D(_LightBuffer, i.texcoord));
            }
            ENDCG
        }
    }

    Fallback Off
}
