#include "Common.fx"
#include "Lights.fx"

#ifdef _MAX_
int TEXCOORD0 : TEXCOORD < int Texcoord = 0; int MapChannel = 0; >;  // Vertex color
int TEXCOORD1 : TEXCOORD < int Texcoord = 1; int MapChannel = -2; >; // Vertex alpha
int TEXCOORD2 : TEXCOORD < int Texcoord = 2; int MapChannel = 1; >;  // UV0
#endif

float4 DiffuseColor  < string UIName = "Diffuse Color"; string UIWidget = "Color"; > = {1.0f, 1.0f, 1.0f, 1.0f};

bool DiffuseTextureEnabled < string UIName = "Enable Diffuse Texture"; > = true;
bool DiffuseTextureFlip < string UIName = "Flip Diffuse Texture"; > = false;
Texture2D <float4> DiffuseTexture : DIFFUSEMAP < string UIName = "Diffuse Texture"; string UIWidget = "Bitmap"; string ResourceType = "2D"; >;

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

// Nebula does not use Dc or Oc
Pixel Neubla_VS(Vertex Input) {
	Pixel Output = (Pixel)0;

	float4 Position   = mul(Input.Position, World);
	float4 Normal     = mul(Input.Normal, WorldInverseTranspose);
	float3 LightColor = {1.0f, 1.0f, 1.0f};
	
	if (EnableLights) LightColor = CalculateLights(Position.xyz, Normal.xyz);
	
	Output.Position = mul(Input.Position, WorldViewProjection);
	Output.UV0      = Input.UV0; // Nebula does not support material animation
	Output.Color    = DiffuseColor * float4(Input.Color * (AmbientColor + LightColor), Input.Alpha.x);

	Output.UV0.y = DiffuseTextureFlip ? 1 - Output.UV0.y : Output.UV0.y;

	return Output;
}

float4 Nebula_PS(Pixel Input) : SV_TARGET {
	float4 DiffusePixel = DiffuseTextureEnabled ? DiffuseTexture.Sample(DefaultSampler, Input.UV0) : float4(1.0f, 1.0f, 1.0f, 1.0f);
	return (Input.Color * DiffusePixel);
}

technique11 Nebula < int isTransparent = 1; > {
	pass p0 {
		SetBlendState(Additive, float4(0.0f, 0.0f, 0.0f, 0.0f), 0xFFFFFFFF);
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetVertexShader(CompileShader(vs_5_0, Neubla_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, Nebula_PS()));
	}
}

technique11 NebulaTwo < int isTransparent = 1; > {
	pass p0 {
		SetBlendState(Additive, float4(0.0f, 0.0f, 0.0f, 0.0f), 0xFFFFFFFF);
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetRasterizerState(TwoSided);
		SetVertexShader(CompileShader(vs_5_0, Neubla_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, Nebula_PS()));
	}
}