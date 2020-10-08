/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Materials and shaders linking library for Freelancer materials and 3Ds MAX DxMaterials.
 */

struct ShaderLibrary (
	types        = #(), -- Array of string ("DcDt", etc)
	techniques   = #(), -- Array of integer (DxMaterial.technique)
	filenames    = #(), -- Array of string (DxMaterial.effectFilename)
	archetypes   = #(), -- Array of StructDef
	patterns     = #(), -- Array of DataPair (v1 = name pattern, v2 = new type)
	replacements = #(), -- Array of DataPair (v1 = old type, v2 = new type)

	-- Add shader definition to library
	fn AddShader target classes = (
		if not doesFileExist target then throw "Shader file does not exist."

		local item  = DxMaterial effectFilename:target
		local names = item.getTechniqueList()
		local index

		for i = 1 to names.count where (index = findItem types names[i]) == 0 do (
			append types      names[i]
			append techniques (i - 1)
			append filenames  target
			append archetypes (if classOf classes == array then classes[i] else classes)
		)

		OK
	),

	-- Create new material object by type and filename
	fn CreateMaterial filename target = (
		local result
		local regex

		-- Determine type from filename patterns
		for pattern in patterns where ((dotNetObject "System.Text.RegularExpressions.RegEx" pattern.v1).match (toLower filename)).Success do target = pattern.v2

		-- But some types aren't valid and replaced instead
		if target != undefined then for replacement in replacements where stricmp replacement.v1 target == 0 do target = replacement.v2

		-- Only now we can look for StructDef matching target type
		for i = 1 to types.count while result == undefined where types[i] == target do result = archetypes[i] name:filename technique:techniques[i]

		result -- Return object
	),

	-- Create DxShader from material object
	fn CreateShader target = (
		local archetype = classOf target
		local result

		for i = 1 to types.count while result == undefined where archetypes[i] == archetype and techniques[i] == target.technique do
			result = DxMaterial name:target.name effectFilename:filenames[i] technique:techniques[i]
		
		if hasProperty result #EnableLights then setProperty result #EnableLights MAXLancer.displayVertexLighting
		if hasProperty result #EnableVertexColor then setProperty result #EnableVertexColor MAXLancer.displayVertexColors
		if hasProperty result #EnableVertexAlpha then setProperty result #EnableVertexAlpha MAXLancer.displayVertexAlpha

		result -- Return DxMaterial
	),

	-- Get material type string based on input material class and technique ID
	fn GetTypeByMaterial target = (
		local archetype = classOf target
		local result

		for i = 1 to types.count while result == undefined where archetypes[i] == archetype and techniques[i] == target.technique do result = types[i]
		result -- Return string (material type)
	),

	fn LoadFile target = (
		if not doesFileExist target then throw ("Shaders list file does not exist:\r\n" + target)

		local settings = dotNetObject "System.Xml.XmlReaderSettings"

		settings.IgnoreComments = true
		settings.IgnoreWhitespace = true
		settings.IgnoreProcessingInstructions = true

		local reader   = (dotNetClass "System.Xml.XmlReader").Create target settings
		local nodeType = dotNetClass "System.Xml.XmlNodeType"

		local archetype
		local effectFilename

		try (
			reader.Read() -- Read first node (which can be xml declaration)
		
			if reader.NodeType == nodeType.XmlDeclaration then reader.Read() -- Read root
			if reader.NodeType != nodeType.Element or reader.Name != "materials" then throw "Invalid root element."
		
			while reader.Read() do (
				if reader.Depth != 1 or reader.NodeType != nodeType.Element then continue
				
				case reader.Name as name of (
					#replace: append patterns (DataPair (reader.GetAttribute "pattern") (reader.ReadString()))
					#rename: append replacements (DataPair (reader.GetAttribute "type") (reader.ReadString()))
					#shader: (
						effectFilename = pathConfig.normalizePath (pathConfig.appendPath (getFilenamePath target) (reader.GetAttribute "filename"))
						archetype = FLMaterialLibrary.GetMaterialArchetype (reader.ReadString())

						AddShader effectFilename archetype
					)
				)
			)
		) catch (
			reader.Close()
			throw()
		)

		reader.Close()
		OK
	)
)
