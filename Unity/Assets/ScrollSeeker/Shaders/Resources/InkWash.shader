Shader "ScrollSeeker/Ink Wash"
{
    Properties
    {
        _Color ("Ink tint", Color) = (0.8,0.8,0.7,1)
        _Paper ("Paper grain", 2D) = "white" {}
        _Grain ("Grain strength", Range(0,0.3)) = 0.07
        _Scale ("Grain scale", Float) = 0.12
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 150
        CGPROGRAM
        #pragma surface surf Lambert fullforwardshadows
        #pragma multi_compile_instancing
        #pragma target 3.0
        sampler2D _Paper;
        fixed4 _Color;
        half _Grain, _Scale;
        struct Input { float3 worldPos; float3 worldNormal; };
        void surf (Input IN, inout SurfaceOutput o)
        {
            float2 grainUV = (IN.worldPos.xz + IN.worldPos.y * float2(0.23,0.73)) * _Scale;
            half paper = tex2D(_Paper, grainUV).r;
            half fleck = tex2D(_Paper, grainUV * 7.0).r;
            half wash = 1.0 + (paper - 0.5) * _Grain * 1.5 + (fleck - 0.5) * _Grain;
            o.Albedo = _Color.rgb * wash;
            o.Alpha = 1;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
