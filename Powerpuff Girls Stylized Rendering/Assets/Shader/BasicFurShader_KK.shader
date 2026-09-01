Shader "PPG/BasicFurShader_KK" {
    Properties {
        _FurTex ("Fur Texture", 2D) = "white" {}
        _FurColor ("Fur Color", Color) = (1,1,1,1)
        _FurLength ("Fur Length", Range(0.0, 1.0)) = 0.5
        _FurRadius ("Fur Radius", Range(0.0, 1.0)) = 0.5
        _Noise ("Noise (R)", 2D) = "white" {}

        _OcclusionColor ("Occlusion Color", Color) = (0.2,0.2,0.2,1)
        _OcclusionPower ("Occlusion Power", Range(0.1,5.0)) = 1.0
        _LightAdd ("Light Add", Range(-1.0,1.0)) = 0.1

        _UVOffset("UV Offset", Vector) = (0.1, 0.1, 0, 0)
        _Timing("Fur Shape Timing", Range(0.1, 5.0)) = 1.0

        _FresnelColor("Fresnel Color", Color) = (1,1,1,1)
        _FresnelBias("Fresnel Bias", Range(0,1)) = 0.3
        _FresnelScale("Fresnel Scale", Range(0,5)) = 1.5
        _FresnelPower("Fresnel Power", Range(1,10)) = 3.0

        _PrimaryColor ("Primary Specular", Color) = (1,1,1,1)
        _SecondaryColor ("Secondary Specular", Color) = (0.8,0.7,0.6,1)
        _SpecularPower ("Specular Power", Range(10,200)) = 100
        _PrimaryShift ("Primary Shift", Range(-1,1)) = 0.15
        _SecondaryShift ("Secondary Shift", Range(-1,1)) = -0.25
        _SpecularScale ("Specular Scale", Range(0,2)) = 1.0
        _Roughness ("Roughness", Range(0,1)) = 0.3
    }
    
    SubShader {
        Tags { 
            "LightMode"="ForwardBase"
            "RenderType"="Transparent"
            "IgnoreProjector"="True"
            "Queue"="Transparent"
        }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Back
        ZWrite Off
        LOD 200

        Pass {
            ZWrite On
            ColorMask 0
        }

        Pass {
            Name "BASE"
            CGPROGRAM
            #pragma vertex vert_base
            #pragma fragment frag_base
            #pragma multi_compile_fwdbase
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 texcoord : TEXCOORD0;
            };
            
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed3 diff : TEXCOORD1;
            };
            
            sampler2D _FurTex;
            float4 _FurTex_ST;
            fixed4 _FurColor;
            
            v2f vert_base (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _FurTex);
                
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                half nl = dot(worldNormal, worldLightDir) * 0.5 + 0.5;
                o.diff = nl * _LightColor0.rgb + UNITY_LIGHTMODEL_AMBIENT.rgb;
                
                return o;
            }
            
            fixed4 frag_base (v2f i) : SV_Target {
                fixed3 col = tex2D(_FurTex, i.uv).rgb * _FurColor.rgb;
                col *= i.diff;
                return fixed4(col, 1.0);
            }
            ENDCG
        }

// Layer 01
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.05
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;

struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };

float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}

v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;

    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));

    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;

    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));

    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;

    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;

    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;

    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;

    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;

    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);

    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);

    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 02
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.10
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 03
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.15
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 04
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.20
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 05
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.25
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 06
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.30
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 07
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.35
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 08
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.40
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 09
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.45
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 10
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.50
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 11
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.55
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 12
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.60
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 13
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.65
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 14
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.70
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 15
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.75
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 16
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.80
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 17
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.85
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 18
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.90
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 19
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 0.95
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG }

