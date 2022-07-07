matrix World                     : WORLD;
matrix WorldInverseTranspose     : WORLDIT;
matrix WorldView                 : WORLDVIEW;
matrix WorldViewInverseTranspose : WORLDVIEWIT;
matrix WorldViewProjection       : WORLDVIEWPROJ;

float3 AmbientColor : AMBIENT = {0.0f, 0.0f, 0.0f};

bool EnableVertexColor < string UIName = "Vertex Color"; > = true;
bool EnableVertexAlpha < string UIName = "Vertex Alpha"; > = true;

SamplerState DefaultSampler {
	Filter   = MIN_MAG_MIP_LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

RasterizerState TwoSided {
	FillMode = SOLID;
	CullMode = NONE;
};

DepthStencilState DepthTestWrite {
	DepthEnable    = TRUE;
	DepthFunc      = LESS;
};

DepthStencilState DepthTestNoWrite {
	DepthEnable    = TRUE;
	DepthWriteMask = ZERO;
	DepthFunc      = LESS;
};

BlendState Additive {
	BlendEnable[0]           = TRUE;
	SrcBlend                 = SRC_ALPHA;
	DestBlend                = ONE;
	BlendOp                  = ADD;
	SrcBlendAlpha            = SRC_ALPHA;
	DestBlendAlpha           = ONE;
	BlendOpAlpha             = ADD;
	RenderTargetWriteMask[0] = 0x0F;
};