/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 * 
 * "DcDt",                          
 * "DcDtTwo",                       -- Dc, Dt_name, Dt_flags
 * "DcDtEc",                        
 * "DcDtEcTwo",                     -- Dc, Dt_name, Dt_flags, Ec
 * "DcDtOcOt",                      
 * "DcDtOcOtTwo",                   -- Dc, Dt_name, Dt_flags, Oc
 * "DcDtEcOcOt",                   
 * "DcDtEcOcOtTwo",                 -- Dc, Dt_name, Dt_flags, Ec, Oc
 * "EcEt",                          -- Ec, Et_name, Et_flags
 * "DcDtEt",                        -- Dc, Dt_name, Dt_flags, Et_name, Et_flags
 * "BtDetailMapMaterial",           
 * "BtDetailMapTwoMaterial",        -- Dc, Dt_name, Dt_flags, Bt_name, Bt_flags
 * "DetailMapMaterial",             -- Dc, Dt_name, Dt_flags, Dm_name, Dm_flags
 * "DetailMap2Dm1Msk2PassMaterial", -- Dc, Dt_name, Dt_flags, Dm1_name, Dm1_flags, TileRate
 * "IllumDetailMapMaterial",        -- Dc, Dt_name, Dt_flags, Dm0_name, Dm0_flags, Dm1_name, Dm1_flags, TileRate0, TileRate1
 * "Masked2DetailMapMaterial",      -- Dc, Dt_name, Dt_flags, Dm0_name, Dm0_flags, Dm1_name, Dm1_flags, TileRate0, TileRate1
 * "Nebula",                        
 * "NebulaTwo",                     -- Dc, Dt_name, Dt_flags
 * "AtmosphereMaterial",            -- Ac, Alpha, Dc, Dt_name, Dt_flags Fade, Scale
 * "PlanetWaterMaterial",           -- Dc, Dt_name, Dt_flags
 * "NomadMaterial",                 
 * "NomadMaterialNoBendy",          -- Dt, Nt_name, Nt_flags
 * "GlassMaterial",                 
 * "GFGlassMaterial",               -- Dc, Oc
 * "HighGlassMaterial",             -- Dc, Oc
 * "ExclusionZoneMaterial",         -- Dc, Dt_name, Dt_flags
 * "HUDAnimMaterial",               -- Dc, Dt_name, Dt_flags
 * "HUDIconMaterial"                -- Dc, Dt_name, Dt_flags
 */

struct FLMaterialMap (
	filename,  -- Texture filename (! Not external filename !)
	flags = 64 -- Wrapping mode flags
)

fn ReadTextureMap reader prefix &map = (
	local filename = reader.ReadFileString (prefix + "_name")
	local flags    = reader.ReadFileInteger (prefix + "_flags") #unsigned

	if flags == undefined then flags = 0
	if filename != undefined then map = FLMaterialMap filename:filename flags:flags
	OK
)

fn WriteTextureMap writer prefix map = (
	if classOf map == FLMaterialMap then (
		writer.WriteFileString (prefix + "_name") map.filename
		if map.flags > 0 then writer.WriteFileInteger (prefix + "_flags") map.flags #unsigned
	)

	OK
)

fn GetTextureMap target property textureLib &textureMap = if classOf target == DxMaterial and hasProperty target property then (
	local enabledProperty = (property as string + "Enabled") as name
	local enabled = if hasProperty target enabledProperty then getProperty target enabledProperty else true

	if enabled then (
		local image = getProperty target property
		local texture
		
		if classOf image == bitmap then (
			texture = textureLib.AddTexture image.filename
			textureMap = FLMaterialMap filename:texture.filename
		)
	)
	
	OK
)

