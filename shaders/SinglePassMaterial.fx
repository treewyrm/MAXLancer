#include "Common.fx"
#include "Lights.fx"

#ifdef _MAX_
int TEXCOORD0 : TEXCOORD < int Texcoord = 0; int MapChannel = 0; >;  // Vertex color
int TEXCOORD1 : TEXCOORD < int Texcoord = 1; int MapChannel = -2; >; // Vertex alpha
int TEXCOORD2 : TEXCOORD < int Texcoord = 2; int MapChannel = 1; >;  // UV0
#endif

float4 DiffuseColor  < string UIName = "Diffuse Color"; string UIWidget = "Color"; > = {1.0f, 1.0f, 1.0f, 1.0f};
float3 EmissionColor < string UIName = "Emission Color"; string UIWidget = "Color"; > = {0.0f, 0.0f, 0.0f};

bool DiffuseTextureEnabled < string UIName = "Enable Diffuse Texture"; > = true;
bool DiffuseTextureFlip < string UIName = "Flip Diffuse Texture"; > = false;
Texture2D <float4> DiffuseTexture : DIFFUSEMAP < string UIName = "Diffuse Texture"; string UIWidget = "Bitmap"; string ResourceType = "2D"; >;

bool EmissionTextureEnabled < string UIName = "Enable Emission Texture"; > = true;
bool EmissionTextureFlip < string UIName = "Flip Emission Texture"; > = false;
Texture2D <float4> EmissionTexture : LIGHTMAP < string UIName = "Emission Texture"; string UIWidget = "Bitmap"; string ResourceType = "2D"; >;

float2 UV0Delta : NORMAL < string UIName = "Texture 0 Delta"; > = {0.0f, 0.0f};
float2 UV0Scale : NORMAL < string UIName = "Texture 0 Scale"; > = {1.0f, 1.0f};

struct Vertex {
	float4 Position : POSITION;
	float4 Normal   : NORMAL;
	float3 Color    : TEXCOORD0;
	float3 Alpha    : TEXCOORD1;
	float2 UV0      : TEXCOORD2;
};

struct Pixel {
	float4 Position   : SV_POSITION;
	float4 Color      : COLOR0;
	float2 DiffuseUV  : TEXCOORD2;
	float2 EmissionUV : TEXCOORD2;
};

Pixel Basic_VS(Vertex Input) {
	Pixel Output = (Pixel)0;

	float4 Position   = mul(Input.Position, World);
	float4 Normal     = mul(Input.Normal, WorldInverseTranspose);
	float3 LightColor = {1.0f, 1.0f, 1.0f};

	if (EnableLights) LightColor = CalculateLights(Position.xyz, Normal.xyz);

	DiffuseColor.rgb *= EnableVertexColor ? Input.Color : float3(1.0f, 1.0f, 1.0f);
	DiffuseColor.a   *= EnableVertexAlpha ? Input.Alpha.x : 1.0f;

	Output.Position   = mul(Input.Position, WorldViewProjection);
	Output.Color      = float4(DiffuseColor.rgb * (AmbientColor + LightColor), DiffuseColor.a);
	Output.DiffuseUV  = Input.UV0 * UV0Scale + UV0Delta;
	Output.EmissionUV = Input.UV0 * UV0Scale + UV0Delta;

	Output.DiffuseUV.y  = DiffuseTextureFlip  ? 1 - Output.DiffuseUV.y  : Output.DiffuseUV.y;
	Output.EmissionUV.y = EmissionTextureFlip ? 1 - Output.EmissionUV.y : Output.EmissionUV.y;

	return Output;
}

float4 DcDt_PS(Pixel Input) : SV_TARGET {
	float3 DiffusePixel = DiffuseTextureEnabled ? DiffuseTexture.Sample(DefaultSampler, Input.DiffuseUV).rgb : float3(1.0f, 1.0f, 1.0f);
	return float4(Input.Color.rgb * DiffusePixel, 1.0f);
}

float4 DcDtEc_PS(Pixel Input) : SV_TARGET {
	float3 DiffusePixel = DiffuseTextureEnabled ? DiffuseTexture.Sample(DefaultSampler, Input.DiffuseUV).rgb : float3(1.0f, 1.0f, 1.0f);
	return float4(saturate(EmissionColor * DiffusePixel + Input.Color.rgb * DiffusePixel), 1.0f);
}

float4 DcDtOcOt_PS(Pixel Input) : SV_TARGET {
	float4 DiffusePixel = DiffuseTextureEnabled ? DiffuseTexture.Sample(DefaultSampler, Input.DiffuseUV) : float4(1.0f, 1.0f, 1.0f, 1.0f);
	return (Input.Color * DiffusePixel);
}

float4 DcDtEcOcOt_PS(Pixel Input) : SV_TARGET {
	float4 DiffusePixel = DiffuseTextureEnabled ? DiffuseTexture.Sample(DefaultSampler, Input.DiffuseUV) : float4(1.0f, 1.0f, 1.0f, 1.0f);
	return saturate (float4(EmissionColor * DiffusePixel.rgb, 0.0f) + Input.Color * DiffusePixel);
}

float4 DcDtEt_PS(Pixel Input) : SV_TARGET {
	float3 DiffusePixel = DiffuseTextureEnabled ? DiffuseTexture.Sample(DefaultSampler, Input.DiffuseUV).rgb : float3(1.0f, 1.0f, 1.0f);
	float3 EmissionPixel = EmissionTextureEnabled ? EmissionTexture.Sample(DefaultSampler, Input.EmissionUV).rgb : float3(0.0f, 0.0f, 0.0f);

	float3 Color = saturate(Input.Color.rgb * DiffusePixel);
	return float4(max(Color, EmissionPixel), 1.0f);
}

float4 EcEt_PS(Pixel Input) : SV_TARGET {
	return float4(1.0f, 1.0f, 1.0f, 1.0f);
}

technique11 DcDt {
	pass p0 {
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDt_PS()));
	}
}

technique11 DcDtTwo {
	pass p0 {
		SetRasterizerState(TwoSided);
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDt_PS()));
	}
}

technique11 DcDtEc {
	pass p0 {
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDtEc_PS()));
	}
}

technique11 DcDtEcTwo {
	pass p0 {
		SetRasterizerState(TwoSided);
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDtEc_PS()));
	}
}

technique11 DcDtOcOt < int isTransparent = 1; > {
	pass p0 {
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDtOcOt_PS()));
	}
}

technique11 DcDtOcOtTwo < int isTransparent = 1; > {
	pass p0 {
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetRasterizerState(TwoSided);
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDtOcOt_PS()));
	}
}

technique11 DcDtEcOcOt < int isTransparent = 1; > {
	pass p0 {
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDtEcOcOt_PS()));
	}
}

technique11 DcDtEcOcOtTwo < int isTransparent = 1; > {
	pass p0 {
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetRasterizerState(TwoSided);
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDtEcOcOt_PS()));
	}
}

technique11 EcEt {
	pass p0 {
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, EcEt_PS()));
	}
}

technique11 DcDtEt {
	pass p0 {
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDtEt_PS()));
	}
}

technique11 HUDAnimMaterial < int isTransparent = 1; > {
	pass p0 {
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetRasterizerState(TwoSided);
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDtOcOt_PS()));
	}
}

technique11 HUDIconMaterial < int isTransparent = 1; > {
	pass p0 {
		SetDepthStencilState(DepthTestNoWrite, 0);
		SetRasterizerState(TwoSided);
		SetVertexShader(CompileShader(vs_5_0, Basic_VS()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_5_0, DcDtOcOt_PS()));
	}
}