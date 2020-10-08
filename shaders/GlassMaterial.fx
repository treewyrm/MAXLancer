#include "Common.fx"
#include "Lights.fx"

#ifdef _MAX_
int TEXCOORD0 : TEXCOORD < int Texcoord = 0; int MapChannel = 0; >;  // Vertex color
int TEXCOORD1 : TEXCOORD < int Texcoord = 1; int MapChannel = -2; >; // Vertex alpha
int TEXCOORD2 : TEXCOORD < int Texcoord = 2; int MapChannel = 1; >;  // UV0
#endif

float4 DiffuseColor < string UIName = "Diffuse Color"; string UIWidget = "Color"; > = {1.0f, 1.0f, 1.0f, 1.0f};

struct Vertex {
	float4 Position : POSITION;
	float4 Normal   : NORMAL;
	float3 Color    : TEXCOORD0;
	float3 Alpha    : TEXCOORD1;
	float2 UV0      : TEXCOORD2;
};

struct Pixel {
	float4 Position : SV_POSITION;
	float4 Color    : COLOR0;
	float2 UV0      : TEXCOORD2;
};

Pixel Glass_VS(Vertex Input) {
	Pixel Output = (Pixel)0;

	float4 Position   = mul(Input.Position, World);
	float4 Normal     = mul(Input.Normal, WorldInverseTranspose);
	float3 LightColor = {1.0f, 1.0f, 1.0f};

	if (EnableLights) LightColor = CalculateLights(Position.xyz, Normal.xyz);
	if (EnableVertexColor) DiffuseColor.rgb *= Input.Color;
	if (EnableVertexAlpha) DiffuseColor.a *= Input.Alpha.x;

	Output.Position = mul(Input.Position, WorldViewProjection);
	Output.UV0      = Input.UV0;
	Output.Color    = float4(DiffuseColor.rgb * (AmbientColor + LightColor), DiffuseColor.a);

	return Output;
}

float4 Glass_PS(Pixel Input) : SV_TARGET {
	return float4(Input.Color.rgb, Input.Color.a);
}

technique11 GlassMaterial < int isTransparent = 1; > {
	pass p0 {
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetVertexShader(CompileShader(vs_5_0, Glass_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, Glass_PS()));
	}
}

technique11 GFGlassMaterial < int isTransparent = 1; > {
	pass p0 {
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetVertexShader(CompileShader(vs_5_0, Glass_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, Glass_PS()));
	}
}

technique11 HighGlassMaterial < int isTransparent = 1; > {
	pass p0 {
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetVertexShader(CompileShader(vs_5_0, Glass_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, Glass_PS()));
	}
}