-- Set bitmap to shader texture
fn SetTextureMap target property textureLib textureMap = if classOf target == DxMaterial and hasProperty target property then (
	local enabledProperty = (property as string + "Enabled") as name
	local enabled = classOf textureLib == FLTextureLibrary and classOf textureMap == FLMaterialMap

	if hasProperty target enabledProperty then setProperty target enabledProperty enabled

	if enabled then (
		local texture = textureLib.GetTexture textureMap.filename
		local image

		if texture != undefined and classOf (image = texture.GetBitmap()) == bitmap then (
			setProperty target property image

			if getFilenameType image.filename == ".dds" then (
				local flipProperty = (property as string + "Flip") as name

				if hasProperty target flipProperty then setProperty target flipProperty true
			)
		) else (
			MAXLancer.WriteLog ("Texture \"" + textureMap.filename + "\" not found for material \"" + target.name + "\".")

			-- TODO: Generate texture placeholder here
		)
	)

	OK
)

fn SetRenderTextureMap target property textureLib textureMap = if hasProperty target property then (
	if classOf textureLib == FLTextureLibrary and classOf textureMap == FLMaterialMap then (
		local texture = textureLib.GetTexture textureMap.filename
		
		if texture != undefined then (
			local image = texture.GetBitmap()
			if classOf image == bitmap then setProperty target property (bitmaptexture bitmap:image)
		)
	)
)

fn GetShaderColor target property &source = if classOf target == DxMaterial and hasProperty target property then (
	local result = getProperty target property

	if classOf result == color then source = copy result
	OK
)

-- Set color in shader to specified values
fn SetShaderColor target property source = if hasProperty target property then (
	local result = getProperty target property

	if classOf result == color then setProperty target property (copy source)
	OK
)

fn ReadDiffuseColor reader &diffuseColor opacity:false default:white = (
	reader.ReadFileColorFloat "Dc" (diffuseColor = default)

	if opacity then (
		local a = reader.ReadFileFloat "Oc"
		if classOf a == Float then diffuseColor.a = a * 255
	)

	OK
)

fn WriteDiffuseColor writer diffuseColor opacity:false default:white = (
	if diffuseColor.r < default.r or diffuseColor.g < default.g or diffuseColor.b < default.b then writer.WriteFileColorFloat "Dc" diffuseColor
	if diffuseColor.a < default.a then writer.WriteFileFloat "Oc" (diffuseColor.a / 255)
	OK
)

-- DcDt, DcDtTwo, DcDtEc, DcDtEcTwo, DcDtOcOt, DcDtOcOtTwo, DcDtEcOcOt, DcDtEcOcOtTwo, EcEt, DcDtEt
struct SinglePassMaterial (
	name,            -- Material name
	technique,       -- Display technique
	diffuseColor,    -- Diffuse color and opacity (color)
	emissionColor,   -- Emission color (color)
	diffuseTexture,  -- Diffuse texture (FLTextureMap)
	emissionTexture, -- Emission texture (FLTextureMap)

	fn Parse target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."

		GetShaderColor target #DiffuseColor  &diffuseColor
		GetShaderColor target #EmissionColor &emissionColor

		GetTextureMap target #DiffuseTexture  textureLib &diffuseTexture
		GetTextureMap target #EmissionTexture textureLib &emissionTexture
		OK
	),

	fn Build target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."

		SetShaderColor target #DiffuseColor  diffuseColor
		SetShaderColor target #EmissionColor emissionColor

		SetTextureMap target #DiffuseTexture  textureLib diffuseTexture
		SetTextureMap target #EmissionTexture textureLib emissionTexture

		SetRenderTextureMap target.renderMaterial #diffuseMap textureLib diffuseTexture

		OK
	),

	fn ReadUTF reader = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		ReadDiffuseColor reader &diffuseColor opacity:true
		reader.ReadFileColorFloat "Ec" (emissionColor = black)

		ReadTextureMap reader "Dt" &diffuseTexture
		ReadTextureMap reader "Et" &emissionTexture
		OK
	),

	fn WriteUTF writer = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		WriteDiffuseColor writer diffuseColor opacity:true
		if emissionColor.r > 0 or emissionColor.g > 0 or emissionColor.b > 0 then writer.WriteFileColorFloat "Ec" emissionColor

		WriteTextureMap writer "Dt" diffuseTexture
		WriteTextureMap writer "Et" emissionTexture
		OK
	)
)