// Layer 20
Pass { CGPROGRAM
#pragma vertex vert_fur
#pragma fragment frag_fur
#define FURSTEP 1.00
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
sampler2D _FurTex, _Noise;
float4 _FurTex_ST, _Noise_ST;
fixed4 _FurColor;
float _FurLength, _FurRadius, _Timing;
fixed4 _OcclusionColor;
float _OcclusionPower;
float _LightAdd;
float2 _UVOffset;
fixed4 _FresnelColor;
float _FresnelBias, _FresnelScale, _FresnelPower;
fixed4 _PrimaryColor, _SecondaryColor;
float _SpecularPower, _PrimaryShift, _SecondaryShift, _SpecularScale, _Roughness;
struct appdata_fur { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 texcoord : TEXCOORD0; };
struct v2f_fur { float4 pos : SV_POSITION; float2 uv_FurTex : TEXCOORD0; float2 uv_Noise : TEXCOORD1; fixed4 lightMul : TEXCOORD2; fixed3 spec : TEXCOORD3; fixed fresnel : TEXCOORD4; LIGHTING_COORDS(5,6) };
float3 ShiftTangent(float3 T, float3 N, float shift){ return normalize(T + shift * N); }
float StrandSpecular(float3 T, float3 V, float3 L, float exponent){
    float3 H = normalize(L + V); float dotTH = dot(T,H); float sinTH = sqrt(1-dotTH*dotTH);
    float dirAtten = smoothstep(-1,0,dotTH) * smoothstep(-1,0,dot(T,L));
    return dirAtten * pow(sinTH,exponent);
}
v2f_fur vert_fur (appdata_fur v) {
    v2f_fur o;
    float3 displacedPos = v.vertex.xyz + v.normal * _FurLength * 0.1 * FURSTEP;
    o.pos = UnityObjectToClipPos(float4(displacedPos,1));
    o.uv_FurTex = TRANSFORM_TEX(v.texcoord,_FurTex);
    float2 uvoffset = FURSTEP * _UVOffset.xy *0.1;
    o.uv_Noise = TRANSFORM_TEX(v.texcoord,_Noise)+uvoffset;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
    float3 worldViewDir = normalize(WorldSpaceViewDir(v.vertex));
    float diff = dot(worldNormal,worldLightDir)*0.5+0.5;
    diff = saturate(diff+FURSTEP+_LightAdd);
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
    fixed3 diffuse = _LightColor0.rgb*diff+ambient;
    fixed occlusion = saturate(pow(FURSTEP,_OcclusionPower)*2.5);
    o.lightMul.rgb = diffuse; o.lightMul.a = occlusion;
    o.fresnel = saturate(_FresnelBias + _FresnelScale * pow(1-dot(worldViewDir,worldNormal),_FresnelPower)) * occlusion;
    float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz));
    float3 worldBiTangent = normalize(cross(worldNormal,worldTangent));
    float3 T1 = ShiftTangent(worldBiTangent,worldNormal,_PrimaryShift);
    float3 T2 = ShiftTangent(worldBiTangent,worldNormal,_SecondaryShift);
    float spec1 = StrandSpecular(T1,worldViewDir,worldLightDir,_SpecularPower);
    float spec2 = StrandSpecular(T2,worldViewDir,worldLightDir,_SpecularPower*0.8);
    float nl = saturate(dot(worldNormal,worldLightDir));
    o.spec = (_PrimaryColor.rgb*spec1+_SecondaryColor.rgb*spec2)*_SpecularScale*FURSTEP*2*nl;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    return o;
}
fixed4 frag_fur (v2f_fur i) : SV_Target {
    fixed3 albedo = tex2D(_FurTex,i.uv_FurTex).rgb*_FurColor.rgb;
    fixed noise = tex2D(_Noise,i.uv_Noise).r;
    fixed alpha = saturate(noise*2-(FURSTEP*FURSTEP+FURSTEP*_FurRadius)*_Timing);
    fixed3 occColor = lerp(_OcclusionColor.rgb,1,i.lightMul.a);
    fixed3 finalColor = albedo*i.lightMul.rgb*occColor + i.spec*alpha*LIGHT_ATTENUATION(i) + i.fresnel*_FresnelColor.rgb;
    return fixed4(finalColor,alpha);
}
ENDCG 
}
    }
    FallBack "Diffuse"
}