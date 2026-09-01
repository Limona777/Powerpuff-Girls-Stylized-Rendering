Shader "PPG/ComicShader2"
{
    Properties
    {
        _Color ("Base Color", Color) = (1,1,1,1)
        _MainTex ("Main Texture", 2D) = "white" {}

        _Ramp1 ("Dark2 Threshold", Range(0,1)) = 0.3
        _Ramp2 ("Dark1 Threshold", Range(0,1)) = 0.6

        _LineToBrightSmooth ("Line to Bright Smoothness", Range(0, 0.2)) = 0.08

        _LineThicknessGradient ("Line Thickness Gradient", Range(0, 1)) = 0.6

        _EdgeDistortScale ("Edge Distort Scale", Float) = 25.0
        _EdgeDistortIntensity ("Edge Distort Intensity", Range(0, 0.3)) = 0.12
        _EdgeDistortOctaves ("Edge Distort Detail", Range(1, 4)) = 3
        _EdgeDetailStrength ("Edge Detail Strength", Range(0, 0.2)) = 0.1

        _HalftoneDensity ("Halftone Density", Float) = 80
        _HalftoneSize ("Halftone Size", Range(0.05, 1)) = 0.3

        _CrossAngle1 ("Cross Line 1 Angle", Range(0,180)) = 45
        _CrossAngle2 ("Cross Line 2 Angle", Range(0,180)) = 135
        _CrossDensity ("Cross Density", Float) = 120
        _CrossThickness ("Cross Thickness", Range(0.01,1)) = 0.18

        _LineAngle ("Single Line Angle", Range(0,180)) = 45
        _LineDensity ("Single Density", Float) = 100
        _LineThickness ("Single Thickness", Range(0.01,1)) = 0.2

        _FineLineEnable ("Fine Line Enable", Range(0,1)) = 1
        _FineLineAngle ("Fine Line Angle", Range(0,180)) = 30
        _FineLineDensity ("Fine Line Density", Float) = 180
        _FineLineThickness ("Fine Line Thickness", Range(0.01,0.2)) = 0.08
        _FineLineStrength ("Fine Line Strength", Range(0,1)) = 0.4
        _FineAngleStrength ("Fine Line Angle Noise Strength", Range(0,1)) = 0.15

        _FineLineNoise ("Fine Line Noise (Angle Only)", 2D) = "white" {}
        _FineLineMask ("Fine Line Mask (Small Area)", 2D) = "white" {}
        _FineLineMaskScale ("Fine Line Mask Scale", Float) = 10

        _ShadowDistortScale ("Shadow Distort Scale", Float) = 1
        _ShadowDistortIntensity ("Shadow Distort Intensity", Range(0,1)) = 0.2
        _ShadowBreakAmount ("Shadow Break Amount", Range(0,1)) = 0.3
        _ShadowThicknessRand ("Shadow Thickness Random", Range(0,1)) = 0.2

        _OutlineWidth ("Outline Width", Range(0,0.1)) = 0.02
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        Pass
        {
            Cull Front
            ZWrite On
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata { float4 vertex : POSITION; float3 normal : NORMAL; };
            struct v2f { float4 pos : SV_POSITION; };

            float _OutlineWidth;
            float4 _OutlineColor;

            v2f vert (appdata v)
            {
                v2f o;
                float3 pos = v.vertex + v.normal * _OutlineWidth;
                o.pos = UnityObjectToClipPos(float4(pos,1));
                return o;
            }
            fixed4 frag (v2f i) : SV_Target { return _OutlineColor; }
            ENDCG
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
            };

            sampler2D _MainTex; float4 _MainTex_ST;
            float4 _Color;
            float _Ramp1, _Ramp2, _LineToBrightSmooth, _LineThicknessGradient;

            float _EdgeDistortScale, _EdgeDistortIntensity, _EdgeDistortOctaves, _EdgeDetailStrength;

            float _HalftoneDensity, _HalftoneSize;

            float _CrossAngle1, _CrossAngle2, _CrossDensity, _CrossThickness;
            float _LineAngle, _LineDensity, _LineThickness;

            float _FineLineEnable, _FineLineAngle, _FineLineDensity, _FineLineThickness, _FineLineStrength;
            float _FineAngleStrength;
            sampler2D _FineLineNoise;
            sampler2D _FineLineMask;
            float _FineLineMaskScale;

            float _ShadowDistortScale, _ShadowDistortIntensity, _ShadowBreakAmount, _ShadowThicknessRand;

            float Remap(float iMin, float iMax, float oMin, float oMax, float v)
            {
                return lerp(oMin, oMax, saturate((v-iMin)/(iMax-iMin)));
            }

            float Hash(float2 p)
            {
                return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
            }

            float ValueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);

                float a = Hash(i);
                float b = Hash(i + float2(1.0, 0.0));
                float c = Hash(i + float2(0.0, 1.0));
                float d = Hash(i + float2(1.0, 1.0));

                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float FractalNoise(float2 p, int octaves)
            {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                
                [unroll]
                for(int i = 0; i < 4; i++)
                {
                    if(i >= octaves) break;
                    value += amplitude * ValueNoise(p * frequency);
                    amplitude *= 0.5;
                    frequency *= 2.0;
                }
                
                return value;
            }

            float Hatch_Shadow(float2 scrUV, float angleDeg, float density, float thickness, float thicknessFactor=1.0)
            {
                float angle = radians(angleDeg);
                float2 uv = scrUV * density;

                float2 dUV = uv * _ShadowDistortScale * 0.03;
                float dl = ValueNoise(dUV);
                float ds = ValueNoise(dUV * 6.0);
                dl = Remap(0,1,-0.5,0.5, dl);
                ds = Remap(0,1,-0.5,0.5, ds);

                angle -= (dl*4+ds) * _ShadowDistortIntensity;

                float2 dir = float2(cos(angle), sin(angle));
                float f = frac(dot(dir, uv));

                float tr = ValueNoise(uv * 0.8);
                tr = Remap(0,1,-0.1,0.1, tr) * _ShadowThicknessRand;

                float effectiveThickness = thickness * (thicknessFactor * thicknessFactor) + tr;
                float hatchLine = step(f, effectiveThickness);

                float2 bUV = uv * density * 0.07;
                float breakThreshold = _ShadowBreakAmount * (1.0 - pow(thicknessFactor, 3.0));
                float b = step(breakThreshold, ValueNoise(bUV));
                hatchLine *= b;

                return hatchLine;
            }

            float Hatch_FineLine(float2 scrUV, float angleDeg, float density, float thickness)
            {
                float angle = radians(angleDeg);
                float2 uv = scrUV * density;

                float2 nUV = scrUV * 2.0;
                float noiseVal = tex2D(_FineLineNoise, nUV).r;
                float angleOffset = Remap(0,1, -1,1, noiseVal);
                angle += angleOffset * _FineAngleStrength * 3.1416;

                float2 dir = float2(cos(angle), sin(angle));
                float f = frac(dot(dir, uv));

                float hatchLine = step(f, thickness);
                return hatchLine;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                float3 N = normalize(i.worldNormal);
                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                float ndl = saturate(dot(N,L));
                float2 scrUV = i.screenPos.xy / i.screenPos.w;

                float2 edgeNoiseUV = scrUV * _EdgeDistortScale;
                float edgeDistort = FractalNoise(edgeNoiseUV, (int)_EdgeDistortOctaves);
                edgeDistort = Remap(0, 1, -_EdgeDistortIntensity, _EdgeDistortIntensity, edgeDistort);

                float edgeDetail = ValueNoise(edgeNoiseUV * 4.0);
                edgeDetail = Remap(0, 1, -_EdgeDetailStrength, _EdgeDetailStrength, edgeDetail);

                float ramp2Distorted = _Ramp2 + edgeDistort + edgeDetail;
                ramp2Distorted = saturate(ramp2Distorted);

                float dark2 = step(ndl, _Ramp1);

                float dark1_full = step(ndl, ramp2Distorted - _LineToBrightSmooth) - dark2;
                float dark1_fade = smoothstep(ramp2Distorted, ramp2Distorted - _LineToBrightSmooth, ndl) - dark2;
                float dark1 = max(dark1_full, dark1_fade);

                float bright = 1 - step(ndl, ramp2Distorted);

                float thicknessFactor = smoothstep(ramp2Distorted, _Ramp1, ndl);

                thicknessFactor = lerp(1.0, thicknessFactor, _LineThicknessGradient);

                float transitionNoise = ValueNoise(scrUV * _EdgeDistortScale * 2.5);
                transitionNoise = Remap(0, 1, -0.12, 0.12, transitionNoise);
                thicknessFactor = saturate(thicknessFactor + transitionNoise);

                float h1 = Hatch_Shadow(scrUV, _CrossAngle1, _CrossDensity, _CrossThickness);
                float h2 = Hatch_Shadow(scrUV, _CrossAngle2, _CrossDensity, _CrossThickness);
                float cross = h1 * h2;
                float single = Hatch_Shadow(scrUV, _LineAngle, _LineDensity, _LineThickness, thicknessFactor);

                float fine = 0;
                if (_FineLineEnable > 0.5)
                {
                    fine = Hatch_FineLine(scrUV, _FineLineAngle, _FineLineDensity, _FineLineThickness);

                    float mask = tex2D(_FineLineMask, scrUV * _FineLineMaskScale).r;
                    fine *= mask * _FineLineStrength;
                }

                float2 uvSpot = frac(scrUV * _HalftoneDensity);
                float dSpot = distance(0.5, uvSpot);
                float halftone = step(dSpot, _HalftoneSize);

                float pattern = 1;
                pattern = lerp(pattern, halftone, bright);
                pattern = lerp(pattern, single, dark1);
                pattern = lerp(pattern, cross, dark2);
                pattern = min(pattern, 1 - fine);

                col.rgb *= pattern;
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}