-- BtDetailMapMaterial, BtDetailMapTwoMaterial
struct DetailMaterial (
	name,
	technique,
	diffuseColor,
	diffuseTexture,
	detailTexture,

	fn Parse target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."

		GetShaderColor target #DiffuseColor &diffuseColor

		GetTextureMap target #DiffuseTexture textureLib &diffuseTexture
		GetTextureMap target #DetailTexture  textureLib &detailTexture
		OK
	),

	fn Build target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."

		SetShaderColor target #DiffuseColor diffuseColor

		SetTextureMap target #DiffuseTexture textureLib diffuseTexture
		SetTextureMap target #DetailTexture  textureLib detailTexture
		OK
	),

	fn ReadUTF reader = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		ReadDiffuseColor reader &diffuseColor opacity:false
		ReadTextureMap reader "Dt" &diffuseTexture
		ReadTextureMap reader "Bt" &detailTexture
		OK
	),

	fn WriteUTF writer = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		WriteDiffuseColor writer diffuseColor opacity:false
		WriteTextureMap writer "Dt" diffuseTexture
		WriteTextureMap writer "Bt" detailTexture
		OK
	)
)

-- Nebula, NebulaTwo
struct NebulaMaterial (
	name,
	technique,
	diffuseColor,
	diffuseTexture,

	fn Parse target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."

		GetShaderColor target #DiffuseColor &diffuseColor
		GetTextureMap target #DiffuseTexture textureLib &diffuseTexture
		OK
	),

	fn Build target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."

		SetShaderColor target #DiffuseColor diffuseColor
		SetTextureMap target #DiffuseTexture textureLib diffuseTexture
		OK
	),

	fn ReadUTF reader = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		ReadDiffuseColor reader &diffuseColor opacity:true
		ReadTextureMap reader "Dt" &diffuseTexture
		OK
	),

	fn WriteUTF writer = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		WriteDiffuseColor writer diffuseColor opacity:true
		WriteTextureMap writer "Dt" diffuseTexture
		OK
	)
)

-- GlassMaterial, GFGlassMaterial, HighGlassMaterial
struct GlassMaterial (
	name,
	technique,
	diffuseColor,

	fn Parse target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."

		GetShaderColor target #DiffuseColor &diffuseColor
		OK
	),

	fn Build target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."

		SetShaderColor target #DiffuseColor diffuseColor
		OK
	),

	fn ReadUTF reader = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		ReadDiffuseColor reader &diffuseColor opacity:true
		OK
	),

	fn WriteUTF writer = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		WriteDiffuseColor writer diffuseColor opacity:true
		OK
	)
)

-- PlanetWaterMaterial
struct PlanetWaterMaterial (
	name,
	technique = 0,
	diffuseColor,
	diffuseTexture
)

-- NomadMaterial, NomadMaterialNoBendy
struct NomadMaterial (
	name,
	technique,
	diffuseColor,
	diffuseTexture,
	nomadTexture,

	fn Parse target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."

		GetShaderColor target #DiffuseColor &diffuseColor

		GetTextureMap target #DiffuseTexture textureLib &diffuseTexture
		GetTextureMap target #NomadTexture   textureLib &nomadTexture
		OK
	),

	fn Build target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."

		SetShaderColor target #DiffuseColor  diffuseColor

		SetTextureMap target #DiffuseTexture textureLib diffuseTexture
		SetTextureMap target #NomadTexture   textureLib nomadTexture
		OK
	),

	fn ReadUTF reader = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		ReadDiffuseColor reader &diffuseColor opacity:true
		ReadTextureMap reader "Dt" &diffuseTexture
		ReadTextureMap reader "Nt" &nomadTexture

		-- Default map hardcoded into FLMaterials.dll
		if nomadTexture == undefined then nomadTexture = FLMaterialMap filename:"NomadRGB1_NomadAlpha1" flags:0
		OK
	),

	fn WriteUTF writer = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		WriteDiffuseColor writer diffuseColor opacity:true
		WriteTextureMap writer "Dt" diffuseTexture

		-- No need to write out default map
		if classOf nomadTexture == FLMaterialMap and stricmp nomadTexture.filename "NomadRGB1_NomadAlpha1" != 0 then WriteTextureMap writer "Nt" nomadTexture
		OK
	)
)

