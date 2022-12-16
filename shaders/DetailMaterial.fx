#include "Common.fx"
#include "Lights.fx"

#ifdef _MAX_
int TEXCOORD0 : TEXCOORD < int Texcoord = 0; int MapChannel = 0; >;  // Vertex color
int TEXCOORD1 : TEXCOORD < int Texcoord = 1; int MapChannel = -2; >; // Vertex alpha
int TEXCOORD2 : TEXCOORD < int Texcoord = 2; int MapChannel = 1; >;  // UV0
int TEXCOORD3 : TEXCOORD < int Texcoord = 3; int MapChannel = 2; >;  // UV1
#endif

float4 DiffuseColor < string UIName = "Diffuse Color"; string UIWidget = "Color"; > = {1.0f, 1.0f, 1.0f, 1.0f};

bool DiffuseTextureEnabled < string UIName = "Enable Diffuse Texture"; > = true;
bool DiffuseTextureFlip < string UIName = "Flip Diffuse Texture"; > = false;
Texture2D <float4> DiffuseTexture : DIFFUSEMAP < string UIName = "Diffuse Texture"; string UIWidget = "Bitmap"; string ResourceType = "2D"; >;

bool DetailTextureEnabled < string UIName = "Enable Detail Texture"; > = true;
bool DetailTextureFlip < string UIName = "Flip Diffuse Texture"; > = false;
Texture2D <float4> DetailTexture : LIGHTMAP < string UIName = "Detail Texture"; string UIWidget = "Bitmap"; string ResourceType = "2D"; >;

struct Vertex {
	float4 Position : POSITION;
	float4 Normal   : NORMAL;
	float3 Color    : TEXCOORD0;
	float3 Alpha    : TEXCOORD1;
	float2 UV0      : TEXCOORD2;
	float2 UV1      : TEXCOORD3;
};

struct Pixel {
	float4 Position : SV_POSITION;
	float4 Color    : COLOR0;
	float2 UV0      : TEXCOORD2;
	float2 UV1      : TEXCOORD3;
};

Pixel Detail_VS(Vertex Input) {
	Pixel Output = (Pixel)0;

	float4 Position   = mul(Input.Position, World);
	float4 Normal     = mul(Input.Normal, WorldInverseTranspose);
	float3 LightColor = {1.0f, 1.0f, 1.0f};

	if (EnableLights) LightColor = CalculateLights(Position.xyz, Normal.xyz);
	if (EnableVertexColor) DiffuseColor.rgb *= Input.Color;
	if (EnableVertexAlpha) DiffuseColor.a *= Input.Alpha.x;

	Output.Position = mul(Input.Position, WorldViewProjection);
	Output.UV0      = Input.UV0;
	Output.UV1      = Input.UV1;
	Output.Color    = float4(DiffuseColor.rgb * (AmbientColor + LightColor), DiffuseColor.a);

	Output.UV0.y = DiffuseTextureFlip ? 1 - Output.UV0.y : Output.UV0.y;
	Output.UV1.y = DetailTextureFlip  ? 1 - Output.UV1.y : Output.UV1.y;

	return Output;
}

// BtDetailMapMaterial, BtDetailMapMaterialTwo
float4 Detail_PS(Pixel Input) : SV_TARGET {
	float3 Color       = DiffuseTextureEnabled ? DiffuseTexture.Sample(DefaultSampler, Input.UV0).rgb : float3(1.0f, 1.0f, 1.0f);
	float3 DetailColor = DetailTextureEnabled ? DetailTexture.Sample(DefaultSampler, Input.UV1).rgb : float3(0.5f, 0.5f, 0.5f);
	float3 ResultColor = {0.0f, 0.0f, 0.0f};

	ResultColor.r = Color.r < 0.5f ? (2.0f * Color.r * DetailColor.r) : (1.0f - 2.0f * (1.0f - Color.r) * (1.0f - DetailColor.r));
	ResultColor.g = Color.g < 0.5f ? (2.0f * Color.g * DetailColor.g) : (1.0f - 2.0f * (1.0f - Color.g) * (1.0f - DetailColor.g));
	ResultColor.b = Color.b < 0.5f ? (2.0f * Color.b * DetailColor.b) : (1.0f - 2.0f * (1.0f - Color.b) * (1.0f - DetailColor.b));

	return float4(Input.Color.rgb * ResultColor.rgb, 1.0f);
}

technique11 BtDetailMapMaterial {
	pass p0 {
		SetDepthStencilState(DepthTestWrite, 0);
		SetVertexShader(CompileShader(vs_5_0, Detail_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, Detail_PS()));
	}
}

technique11 BtDetailMapTwoMaterial {
	pass p0 {
		SetDepthStencilState(DepthTestWrite, 0);
		SetRasterizerState(TwoSided);
		SetVertexShader(CompileShader(vs_5_0, Detail_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, Detail_PS()));
	}
}