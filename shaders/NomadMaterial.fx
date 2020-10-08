#include "Common.fx"

#ifdef _MAX_
int TEXCOORD0 : TEXCOORD < int Texcoord = 0; int MapChannel = 0; >;  // Vertex color
int TEXCOORD1 : TEXCOORD < int Texcoord = 1; int MapChannel = -2; >; // Vertex alpha
int TEXCOORD2 : TEXCOORD < int Texcoord = 2; int MapChannel = 1; >;  // UV0
#endif

float4 DiffuseColor < string UIName = "Diffuse Color"; string UIWidget = "Color"; > = {1.0f, 1.0f, 1.0f, 1.0f};

bool DiffuseTextureFlip < string UIName = "Flip Diffuse Texture"; > = false;
Texture2D <float4> DiffuseTexture : DIFFUSEMAP < string UIName = "Diffuse Texture"; string UIWidget = "Bitmap"; string ResourceType = "2D"; >;

bool NomadTextureFlip < string UIName = "Flip Nomad Texture"; > = false;
Texture2D <float4> NomadTexture : LIGHTMAP < string UIName = "Nomad Texture"; string UIWidget = "Bitmap"; string ResourceType = "2D"; >;

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
	float2 UV0      : TEXCOORD0;
	float3 Normal   : NORMAL0;
	float3 Negate   : NORMAL1;
};

Pixel Nomad_VS(Vertex Input) {
	Pixel Output = (Pixel)0;

	float4 Position = mul(Input.Position, WorldView);
	float4 Normal   = mul(Input.Normal, WorldViewInverseTranspose);

	Output.Position = mul(Input.Position, WorldViewProjection);
	Output.Color    = DiffuseColor;
	Output.Normal   = normalize(Normal.xyz);
	Output.Negate   = normalize(-Position.xyz);
	Output.UV0      = Input.UV0;

	if (DiffuseTextureFlip) Output.UV0.y = 1 - Output.UV0.y;

	return Output;
}

float4 Nomad_PS(Pixel Input) : SV_TARGET {
	float  Ratio      = saturate((dot(Input.Negate, Input.Normal) + 1.0f) / 2.0f);
	float4 Color      = DiffuseTexture.Sample(DefaultSampler, Input.UV0.xy);
	float4 NomadColor = NomadTexture.Sample(DefaultSampler, float2(Ratio, 1.0f));
	
	return float4((Color.rgb + NomadColor.rgb) * Input.Color.rgb, Color.a * NomadColor.a * Input.Color.a);
}

technique11 NomadMaterial < int isTransparent = 1; > { 
	pass p0 {
		SetRasterizerState(TwoSided);
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetVertexShader(CompileShader(vs_5_0, Nomad_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, Nomad_PS()));
	}
}

// What's the difference though?
technique11 NomadMaterialNoBendy < int isTransparent = 1; > { 
	pass p0 {
		SetRasterizerState(TwoSided);
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetVertexShader(CompileShader(vs_5_0, Nomad_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, Nomad_PS()));
	}
}