struct FLMaterialLibrary (
	materials    = #(), -- Array of SinglePassMaterial/DetailMaterial/etc
	cache        = #(), -- Array of cached DxMaterial associated with materials

	fn ToString stream = (
		format "Material Library (%):\r\n" materials.count to:stream
		
		for m in materials do (
			format "% (0x%): %\r\n" m.name (formattedPrint (MAXLancer.Hash m.name) format:"08X") "" to:stream
		)
	),

	fn GetMaterialArchetype target = (
		case target as name of (
			#SinglePassMaterial: SinglePassMaterial
			#DetailMaterial:     DetailMaterial
			#NebulaMaterial:     NebulaMaterial
			#GlassMaterial:      GlassMaterial
			#NomadMaterial:      NomadMaterial
			default: throw "No matching material struct."
		)
	),

	fn GetMaterial id = (
		id = MAXLancer.hash id

		local result
		for item in materials while result == undefined where MAXLancer.hash item.name == id do result = item
		result -- Return material
	),

	fn GeneratePlaceholder id = (
		local placeholder = SinglePassMaterial name:(formatID id) technique:1 diffuseColor:(random black white) emissionColor:black
		append materials placeholder
		placeholder
	),

	fn GetItem id = GetMaterial id, -- Alias for autoloader

	fn AddMaterial target = (
		local type = MAXLancer.shaders.GetTypeByMaterial target
		if type == undefined then throw "Target material has invalid class or technique."

		local result = GetMaterial target.name
		if result == undefined then append materials target
		OK
	),

	-- Get list of unique texture IDs used by material
	fn GetTextureIDs target = (
		local textureIDs = #(), map
		for name in getPropNames target where classOf (map = getProperty target name) == FLMaterialMap do appendIfUnique textureIDs (MAXLancer.hash map.filename)
		textureIDs -- Return Array of numbers
	),

	-- Parse DxMaterial into material object
	fn Parse target textureLib: = (
		if classOf target != DxMaterial then throw "Invalid DxMaterial object."
		
		local result = MAXLancer.shaders.CreateMaterial target.name (target.getCurrentTechniqueName())
		if result != undefined then result.Parse target textureLib:textureLib

		result -- Return one of Material objects
	),

	fn GetCachedMaterial target = (
		local crc = MAXLancer.Hash target
		local result

		for item in cache while result == undefined where MAXLancer.Hash item.name == crc do result = item
		result
	),

	-- Build material object into DxMaterial
	fn Build target textureLib: useCache:true = (
		
		-- Look for cached DxMaterial
		local result = if useCache then GetCachedMaterial target
			
		if result == undefined then (
			if (mat = GetMaterial target) != undefined then (

				-- Create new DxMaterial
				if (result = MAXLancer.shaders.CreateShader mat) == undefined then throw "Material has no matching shader associated."

				mat.Build result textureLib:textureLib

				-- Add DxMaterial to cache
				if useCache and result != undefined then append cache result
			) else (
				result = standardmaterial name:target
			)
		)

		result -- Return DxMaterial
	),

	-- Read materials from scene
	fn ReadScene filter: textureLib: = (
		local mats = #()

		for m in sceneMaterials do (
			case classOf m of (
				Multimaterial: for sm in m.materialList where classOf sm == DxMaterial do appendIfUnique mats sm
				DxMaterial: appendIfUnique mats m
			)
		)

		for m in meditMaterials do (
			case classOf m of (
				Multimaterial: for sm in m.materialList where classOf sm == DxMaterial do appendIfUnique mats sm
				DxMaterial: appendIfUnique mats m
			)
		)

		for m in mats do (
			local crc = MAXLancer.Hash m.name

			if classOf filter == Array then (
				local found = false
				for filename in filter while not found where MAXLancer.Hash filename == crc do found = true
				if not found then continue
			)

			append cache m
			append materials (Parse m textureLib:textureLib)
		)

		OK
	),

	-- Read materials from UTFReader
	fn ReadUTF reader filter: = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		local item
		local type

		if reader.OpenFolder "Material library" then (
			for filename in (if filter == unsupplied then reader.GetFolders() else filter) where (item = GetMaterial filename) == undefined and reader.OpenFolder filename do (
				filename = reader.ReadName reader.entry.nameOffset -- Get real material name

				type = reader.ReadFileString "Type"

				MAXLancer.WriteLog ("Reading material (" + type + "): " + filename)

				item = MAXLancer.shaders.CreateMaterial filename type
				if item == undefined then throw ("Unsupported material type " + type + " in: " + filename)
				
				item.ReadUTF reader

				append materials item
				reader.CloseFolder() -- Close filename
			)

			reader.CloseFolder() -- Close material library
		)

		OK
	),

	-- Write materials into UTFWriter
	fn WriteUTF writer filter: = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		local item
		local type
		local items = if classOf filter == Array then for filename in filter where (item = GetMaterial filename) != undefined collect item else materials

		if items.count > 0 and writer.OpenFolder "Material library" then (
			for item in items where writer.OpenFolder item.name do (
				type = MAXLancer.shaders.GetTypeByMaterial item

				MAXLancer.WriteLog ("Writing material (" + type + "): " + item.name)
				writer.WriteFileString "Type" type

				item.WriteUTF writer
				writer.CloseFolder() -- Close filename
			)

			writer.WriteFileInteger "Material count" items.count #unsigned
			writer.CloseFolder() -- Close material library
		)

		OK
	),

	-- Load material library from file (.mat)
	fn LoadFile filename filter: = (
		local reader = UTFReader()
		reader.Open filename
		ReadUTF reader filter:filter
		reader.Close()
		OK
	),

	-- Save material library into file (.mat)
	fn SaveFile filename filter: = (
		local writer = UTFWriter()
		writer.Open filename
		WriteUTF writer filter:filter
		writer.Close()
		OK
	)
)

/*
struct FLMaterialAnimation (
	filename,
	deltas = #(),
	offsets = #(),
	flags = #(),

	fn ReadUTF folder = (
		filename = folder.name

		local keyCount = folder.GetInteger "MACount"
		if keyCount == undefined then throw "Material animation is missing MACount entry."

		for k = 1 to keyCount do (
			"MADeltas"
			"MAFlags"

			if k > 1 then (
				"MAKeys"
			)
		)

		OK
	),

	fn WriteUTF writer = (
		writer.StartFolder filename

		writer.EndFolder()
		OK
	)
)

struct FLMaterialAnimationLibrary (
	materials = #(), -- Array of FLMaterialAnimation

	fn ReadUTF reader filter: = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		local folder = reader.root.findFolder "MaterialAnim", result

		if folder != undefined then for subFolder in folder.getChildren type:#folder do (

			result = FLMaterialAnimation()
			result.ReadUTF subFolder
			append materials result
		)

		OK
	),

	fn WriteUTF writer = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		writer.StartFolder "MaterialAnim"
		for m in materials do m.WriteUTF writer
		writer.EndFolder()
		OK
	)
)
*/
