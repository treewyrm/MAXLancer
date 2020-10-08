bool EnableLights < string UIName = "Vertex Lighting"; > = true;

int LightCount < string UIName = "Active Light Count"; string UIWidget = "IntSpinner"; float UIMin = 0; float UIMax = 4; float UIStep = 1; > = 0;

float3 Light0Position : POSITION < string Space = "World"; int RefID = 0; >;
float3 Light1Position : POSITION < string Object = "OmniLight"; string UIName = "Light 1"; string Space = "World"; int RefID = 1; >;
float3 Light2Position : POSITION < string Object = "OmniLight"; string UIName = "Light 2"; string Space = "World"; int RefID = 2; >;
float3 Light3Position : POSITION < string Object = "OmniLight"; string UIName = "Light 3"; string Space = "World"; int RefID = 3; >;
float3 Light4Position : POSITION < string Object = "OmniLight"; string UIName = "Light 4"; string Space = "World"; int RefID = 3; >;

float3 Light0Color : LIGHTCOLOR < int LightRef = 0; >;
float3 Light1Color : LIGHTCOLOR < int LightRef = 1; >;
float3 Light2Color : LIGHTCOLOR < int LightRef = 2; >;
float3 Light3Color : LIGHTCOLOR < int LightRef = 3; >;
float3 Light4Color : LIGHTCOLOR < int LightRef = 4; >;

float Light0FallOff : LIGHTFALLOFF < int LightRef = 0; >;
float Light1FallOff : LIGHTFALLOFF < int LightRef = 1; >;
float Light2FallOff : LIGHTFALLOFF < int LightRef = 2; >;
float Light3FallOff : LIGHTFALLOFF < int LightRef = 3; >;
float Light4FallOff : LIGHTFALLOFF < int LightRef = 4; >;

float4 Light0Attenuations : LIGHTATTENUATION < int LightRef = 0; >;
float4 Light1Attenuations : LIGHTATTENUATION < int LightRef = 1; >;
float4 Light2Attenuations : LIGHTATTENUATION < int LightRef = 2; >;
float4 Light3Attenuations : LIGHTATTENUATION < int LightRef = 3; >;
float4 Light4Attenuations : LIGHTATTENUATION < int LightRef = 4; >;

float3 GetLight(float3 VertexPosition, float3 VertexNormal, float3 LightPosition, float3 LightColor, float4 LightAttenuations) {
	float3 LightDirection = LightPosition - VertexPosition;
	float LightDistance = length(LightDirection);
	float LightDot = saturate(dot(normalize(LightDirection), VertexNormal));

	float LightAttenuation = LightAttenuations.y == 0.0f ? 1.0f : saturate(1.0f - LightDistance * LightDistance / (LightAttenuations.y * LightAttenuations.y));
	LightAttenuation *= LightAttenuation;

	return LightColor * LightDot * LightAttenuation;
}

float3 CalculateLights(float3 Position, float3 Normal) {
	float3 LightColor = float3(0.0f, 0.0f, 0.0f);

	LightColor = GetLight(Position, Normal, Light0Position, Light0Color, float4(0.0f, 0.0f, 0.0f, 0.0f));

	if (LightCount > 0) LightColor  = GetLight(Position, Normal, Light1Position, Light1Color, Light1Attenuations);
	if (LightCount > 1) LightColor += GetLight(Position, Normal, Light2Position, Light2Color, Light2Attenuations);
	if (LightCount > 2) LightColor += GetLight(Position, Normal, Light3Position, Light3Color, Light3Attenuations);
	if (LightCount > 3) LightColor += GetLight(Position, Normal, Light4Position, Light4Color, Light4Attenuations);

	return LightColor;
}