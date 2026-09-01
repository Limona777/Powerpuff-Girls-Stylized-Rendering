Shader "PPG/SpeedLinePostProcessShader"
{
    Properties
    {
        [NoScaleOffset]_NoiseTex ("NoiseTex", 2D) = "white" { }
        _Center ("Center", Vector) = (0.5, 0.5, 0, 0)
        _RotateSpeed ("Rotate Speed", Float) = 0.2
        _RayMultiply ("Ray Multiply", Float) = 6
        _RayPower ("Ray Power", Float) = 1
        _Threshold ("Threshold", Range(0,1)) = 0.5
        _TintColor ("Tint Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        ZTest Always
        Cull Off
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct Attributes
            {
                float4 positionOS: POSITION;
                float2 uv: TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv: TEXCOORD0;
                float4 vertex: SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _Center;
            float _RotateSpeed;
            float _RayMultiply;
            float _RayPower;
            float _Threshold;
            half4 _TintColor;
            CBUFFER_END

            sampler2D _NoiseTex;

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.vertex = UnityObjectToClipPos(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            half4 frag(Varyings input): SV_Target
            {
                half2 uv = input.uv - _Center.xy;

                float angle = radians(_RotateSpeed * _Time.y);
                float s, c;
                sincos(angle, s, c);

                float2x2 rot0 = float2x2(c, -s, s, c);
                float2x2 rot1 = float2x2(c, s, -s, c);
                half2 uv0 = normalize(mul(rot0, uv));
                half2 uv1 = normalize(mul(rot1, uv));

                half mask0 = tex2D(_NoiseTex, uv0).r;
                half mask1 = tex2D(_NoiseTex, uv1).r;
                half texMask = mask0 * mask1;

                half len = length(uv);
                half uvMask = pow(_RayMultiply * len, _RayPower);
                half combinedMask = texMask * uvMask;

                half finalMask = smoothstep(_Threshold - 0.1, _Threshold + 0.1, combinedMask);

                return half4(_TintColor.rgb, finalMask * _TintColor.a);
            }
            ENDCG
        }
    }
}