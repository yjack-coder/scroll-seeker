Shader "ScrollSeeker/River Ink"
{
    Properties
    {
        _Color ("River jade", Color) = (0.30,0.51,0.48,1)
        _Foam ("Reflected paper", Color) = (0.78,0.84,0.73,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 150
        CGPROGRAM
        #pragma surface surf Lambert fullforwardshadows
        #pragma multi_compile_instancing
        #pragma target 3.0
        fixed4 _Color, _Foam;
        struct Input { float3 worldPos; };
        void surf (Input IN, inout SurfaceOutput o)
        {
            float x = IN.worldPos.x, z = IN.worldPos.z;
            float wave = sin(z * 4.5 + x * 0.7 - _Time.y * 1.2 + sin(x * 2.1));
            float fine = pow(saturate(wave), 26) * 0.19;
            float wash = sin(z * 0.8 - _Time.y * 0.25 + sin(x * 0.8)) * 0.045;
            o.Albedo = lerp(_Color.rgb + wash, _Foam.rgb, fine);
            o.Emission = o.Albedo * 0.12;
            o.Alpha = 1;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
