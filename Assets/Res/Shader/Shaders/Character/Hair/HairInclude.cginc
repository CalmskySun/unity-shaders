#ifndef HAIR_INCLUDED
#define HAIR_INCLUDED

struct SurfaceOutputHair
{
	fixed3 Albedo;
	fixed3 Normal;
	fixed3 Emission;
	half Specular;
	fixed SpecShift;
	fixed Alpha;
	fixed SpecMask;
	half3 tangent_input;
};

struct Input
{
	float2 uv_MainTex;
	half3 tangent_input;
};

sampler2D _MainTex, _SpecularTex , _HairAlphaTex;

float _SpecularMultiplier, _SpecularMultiplier2, _PrimaryShift, _SecondaryShift;
fixed4 _SpecularColor, _Color, _SpecularColor2, _MixedColor;


half3 ShiftTangent(half3 T, half3 N, float shift)
{
	half3 shiftedT = T + shift * N;
	return normalize(shiftedT);
}

float StrandSpecular(half3 T, half3 V, half3 L, float exponent)
{
	half3 H = normalize(L + V);
	float dotTH = dot(T, H);
	float sinTH = sqrt(1 - dotTH * dotTH);
	float dirAtten = smoothstep(-1, 0, dotTH);
	return dirAtten * pow(sinTH, exponent);
}

inline fixed4 LightingHair(SurfaceOutputHair s, fixed3 lightDir, fixed3 viewDir, fixed atten)
{
	float NdotL = saturate(dot(s.Normal, lightDir));

	float shiftTex = s.SpecShift - .5;
	half3 T = -normalize(cross(s.Normal, s.tangent_input));

	half3 t1 = ShiftTangent(T, s.Normal, _PrimaryShift + shiftTex);
	half3 t2 = ShiftTangent(T, s.Normal, _SecondaryShift + shiftTex);

	half3 diff = saturate(lerp(.25, 1, NdotL));
	diff = diff * _Color;

	half3 spec = _SpecularColor * StrandSpecular(t1, viewDir, lightDir, _SpecularMultiplier);
	spec *= 2;

	spec = spec + _SpecularColor2 * (s.SpecMask * 2) * (StrandSpecular(t2, viewDir, lightDir, _SpecularMultiplier2) * 3);

	fixed4 c;
	c.rgb = (diff + spec) * s.Albedo * atten * 2 * _LightColor0.rgb * NdotL;
	c.a = s.Alpha;
	return c;
}


void vert(inout appdata_full i, out Input o)
{
	UNITY_INITIALIZE_OUTPUT(Input, o);
	o.tangent_input = i.tangent.xyz;
}

void surf(Input IN, inout SurfaceOutputHair o)
{
	fixed4 albedo = tex2D(_MainTex, IN.uv_MainTex);
	fixed alphaTex = tex2D(_HairAlphaTex, IN.uv_MainTex).r;
	o.Albedo = saturate((albedo.r > 0.8 ? (1.0 - (1.0 - 5.0*(albedo.r - 0.8))*(1.0 - _Color.rgb)) : (1.25*albedo.r*_Color.rgb)));
	o.Albedo = lerp(o.Albedo, _MixedColor.rgb, albedo.g);
	o.Alpha = albedo.b;
	fixed3 spec = tex2D(_SpecularTex, IN.uv_MainTex).rgb;
	o.Specular = spec.r;
	o.SpecShift = spec.g;
	o.SpecMask = spec.b;
	o.tangent_input = IN.tangent_input;
}

#endif