/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Mesh format used by rigid models (ships, stations, scenery, etc).
 *
 * Each LOD of each part in a rigid model uses reference pointer (VMeshRef)
 * which specifies what mesh buffer (VMeshData) to use and within it which
 * groups of triangles (VMeshGroup) to to draw. Each group specifies what
 * material (materialID) is to be used for drawing. Typicaly mesh buffers
 * (VMeshData) would be embedded into model file but that's not always the case.
 * The game would load these buffers as-is and when a rigid part is to be drawn
 * for a visible LOD it would tell GPU to draw each mesh group referenced in
 * VMeshRef while switching shaders and texture buffers between draws.
 */

-- Exportable VMesh attributes
VMeshAttributes = attributes "Level of Detail" attribID:#(0x4C58414D, 0x6873656D) (
	parameters VMeshParameters rollout:VMeshRollout (
		mode       type:#integer animatable:false ui:modeList           default:4
		level      type:#integer animatable:false ui:levelSpinner       default:0
		range      type:#float   animatable:false ui:rangeSpinner       default:1000
		normals    type:#boolean animatable:false ui:normalsCheckbox    default:true
		colors     type:#boolean animatable:false ui:colorsCheckbox     default:false
		maps       type:#integer animatable:false ui:mapsSpinner        default:1
		filename   type:#string  animatable:false ui:filenameText       default:""
	)

	rollout VMeshRollout "Level of Detail" (
		dropdownlist modeList "Primitive Type:" items:#("Points", "Line List", "Line Strip", "Triangle List", "Triangle Strip", "Triangle Fan")

		group "Level of Detail" (
			spinner levelSpinner "Detail Level:" type:#integer range:[0, 9, 0] tooltip:"Level of detail (LOD)."
			spinner rangeSpinner "View Range:" type:#float range:[0, 3.4e38, 1000] tooltip:"Level view distance."
		)

		group "Vertex Data" (
			checkbox colorsCheckbox "Color and Transparency" tooltip:"Export vertex colors (map channels -2 and 0)."
			checkbox normalsCheckbox "Normals" tooltip:"Export vertex normals."
			spinner  mapsSpinner "UV Maps:" type:#integer range:[0, 8, 1] tooltip:"Export texture maps (map channels 1 to 8)."
		)

		editText filenameText "Mesh Library Name:" labelOnTop:true tooltip:"Custom name for mesh library will override default (which derives from filename of exported model)."
	)
)

/**
 * VMeshRefs are composite references to vertex and element buffers in
 * VMeshData. Contains three ranges for material groups, elements and vertices.
 * Additionally bounding box and bounding sphere are stored here. Bounding
 * sphere is used for offscreen culling, starsphere offset, as well as distance
 * and target for HUD wireframe viewport orbit camera.
 *
 * VertexStart is used to provide base offset.
 *
 * Index range isn't used by game, how many elements are being drawn depends on
 * indexCount in VMeshGroup. The game doesn't check if accumulated indexCount
 * from drawing mesh groups exceeds indexCount in VMeshRef.
 */
struct VMeshRef (
	size        = 60,        -- Number of bytes used by structure: 20 header, 24 box, 16 sphere
	meshID      = 0,         -- Mesh hash in VMeshLibrary
	vertexStart = 0,         -- Vertex start offset
	vertexCount = 0,         -- Vertex count
	indexStart  = 0,         -- Index start offset
	indexCount  = 0,         -- Index count
	groupStart  = 0,         -- Mesh group start offset
	groupCount  = 0,         -- Mesh group count
	minimum     = [0, 0, 0], -- Bounding box minimum
	maximum     = [0, 0, 0], -- Bounding box maximum
	center      = [0, 0, 0], -- Bounding sphere center
	radius      = 0,         -- Bounding sphere radius

	fn ReadStream stream = (
		size        = ReadLong  stream #unsigned
		meshID      = ReadLong  stream #unsigned
		vertexStart = ReadShort stream #unsigned
		vertexCount = ReadShort stream #unsigned
		indexStart  = ReadShort stream #unsigned
		indexCount  = ReadShort stream #unsigned
		groupStart  = ReadShort stream #unsigned
		groupCount  = ReadShort stream #unsigned

		maximum.x =  ReadFloat stream
		minimum.x =  ReadFloat stream
		maximum.z =  ReadFloat stream
		minimum.z =  ReadFloat stream
		minimum.y = -ReadFloat stream
		maximum.y = -ReadFloat stream

		ReadPosition stream center
		radius = ReadFloat stream
		OK
	),

	fn WriteStream stream = (
		WriteLong  stream size        #unsigned
		WriteLong  stream meshID      #unsigned
		WriteShort stream vertexStart #unsigned
		WriteShort stream vertexCount #unsigned
		WriteShort stream indexStart  #unsigned
		WriteShort stream indexCount  #unsigned
		WriteShort stream groupStart  #unsigned
		WriteShort stream groupCount  #unsigned

		WriteFloat stream  maximum.x
		WriteFloat stream  minimum.x
		WriteFloat stream  maximum.z
		WriteFloat stream  minimum.z
		WriteFloat stream -minimum.y
		WriteFloat stream -maximum.y

		WritePosition stream center
		WriteFloat stream radius
		OK
	),

	fn ReadUTF reader = if reader.OpenFile "VMeshRef" then ReadStream reader.data else throw "Error reading VMeshRef",

	fn WriteUTF writer = if writer.OpenFile "VMeshRef" then WriteStream writer.data else throw "Error writing VMeshRef",

	fn Extend p = (
		minimum.x = amin minimum.x p.x
		minimum.y = amin minimum.y p.y
		minimum.z = amin minimum.z p.z

		maximum.x = amax maximum.x p.x
		maximum.y = amax maximum.y p.y
		maximum.z = amax maximum.z p.z

		center = 0.5 * (minimum + maximum)
		radius = 0.5 * distance minimum maximum

		OK
	),

	fn BuildBox parent = dummy name:(parent.name + "_Box") boxSize:(maximum - minimum) parent:parent transform:(PreTranslate parent.transform (0.5 * (minimum + maximum))),

	fn BuildSphere parent = SphereGizmo name:(parent.name + "_Sphere") radius:radius parent:parent transform:(PreTranslate parent.transform center)
)

/**
 * Mesh group specifies material ID used for drawing, vertex range and element
 * indices count.
 */
struct VMeshGroup (
	materialID  = 0,
	vertexStart = 0,
	vertexEnd   = 0,
	indexCount  = 0,
	padding     = 0xCC,

	fn ReadStream stream = (
		materialID  = ReadLong stream #unsigned
		vertexStart = ReadShort stream #unsigned
		vertexEnd   = ReadShort stream #unsigned
		indexCount  = ReadShort stream #unsigned
		padding     = ReadShort stream #unsigned
		OK
	),

	fn WriteStream stream = (
		WriteLong  stream materialID  #unsigned
		WriteShort stream vertexStart #unsigned
		WriteShort stream vertexEnd   #unsigned
		WriteShort stream indexCount  #unsigned
		WriteShort stream padding     #unsigned
		OK
	)
)

/**
 * Freelancer support D3DFVF_XYZ, D3DFVF_NORMAL, D3DFVF_DIFFUSE and D3DFVF_TEX0
 * to D3DFVF_TEX8. D3DFVF_PSIZE and D3DFVF_SPECULAR are not supported and will
 * result in corrupted drawing.
 */
struct VMeshFVF (
	positions = true,  -- D3DFVF_XYZ
	normals   = false, -- D3DFVF_NORMAL
	colors    = false, -- D3DFVF_DIFFUSE
	maps      = 0,     -- D3DFVF_TEX1 to D3DFVF_TEX8

	fn GetMask = (
		local result = 0 
		
		result = bit.set result 2 positions
		result = bit.set result 5 normals
		result = bit.set result 7 colors
		result = bit.or result (bit.shift maps 8)

		result -- Return Integer
	),

	fn SetMask bitmask = (
		positions = bit.get bitmask 2
		normals   = bit.get bitmask 5
		colors    = bit.get bitmask 7
		maps      = bit.shift (bit.and bitmask 0xF00) -8

		OK
	),

	fn ReadStream stream = SetMask (ReadShort stream #unsigned),
	fn WriteStream stream = WriteShort stream (GetMask()) #unsigned
)

/**
 * Compound mesh buffer contains list of mesh groups, element and vertex
 * buffers. Direct3D FVF bitmask identifies attributes for vertex buffer. Mesh
 * buffer uses 16-bit indices.
 */
struct VMeshData (
	filename     = "",         -- Filename in VMeshLibrary, ex: "data.jinx.trash.lod0-110.vms"
	version      = 1,          -- Unknown (anything other than 1 renders nothing and crashes the game)
	mode         = 4,          -- Direct3D Primitive (1 = Point list, 2 = Line list, 3 = Line strip, 4 = Triangle list, 5 = Triangle strip, 6 = Triangle fan)
	vertexFormat = VMeshFVF(), -- Direct3D Flexible Vertex Format
	vertexCount  = 0,          -- Vertex count (positions, normals, colors and maps[m] count must be equal this value)
	groups       = #(),        -- Array of VMeshGroup
	indices      = #(),        -- Array of Integer
	positions    = #(),        -- Array of point3: vertex coordinates
	normals      = #(),        -- Array of point3: vertex normals
	colors       = #(),        -- Array of color: vertex color tint and alpha
	maps         = #(),        -- Arrays of point3: vertex UV maps
	faceSGroups  = #(),        -- Array of Integer (bitmask per face)
	faceFlags    = #(),        -- Array of Integer (bitmask per face)

	on create do for m = 1 to vertexFormat.maps do maps[m] = #(),

	fn GetFaceCount = (
		case mode of (
			4: indices.count / 3
			5: indices.count - 2
			6: indices.count - 1
			default: 0
		)
	),

	fn ReadStream stream buffers:true = (
		version       = ReadLong  stream #unsigned
		mode          = ReadLong  stream #unsigned
		groups.count  = ReadShort stream #unsigned
		indices.count = ReadShort stream #unsigned

		vertexFormat.ReadStream stream

		vertexCount = ReadShort stream #unsigned

		if vertexFormat.maps > 8 then throw "Texture count exceeds limit of 8"

		-- Preallocate positions, normals and colors
		if vertexFormat.positions then positions.count = vertexCount
		if vertexFormat.normals   then normals.count   = vertexCount
		if vertexFormat.colors    then colors.count    = vertexCount

		-- Preallocate UV maps
		for m = 1 to vertexFormat.maps do (maps[m] = #()).count = vertexCount

		-- Read mesh groups
		for g = 1 to groups.count do (groups[g] = VMeshGroup()).ReadStream stream

		if buffers then (

			-- Read triangle indices
			for i = 1 to indices.count do indices[i] = ReadShort stream #unsigned	

			-- Read vertex buffer
			for v = 1 to vertexCount do (
				if vertexFormat.positions then ReadPosition     stream (positions[v] = [0, 0, 0])
				if vertexFormat.normals   then ReadPosition     stream (normals[v]   = [0, 0, 0])
				if vertexFormat.colors    then ReadColorInteger stream (colors[v]    = white)

				for m = 1 to vertexFormat.maps do maps[m][v] = [ReadFloat stream, ReadFloat stream, 0]
			)
		)

		OK
	),

	fn WriteStream stream = (
		WriteLong  stream version       #unsigned
		WriteLong  stream mode          #unsigned
		WriteShort stream groups.count  #unsigned
		WriteShort stream indices.count #unsigned

		vertexFormat.WriteStream stream

		WriteShort stream vertexCount   #unsigned

		if vertexFormat.maps > 8 then throw "Texture count exceeds limit of 8"

		-- Write mesh groups
		for g = 1 to groups.count do groups[g].WriteStream stream

		-- Write triangle indices
		for i = 1 to indices.count do WriteShort stream indices[i] #unsigned
		
		-- Write vertex buffer
		for v = 1 to vertexCount do (
			if vertexFormat.positions then WritePosition     stream positions[v]
			if vertexFormat.normals   then WritePosition     stream normals[v]
			if vertexFormat.colors    then WriteColorInteger stream colors[v]

			for m = 1 to vertexFormat.maps do WritePoint2 stream maps[m][v]
		)

		OK
	),

	fn ReadUTF reader buffers:true = (
		if reader.OpenFile "VMeshData" then ReadStream reader.data buffers:buffers else throw "Error reading VMeshData"

		local faceCount = GetFaceCount()

		-- Read face data for triangle list
		if faceCount > 0 and reader.OpenFile "FaceData" then (
			faceSGroups = for f = 1 to faceCount collect ReadLong reader.data #unsigned
			faceFlags   = for f = 1 to faceCount collect ReadByte reader.data #unsigned
		)

		OK
	),

	fn WriteUTF writer = (
		if writer.OpenFile "VMeshData" then WriteStream writer.data else throw "Error writing VMeshData"

		local faceCount = GetFaceCount()

		-- Write face data for triangle list
		if faceSGroups.count == faceCount and faceFlags.count == faceCount and writer.OpenFile "FaceData" then (
			for f = 1 to faceCount do WriteLong writer.data faceSGroups[f] #unsigned
			for f = 1 to faceCount do WriteByte writer.data faceFlags[f]   #unsigned
		)

		OK
	),

	-- Append VMeshData block
	fn AppendData meshData = (
		if classOf meshData != VMeshData then throw "Invalid VMeshData object"
		if mode != meshData.mode then throw "VMeshData primitive type mismatch"
		if vertexFormat.GetMask() != meshData.vertexFormat.GetMask() then throw "VMeshData vertex format mismatch"
		if groups.count + meshData.groups.count > 0xFFFF then throw "Too many VMeshData groups"
		if indices.count + meshData.indices.count > 0xFFFF then throw "Too many VMeshData indices"
		if vertexCount + meshData.vertexCount > 0xFFFF then throw "Too many VMeshData vertices"

		join groups  meshData.groups
		join indices meshData.indices
		
		if vertexFormat.positions then join positions meshData.positions
		if vertexFormat.normals   then join normals   meshData.normals
		if vertexFormat.colors    then join colors    meshData.colors

		for m = 1 to vertexFormat.maps do join maps[m] meshData.maps[m]

		vertexCount += meshData.vertexCount
		OK
	),

	-- Parse target Editable_mesh as triangle list into VMeshData and produce VMeshRef
	fn Parse target materialLib: textureLib: progress: hashDecimal: smoothingGroups:false = (
		if superClassOf target != GeometryClass then throw "Invalid LOD mesh object"
		if (custAttributes.get target VMeshAttributes) == undefined then throw "LOD mesh does not have VMeshAttributes"

		if hashDecimal == unsupplied then hashDecimal = MAXLancer.hashDecimal

		-- Create snapshot from target
		local targetSnap = snapShot target
		hide targetSnap

		try (
			local hasVertexColor = meshOp.getMapSupport targetSnap 0
			local hasVertexAlpha = meshOp.getMapSupport targetSnap -2
			local hasVertexMaps  = #{}

			for m = 1 to vertexFormat.maps do hasVertexMaps[m] = meshOp.getMapSupport targetSnap m

			local meshRef = VMeshRef meshID:(MAXLancer.hash filename) groupStart:groups.count indexStart:indices.count vertexStart:vertexCount radius:0.0 minimum:[3.4e38, 3.4e38, 3.4e38] maximum:[-3.4e38, -3.4e38, -3.4e38]

			-- Specify center
			meshRef.center = if classOf target.parent == RigidPartHelper and target.parent.zerocenter then [0, 0, 0] else in coordsys target.parent target.pivot

			local materials = #()
			local faces     = #()

			-- Collect faces into bitArrayed grouped by submaterials
			GetMeshMaterials targetSnap &materials &faces

			-- Check that faces isn't empty
			if materials.count == 0 or faces.count == 0 then throw ("LOD mesh " + target.name + " has no valid materials/faces to export")

			-- Push materials to material and texture libraries
			if classOf materialLib == FLMaterialLibrary then for item in materials do materialLib.AddMaterial (materialLib.Parse item textureLib:textureLib)

			local normalsMod 

			-- Add Edit_Normals modifier for Auto/Explicit normals mode
			if vertexFormat.normals then (
				normalsMod = Edit_Normals displayLength:0
				addModifier targetSnap normalsMod
				select targetSnap
				max modify mode
			)

			-- Extend arrays in VMeshData pre-allocating space for elements and attributes.
			local allocateCount = 0
			for f in faces do allocateCount += f.numberSet * 3

			MAXLancer.WriteLog ("Preallocated " + formattedPrint allocateCount format:"u" + " vertices in: " + filename)

			if vertexFormat.positions then positions.count = vertexCount + allocateCount
			if vertexFormat.normals   then normals.count   = vertexCount + allocateCount
			if vertexFormat.colors    then colors.count    = vertexCount + allocateCount

			for m = 1 to vertexFormat.maps do maps[m].count = vertexCount + allocateCount

			local meshGroup      -- Current mesh group (VMeshGroup)
			local faceVertices   -- Face vertices in Editable_mesh
			local faceColors     -- Face vertices color (channel 0)
			local faceAlphas     -- Face vertices alpha (channel -2)
			local faceMaps       -- Face vertices UV maps
			local faceData       -- Face flags data
			local diffuseAlpha   -- Vertex diffuse alpha component
			local diffuseColor   -- Vertex diffuse color	

			local vertexPosition -- Vertex position (Point3)
			local vertexNormal   -- Vertex normal (Point3)
			local vertexColor    -- Vertex diffuse (Color)
			local vertexMaps     -- Vertex UVs (array of Point3)
			local vertexIndex    -- Vertex index in VMeshData relative to VMeshGroup.vertexStart + VMeshRef.vertexStart
			local vertexHash     -- Number

			local groupHashes = #() -- Array of Number

			-- Process material faces into mesh groups
			in coordsys target.parent for m = 1 to materials.count do (
				if groups.count >= 0xFFFF then throw "Too many VMeshData groups"

				if faces[m].numberSet == 0 then (
					MAXLancer.WriteLog ("Mesh group " + formattedPrint m format:"u" + ": " + materials[m].name + " has no faces")
					continue
				)

				meshGroup  = VMeshGroup materialID:(MAXLancer.Hash materials[m].name) vertexStart:meshRef.vertexCount
				vertexMaps = #()

				groupHashes.count = 0

				MAXLancer.WriteLog ("Mesh group " + formattedPrint m format:"u" + ": " + materials[m].name  + " (" + formatID meshGroup.materialID + ") with " + formattedPrint faces[m].numberSet + " faces")
				
				-- Process faces into index and vertex buffers
				for f in faces[m] do (
					faceData     = 0
					faceVertices = getFace targetSnap f
					faceAlphas   = if hasVertexAlpha then meshOp.getMapFace targetSnap -2 f
					faceColors   = if hasVertexColor then meshOp.getMapFace targetSnap 0 f
					faceMaps     = for m = 1 to vertexFormat.maps collect meshop.getMapFace targetSnap m f

					-- Collect smoothing groups
					if smoothingGroups then append faceSGroups (getFaceSmoothGroup targetSnap f)

					-- Face verteices/edges
					for i = 1 to 3 do (
						if indices.count >= 0xFFFF then throw "Too many VMeshData indices"

						-- Vertex position (relative to target.parent)
						vertexPosition = meshOp.getVert targetSnap faceVertices[i]
						vertexHash = MAXLancer.Hash (RoundPoint3 vertexPosition hashDecimal)

						-- Update VMeshRef bounding box
						meshRef.minimum.x = amin meshRef.minimum.x vertexPosition.x
						meshRef.minimum.y = amin meshRef.minimum.y vertexPosition.y
						meshRef.minimum.z = amin meshRef.minimum.z vertexPosition.z

						meshRef.maximum.x = amax meshRef.maximum.x vertexPosition.x
						meshRef.maximum.y = amax meshRef.maximum.y vertexPosition.y
						meshRef.maximum.z = amax meshRef.maximum.z vertexPosition.z

						-- Update VMeshRef bounding sphere
						meshRef.radius = amax meshRef.radius (distance meshRef.center vertexPosition)

						-- Vertex normal (relative to target.parent)
						if vertexFormat.normals then (
							vertexNormal = normalsMod.GetNormal (normalsMod.GetNormalID f i)
							vertexHash = MAXLancer.Hash (RoundPoint3 vertexNormal hashDecimal) crc:vertexHash
						)

						-- Write edge visibility into face flag as first three bits
						faceData = bit.set faceData i (getEdgeVis targetSnap f i)

						-- Vertex diffuse color and transparency
						if vertexFormat.colors then (
							diffuseAlpha = 0xFF * (if hasVertexAlpha then meshOp.getMapVert targetSnap -2 faceAlphas[i] else [1, 1, 1])
							diffuseColor = 0xFF * (if hasVertexColor then meshOp.getMapVert targetSnap 0 faceColors[i] else [1, 1, 1])
							vertexColor  = color diffuseColor.x diffuseColor.y diffuseColor.z ((diffuseAlpha.x + diffuseAlpha.y + diffuseAlpha.z) / 3)
							vertexHash   = MAXLancer.Hash vertexColor crc:vertexHash
						)
						
						-- Vertex texture maps
						for m = 1 to faceMaps.count do (
							vertexMaps[m] = if hasVertexMaps[m] then meshOp.getMapVert targetSnap m faceMaps[m][i] else [0, 0, 0]
							vertexHash    = MAXLancer.Hash (RoundPoint3 vertexMaps[m] hashDecimal) crc:vertexHash
						)

						vertexIndex = findItem groupHashes vertexHash

						-- When no match was found add vertex attribute to buffer
						if vertexIndex == 0 then (
							if vertexCount >= 0xFFFF then throw "Too many VMeshData vertices"

							vertexIndex = vertexCount += 1 -- Increment number of unique vertex attributes in VMeshData

							if vertexFormat.positions then positions[vertexIndex] = vertexPosition
							if vertexFormat.normals   then normals[vertexIndex]   = vertexNormal
							if vertexFormat.colors    then colors[vertexIndex]    = vertexColor

							for m = 1 to vertexFormat.maps do maps[m][vertexIndex] = vertexMaps[m]

							meshRef.vertexCount += 1 -- Increment number of unique vertices in VMeshRef

							-- Remove this in case I would need to revert back to groupPositions/groupIndices
							vertexIndex -= meshRef.vertexStart + meshGroup.vertexStart + 1

							append groupHashes vertexHash
						) else vertexIndex -= 1 -- Remove this in case I would need to revert back to groupPositions/groupIndices

						-- Push vertex data into VMeshData and get associated vertexIndex within VMeshGroup (!)
						append indices vertexIndex

						-- Add index to element list and increment element counts
						meshGroup.indexCount += 1
						meshRef.indexCount += 1
					)

					append faceFlags faceData

					meshGroup.vertexEnd = meshRef.vertexCount - 1

					if classOf progress == MAXScriptFunction then progress 3
				)

				-- Push VMeshGroup into VMeshData
				append groups meshGroup
				meshRef.groupCount += 1
			)

			-- Shrink element and attribute arrays to their factual count.
			if vertexFormat.positions then positions.count = vertexCount
			if vertexFormat.normals   then normals.count   = vertexCount
			if vertexFormat.colors    then colors.count    = vertexCount

			for m = 1 to vertexFormat.maps do maps[m].count = vertexCount

			MAXLancer.WriteLog ("Written " + formattedPrint meshRef.vertexCount format:"u" + " vertices in: " + filename)
			MAXLancer.WriteLog (formattedPrint faceSGroups.count format:"u" + " faces for smoothing groups")

			delete targetSnap

			meshRef -- Return VMeshRef
		) catch (
			delete targetSnap

			throw()
		)
	),	

	-- Build Line from VWireData
	fn BuildWire parent wireData = (
		if not isValidNode parent then throw "Invalid parent node to build wire"
		if classOf wireData != VWireData then throw "Invalid VWireData object"
		if wireData.meshID != MAXLancer.Hash filename then throw "Mismatched meshID"

		local result = Line name:(formatID wireData.meshID) parent:parent transform:parent.transform
		local index

		in coordsys local for i = 1 to wireData.indices.count by 2 do (
			index = addNewSpline result

			addKnot result index #corner #line positions[wireData.vertexStart + 1 + wireData.indices[i + 0]]
			addKnot result index #corner #line positions[wireData.vertexStart + 1 + wireData.indices[i + 1]]
		)

		updateShape result
		result -- Return Line
	),

	-- Builds Editable_mesh from VMeshRef
	fn Build parent meshRef smoothingGroups:false materialLib: textureLib: progress: = (
		if not isValidNode parent then throw "Invalid parent node to build mesh"
		if classOf meshRef != VMeshRef then throw "Invalid VMeshRef object"
		if meshRef.meshID != MAXLancer.Hash filename then throw "Mismatched meshID"

		local indexStart  = meshRef.indexStart
		local faces       = #() -- Array of Point3
		local materialIDs = #() -- Array of Integer

		-- Validate boundary ranges
		if meshRef.groupStart  + meshRef.groupCount  > groups.count then throw "Referenced group range exceeds VMeshData boundary"
		if meshRef.indexStart  + meshRef.indexCount  > indices.count then throw "Referenced index range exceeds VMeshData boundary"
		if meshRef.vertexStart + meshRef.vertexCount > vertexCount then throw "Referenced vertex range exceeds VMeshData boundary"

		-- Collect faces and unique materialIDs
		for g = 1 to meshRef.groupCount do (
			for i = indexStart + 1 to indexStart += groups[meshRef.groupStart + g].indexCount by 3 do
				append faces ([indices[i], indices[i + 1], indices[i + 2]] + groups[meshRef.groupStart + g].vertexStart + 1)

			appendIfUnique materialIDs groups[meshRef.groupStart + g].materialID
		)

		local faceIndex          = meshRef.indexStart / 3
		local faceSmoothGroup    = 0
		local hasSmoothingGroups = classOf faceSGroups == Array and faceSGroups.count >= faceIndex + faces.count
		local hasFaceFlags       = classOf faceFlags == Array and faceFlags.count >= faceIndex + faces.count

		-- Create mesh
		local result = mesh name:(formatID meshRef.meshID) vertices:(for v = 1 to meshRef.vertexCount collect positions[meshRef.vertexStart + v]) faces:faces backFaceCull:true parent:parent transform:parent.transform
		
		-- Set channels for additional UVs
		if vertexFormat.maps > 1 then meshop.setNumMaps result (vertexFormat.maps + 1)

		-- Create UV map channels and pre-allocate buffers
		for m = 1 to vertexFormat.maps do (
			meshOp.setMapSupport result m true
			meshOp.setMapSupport result m meshRef.vertexCount
		)

		-- Enable vertex color and alpha channels, pre-allocate buffers
		if vertexFormat.colors then (
			meshOp.setMapSupport result 0 true
			meshOp.setMapSupport result -2 true

			meshOp.setNumMapVerts result 0 meshRef.vertexCount
			meshOp.setNumMapVerts result -2 meshRef.vertexCount
		)

		-- Apply channel map indices to face vertices (UVs, vertex color, alpha)
		for f = 1 to faces.count do (
			faceIndex += 1
			
			faceSmoothGroup = if vertexFormat.normals then 0 else 1

			-- Set smoothing group
			if hasSmoothingGroups then faceSmoothGroup = faceSGroups[faceIndex]
			if smoothingGroups then setFaceSmoothGroup result f faceSmoothGroup
			
			-- Set UV maps indices
			for m = 1 to vertexFormat.maps do meshOp.setMapFace result m f faces[f]

			-- Set edge visibility
			if hasFaceFlags then for i = 1 to 3 do setEdgeVis result f i (bit.get faceFlags[faceIndex] i)

			-- Set vertex color and alpha map indices
			if vertexFormat.colors then (
				meshOp.setMapFace result 0 f faces[f]
				meshOp.setMapFace result -2 f faces[f]
			)
		)

		local vertexColor

		-- Set vertex properties
		for v = 1 to meshRef.vertexCount do (

			-- Set UV maps
			for m = 1 to vertexFormat.maps do meshOp.setMapVert result m v maps[m][meshRef.vertexStart + v]

			-- Set vertex color and alpha values
			if vertexFormat.colors then (
				vertexColor = colors[meshRef.vertexStart + v] / 255

				meshOp.setMapVert result 0  v vertexColor
				meshOp.setMapVert result -2 v [vertexColor.a, vertexColor.a, vertexColor.a]
			)

			-- Set vertex normal
			if vertexFormat.normals then in coordsys local setNormal result v normals[meshRef.vertexStart + v]
		)

		-- Apply materials (MultiMaterial)
		local faceIndex = 0
		local materials = #()
		local meshGroup

		-- TODO: Use single material if there's only one meshGroup
		result.material = MultiMaterial name:result.name numsubs:materialIDs.count

		-- Create submaterials
		for m = 1 to materialIDs.count do (
			result.material.materialList[m] = if classOf materialLib == FLMaterialLibrary then materialLib.Build materialIDs[m] textureLib:textureLib else Standardmaterial name:(formatID materialIDs[m])
			result.material.names[m] = result.material.materialList[m].name
		)

		-- Assign submaterials to faces
		for g = 1 to meshRef.groupCount do (
			meshGroup = groups[meshRef.groupStart + g]

			for f = faceIndex + 1 to faceIndex += meshGroup.indexCount / 3 do setFaceMatID result f (findItem materialIDs meshGroup.materialID)

			-- Update progress
			if classOf progress == MAXScriptFunction then progress meshGroup.indexCount
		)

		custAttributes.add result VMeshAttributes

		result.normals = vertexFormat.normals
		result.colors  = vertexFormat.colors
		result.maps    = vertexFormat.maps
		
		result -- Return Editable_mesh
	)
)

/**
 * Line buffer containing pairs of vertex indices between which lines are to be
 * drawn for HUD wireframe display in contact list. I generate these from spline
 * objects whose knots are near vertices of editable mesh the spline is attached
 * to. Wireframes in Freelancer models were typically generated from visible
 * edges of a LOD mesh.
 */
struct VWireData (
	size        = 16,
	meshID      = 0,   -- Referenced mesh in mesh library
	vertexCount = 0,   -- Number of unique vertex IDs
	vertexStart = 0,   -- Offset to first referenced vertex
	vertexRange = 0,   -- Range of vertices used by wireframe lines
	indices     = #(), -- Element indices to draw line list

	fn ReadStream stream = (
		size          = ReadLong  stream #unsigned
		meshID        = ReadLong  stream #unsigned
		vertexStart   = ReadShort stream #unsigned
		vertexCount   = ReadShort stream #unsigned
		indices.count = ReadShort stream #unsigned
		vertexRange   = ReadShort stream #unsigned

		for i = 1 to indices.count do indices[i] = ReadShort stream #unsigned
		OK
	),

	fn WriteStream stream = (
		local vertices = makeUniqueArray indices

		vertexCount = vertices.count
		vertexRange = amax vertices - amin vertices

		WriteLong  stream size          #unsigned
		WriteLong  stream meshID        #unsigned
		WriteShort stream vertexStart   #unsigned
		WriteShort stream vertexCount   #unsigned
		WriteShort stream indices.count #unsigned
		WriteShort stream vertexRange   #unsigned

		for i = 1 to indices.count do WriteShort stream indices[i] #unsigned
		OK
	),

	fn ReadUTF reader = if reader.OpenFile "VWireData" then ReadStream reader.data else throw "Error reading VWireData",

	fn WriteUTF writer = if writer.OpenFile "VWireData" then WriteStream writer.data else throw "Error writing VWireData",
	
	-- Add sequence of lines (Array of Point2)
	fn AppendLines points = (
		local a, b
		local duplicate
		local result = 0
		
		for p in points do (
			duplicate = p.x == p.y
			
			-- Check for duplicate and reverse duplicate
			for i = 1 to indices.count by 2 while not duplicate where (indices[i] == p.x and indices[i + 1] == p.y) or (indices[i] == p.y and indices[i + 1] == p.x) do duplicate = true
			
			if not duplicate then (
				if indices.count >= 0xFFFF then throw "Too many wireframe indices"
					
				append indices p.x
				append indices p.y
				
				result += 2
			)
		)
		
		result -- Return Integer (number of actual indices added)
	)
)

/**
 * Library contains mesh buffers used by rigid models for drawing LOD meshes and
 * HUD wireframes.
 */
struct VMeshLibrary (
	meshes = #(), -- Array of VMeshData

	-- Get VMeshData from library by ID (string or hash number)
	fn GetMesh id = (
		id = MAXLancer.hash id

		local result
		for m in meshes while result == undefined where MAXLancer.Hash m.filename == id do result = m
		result -- Return VMeshData
	),

	fn GetItem id = GetMesh id, -- Alias for autoloader

	fn IsValidMesh target = isValidNode target and superClassOf target == GeometryClass and custAttributes.get target VMeshAttributes != undefined,

	-- Get array of Editable_mesh with VMeshAttributes for model
	fn GetPartLevels target &wireframe = (
		if classOf target != RigidPartHelper then throw "Invalid rigid part helper object"

		local result = #()

		-- LOD meshes must not have same level
		for child in target.children do case of (
			(VMeshLibrary.IsValidMesh child): if result[child.level + 1] == undefined then result[child.level + 1] = child else
				throw ("Duplicate level " + formattedPrint child.level format:"u" + " for " + target.name + " found in " + child.name)
			(superClassOf child == shape): wireframe = child
		)

		-- Ensure there are no gaps and grab wireframe
		for i = 1 to result.count do (
			if result[i] == undefined do throw ("Missing mesh for level " + formattedPrint (i - 1) format:"u" + " in " + target.name)

			-- Wireframe is a shape object attached to one of the LOD meshes (using visible edges is deprecated)
			-- if wireframe == undefined and result[i].wireframe then wireframe = result[i]
			for child in result[i].children while wireframe == undefined where superClassOf child == shape do wireframe = child
		)

		result -- Return array of Editable_mesh with VMeshAttributes
	),

	-- Get list of unique material IDs used by VMeshGroups specified in VMeshRef
	fn GetMaterialIDs meshRef = (
		if classOf meshRef != VMeshRef then throw "Invalid VMeshRef object"
		
		local meshData = GetMesh meshRef.meshID
		if classOf meshData != VMeshData then throw "Referenced mesh not found"

		if meshRef.groupStart + meshRef.groupCount > meshData.groups.count then throw "Referenced group range exceeds VMeshData boundary"

		local materialIDs = #()
		for g = 1 to meshRef.groupCount do appendIfUnique materialIDs meshData.groups[meshRef.groupStart + g].materialID
		materialIDs -- Return Array of numbers
	),

	-- Create full buffer name from relative path to Freelancer and result filename, LOD level and 
	fn GenerateBufferName filename type vertexFormat prefixPath:true = (
		if classOf filename != string then throw "Invlaid buffer filename"
		if classOf type != string then throw "Invalid buffer type"
		if classOf vertexFormat != VMeshFVF then throw "Invalid VMeshFVF object"

		local result = StringStream ""

		-- Get path relative to freelancerPath
		if prefixPath and MAXLancer.freelancerPath != undefined then (
			filename = pathConfig.convertPathToRelativeTo filename MAXLancer.freelancerPath

			-- If path lies within freelancerPath remove initial ".\" and replace slashes with dots
			if substring filename 1 2 == ".\\" then filename = substring (substituteString filename "\\" ".") 3 -1
		)

		format "%.%-%.vms" (toLower (getFilenameFile filename)) type (formattedPrint (vertexFormat.GetMask()) format:"x") to:result

		result as string -- Return String
	),

	-- Create internal filename based on target attributes and supplied filename, find existing VMeshData matching internal filename or create new one
	fn CreateBuffer target filename = (
		if not isValidNode target then throw (target.name + " is not a valid scene node")
		if classOf filename != string then throw "Invalid buffer filename"

		-- Minimally VMeshData will contain vertex positions (D3DFVF_XYZ)
		local vertexFormat = VMeshFVF()

		local buffername = case of (
			(MAXLancer.IsRigidLevel target): (
				local attribs = custAttributes.get target VMeshAttributes

				-- VMeshData will contain diffuse color (D3DFVF_DIFFUSE)
				vertexFormat.colors = attribs.colors

				-- VMeshData will contain normals (D3DFVF_NORMAL)
				vertexFormat.normals = attribs.normals

				-- VMeshData will contain one or more UV maps (D3DFVF_TEX1 to D3DFVF_TEX8)
				if attribs.maps > 0 then vertexFormat.maps = attribs.maps

				GenerateBufferName (if attribs.filename.count > 0 then attribs.filename else filename) ("lod" + formattedPrint attribs.level format:"u") vertexFormat prefixPath:(attribs.filename.count == 0)
			)
			(superClassOf target == shape): GenerateBufferName filename "wire" vertexFormat
		)

		if buffername == undefined then throw (target.name + " has no mesh buffer name")

		-- Find existing VMeshData to append buffers
		local result = GetMesh buffername

		-- Create new VMeshData if no matching VMeshData exist add to library
		if result == undefined then (
			result = VMeshData filename:buffername vertexFormat:vertexFormat

			if superClassOf target == shape then result.mode = 2 -- Set line list for shape

			append meshes result
		)

		-- Check mode and format
		if result.vertexFormat.GetMask() != vertexFormat.GetMask() then throw ("Mismatched vertex format for object " + target.name + " in buffer " + buffername)
		
		result -- Return VMeshData
	),

	/**
	 * Build array of VMeshRefs (levels) into editable meshes, and VWireData
	 * into line shape. Resulting wireframe line shape will re-attach to mesh
	 * whose VMeshRef meshID matched VWireData meshID.
	 */
	fn BuildLevels target levels ranges wireframe wireframes:true boundaries:false smoothingGroups:false materialLib: textureLib: progress: = (
		if classOf target != RigidPartHelper then throw "Invalid RigidPartHelper object"

		local partWire  -- Line object representing part wireframe
		local meshData  -- VMeshData
		local meshRef   -- VMeshRef
		local levelMesh -- Editable_mesh
		local title     -- String
		local hidden

		-- Build VWireData into Line
		if wireframes and classOf wireframe == VWireData and wireframe.indices.count > 0 then (
			MAXLancer.WriteLog ("Building wireframe: " + formatID wireframe.meshID)

			meshData = GetMesh wireframe.meshID
			if classOf meshData != VMeshData then throw ("Referenced mesh not found: " + formatID wireframe.meshID)

			partWire = meshData.BuildWire target wireframe
			partWire.name      = target.name + "_Wire"
			partWire.wireColor = target.wireColor

			AddToLayer "Wireframes" partWire
		)

		-- Build levels
		if classOf levels == Array then for i = 1 to levels.count do (
			meshRef = levels[i]
			title   = "Level" + formattedPrint (i - 1) format:"u"
			hidden  = i > 1

			if classOf meshRef != VMeshRef then throw ("Invalid VMeshRef at level " + formattedPrint (i - 1) format:"u" + " in " + target.name)

			if boundaries then (
				AddToLayer title (meshRef.BuildBox target) hidden:hidden
				AddToLayer title (meshRef.BuildSphere target) hidden:hidden
			)

			-- Skip empty VMeshRefs
			if meshRef.meshID == 0 or meshRef.groupCount == 0 or meshRef.indexCount == 0 or meshRef.vertexCount == 0 then continue

			meshData = GetMesh meshRef.meshID
			if classOf meshData != VMeshData then throw ("Referenced mesh not found: " + formatID meshRef.meshID)

			-- Build level boundaries
			levelMesh = meshData.Build target meshRef smoothingGroups:smoothingGroups materialLib:materialLib textureLib:textureLib progress:progress
			
			levelMesh.name  = target.name + "_" + title
			levelMesh.level = i - 1
			levelMesh.pivot = meshRef.center * target.transform

			if classOf ranges == Array and ranges[i + 1] != undefined then levelMesh.range = ranges[i + 1]

			AddToLayer title levelMesh hidden:hidden

			if partWire != undefined and meshRef.meshID == wireframe.meshID then partWire.parent = levelMesh
		)

		OK
	),

	-- Parse shape object into special mesh buffer
	fn ParseFreeShape target meshData origin hashDecimal: progress: = (

		if hashDecimal == unsupplied then hashDecimal = MAXLancer.hashDecimal

		local wireData = VWireData meshID:(MAXLancer.Hash meshData.filename) vertexStart:meshData.vertexCount

		local firstIndex     -- Spline first knot vertex index
		local previousIndex  -- Previous knot vertex index
		local vertexIndex    -- Current knot vertex index
		local knotPosition   -- Current knot position vector
		local knotHash       -- Current knot position vector hash
		local vertexPosition -- Lookup vertex position vector
		local edges = #()    -- Array of Point2

		MAXLancer.WriteLog ("Parsing freeform wireframe (" + meshData.filename + "): " + target.name)

		local vertexHashes = #()

		in coordsys origin for s = 1 to numSplines target do (
			firstIndex = previousIndex = 0

			for k = 1 to numKnots target s do (
				knotPosition = getKnotPoint target s k
				knotHash     = MAXLancer.Hash (RoundPoint3 knotPosition hashDecimal)
				vertexIndex  = findItem vertexHashes knotHash

				-- Find existing position
				-- for v = wireData.vertexStart + 1 to meshData.vertexCount while vertexIndex == 0 where MAXLancer.Hash (RoundPoint3 knotPosition hashDecimal) == MAXLancer.Hash (RoundPoint3 meshData.positions[v] hashDecimal) do vertexIndex = v

				if vertexIndex == 0 then (
					append meshData.positions knotPosition
					append vertexHashes knotHash
					vertexIndex = vertexHashes.count
					meshData.vertexCount += 1
				)

				if k == 1 then firstIndex = vertexIndex -- Remember first knot point index as origin for loop
				else if k > 1 and previousIndex > 0 and vertexIndex > 0 and previousIndex != vertexIndex then (
					-- append meshData.indices (previousIndex - 1)
					-- append meshData.indices (vertexIndex - 1)
					append edges [previousIndex - 1, vertexIndex - 1]
				)

				previousIndex = vertexIndex
			)

			if isClosed target s and firstIndex > 0 and previousIndex > 0 then append edges [previousIndex - 1, firstIndex - 1]

			if classOf progress == MAXScriptFunction then progress (numSegments target s)
		)

		local indexCount = wireData.AppendLines edges
		MAXLancer.WriteLog ("Added " + formattedPrint indexCount format:"u" + " wireframe indices to VWireData buffer")

		wireData -- Return VWireData
	),

	-- Parse shape object by mapping spline knots to mesh vertices to create lines in VWireData
	fn ParseMeshShape target meshRef origin progress: hashDecimal: = (
		if superClassOf target != shape then throw "Invalid shape object type"
		if classOf meshRef != VMeshRef then throw "Invalid VMeshRef object"

		if hashDecimal == unsupplied then hashDecimal = MAXLancer.hashDecimal

		local meshData = GetMesh meshRef.meshID
		if classOf meshData != VMeshData then throw ("Referenced mesh not found: " + formatID meshRef.meshID)

		local wireData = VWireData meshID:meshRef.meshID vertexStart:meshRef.vertexStart

		local firstIndex     -- Spline first knot vertex index
		local previousIndex  -- Previous knot vertex index
		local vertexIndex    -- Current knot vertex index
		local knotPosition   -- Current knot position vector
		local knotHash
		local vertexPosition -- Lookup vertex position vector
		local edges = #()    -- Array of Point2

		MAXLancer.WriteLog ("Parsing LOD mesh wireframe (" + meshData.filename + "): " + target.name)

		local vertexHashes = #()

		-- Process each shape spline
		in coordsys origin for s = 1 to numSplines target do (
			firstIndex = previousIndex = 0

			-- Process each knot
			for k = 1 to numKnots target s do (
				knotPosition = getKnotPoint target s k
				knotHash     = MAXLancer.Hash (RoundPoint3 knotPosition hashDecimal)
				vertexIndex  = findItem vertexHashes knotHash

				if vertexIndex == 0 then for v = 1 to meshRef.vertexCount while vertexIndex == 0 where distance meshData.positions[meshRef.vertexStart + v] knotPosition <= 0.025 do vertexIndex = v

				if vertexIndex > 0 then (
					vertexHashes[vertexIndex] = knotHash

					if k == 1 then firstIndex = vertexIndex -- Remember first knot point index as origin for loop
					else if k > 1 and previousIndex > 0 and vertexIndex > 0 and previousIndex != vertexIndex then append edges [previousIndex - 1, vertexIndex - 1]

					previousIndex = vertexIndex
				) else MAXLancer.WriteLog ("WARNING: No matching vertex for " + target.name + " in spline " + formattedPrint s format:"u" + " at knot " + formattedPrint k format:"u")
			)

			if isClosed target s and firstIndex > 0 and previousIndex > 0 then append edges [previousIndex - 1, firstIndex - 1]

			if classOf progress == MAXScriptFunction then progress (numSegments target s)
		)
		
		local indexCount = wireData.AppendLines edges
		MAXLancer.WriteLog ("Added " + formattedPrint indexCount format:"u" + " wireframe indices to VWireData buffer")

		wireData -- Return VWireData
	),

	/**
	 * Parse editable meshes into VMeshRefs (levels). Shape objects or visible
	 * edges in meshes are parsed into VWireData.
	 */
	fn ParseLevels target filename &levels &ranges &wireframe wireframes:true smoothingGroups:false materialLib: textureLib: progress: = (
		if classOf target != RigidPartHelper then throw "Invalid RigidPartHelper object"
			
		levels    = #()
		ranges    = #(0)
		wireframe = undefined

		local wireShape -- Line/Editable_mesh
		local levelMesh -- Editable_mesh
		local meshData  -- VMeshData
		local meshRef   -- VMeshRef

		local meshes = GetPartLevels target &wireShape

		-- Parse levels into buffer and 
		for i = 1 to meshes.count do (
			levelMesh = meshes[i]
			meshData  = CreateBuffer levelMesh filename
			meshRef   = meshData.Parse levelMesh smoothingGroups:smoothingGroups materialLib:materialLib textureLib:textureLib progress:progress

			ranges[i + 1] = levelMesh.range

			-- Set LOD wireframe
			if wireframes and wireframe == undefined and wireShape != undefined and wireShape.parent == levelMesh then wireframe = ParseMeshShape wireShape meshRef target.transform progress:progress

			levels[i] = meshRef
		)

		-- Freeform wireframe
		if wireframe == undefined and wireShape != undefined then wireframe = ParseFreeShape wireShape (CreateBuffer wireShape filename) target.transform progress:progress

		-- In absence of mesh but present wireframe create dummy VMeshRef with bounding box/sphere from wireframe positions instead
		if MAXLancer.writeDummyVMeshRef and levels.count == 0 and wireframe != undefined then (
			meshData = GetMesh wireframe.meshID
			meshRef  = VMeshRef minimum:[3.4e38, 3.4e38, 3.4e38] maximum:[-3.4e38, -3.4e38, -3.4e38]

			for i in makeUniqueArray wireframe.indices do meshRef.Extend meshData.positions[wireframe.vertexStart + i + 1]

			append levels meshRef
		)

		OK
	),

	fn ReadUTF reader filter: buffers:true = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object"

		local meshData -- VMeshData

		if reader.OpenFolder "VMeshLibrary" then (
			for id in (if filter == unsupplied then reader.GetFolders() else filter) where GetMesh id == undefined do (
				if not reader.OpenFolder id then throw ("Error reading " + formatID (MAXLancer.Hash id))

				meshData = VMeshData filename:(reader.ReadName reader.entry.nameOffset)

				MAXLancer.WriteLog ("Reading " + meshData.filename + " mesh buffer")

				meshData.ReadUTF reader buffers:buffers

				append meshes meshData
				reader.CloseFolder() -- Close meshData.filename
			)

			reader.CloseFolder() -- Close VMeshLibrary
		)

		OK
	),

	fn WriteUTF writer filter: = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object"

		local meshData -- VMeshData
		
		if writer.OpenFolder "VMeshLibrary" then (
			if filter == unsupplied then filter = for item in meshes collect item.filename

			for id in filter where (meshData = GetMesh id) != undefined do (
				if not writer.OpenFolder meshData.filename then throw ("Error writing " + meshData.filename)

				MAXLancer.WriteLog ("Writing " + meshData.filename + " mesh buffer")

				meshData.WriteUTF writer
				writer.CloseFolder() -- Close meshData.filename
			)

			writer.CloseFolder() -- Close VMeshLibrary
		)

		OK
	),

	-- Load mesh library from file (.vms)
	fn LoadFile filename filter: = (
		local reader = UTFReader()
		reader.Open filename
		ReadUTF reader filter:filter
		reader.Close()
		OK
	),

	-- Save mesh library into file (.vms)
	fn SaveFile filename filter: = (
		local writer = UTFWriter()
		writer.Open filename
		WriteUTF writer filter:filter
		writer.Close()
		OK
	)
)

fn ReadLevels reader &levels &ranges = (
	if classOf reader != UTFReader then throw "Invalid UTFReader object"

	levels = #() -- Array of VMeshRef
	ranges = undefined

	-- Read levels and ranges
	if reader.OpenFolder "MultiLevel" then (

		local level = 0
		while reader.OpenFolder ("Level" + formattedPrint level format:"u") do (
			if not reader.OpenFolder "VMeshPart" then throw ("Level " + formattedPrint level format:"u" + " is missing VMeshPart")
			
			(levels[level += 1] = VMeshRef()).ReadUTF reader
			reader.CloseFolder() -- Close VMeshPart
			reader.CloseFolder() -- Close Level*
		)

		-- Some user models may not have Switch2
		ranges = reader.ReadFileFloats "Switch2"

		reader.CloseFolder() -- Close MultiLevel
	) else if reader.OpenFolder "VMeshPart" then (
		(levels[1] = VMeshRef()).ReadUTF reader
		reader.CloseFolder() -- Close VMeshPart
	)

	OK
)

fn ReadWireframe reader &wireframe = (
	if classOf reader != UTFReader then throw "Invalid UTFReader object"

	wireframe = undefined

	if reader.OpenFolder "VMeshWire" then (
		(wireframe = VWireData()).ReadUTF reader
		reader.CloseFolder() -- Close VMeshWire
	)

	OK
)

fn WriteLevels writer levels ranges = (
	if classOf writer != UTFWriter then throw "Invalid UTFWriter object"

	if classOf levels == Array then (
		if levels.count > 1 then (
			if not writer.OpenFolder "MultiLevel" then throw "Error writing MultiLevel"
		
			if classOf ranges == Array then writer.WriteFileFloats "Switch2" ranges

			for i = 1 to levels.count do (
				if classOf levels[i] != VMeshRef then throw ("Invalid VMeshRef object at index " + formattedPrint i format:"u")

				if not writer.OpenFolder ("Level" + formattedPrint (i - 1) format:"u") then throw "Error writing level"
				if not writer.OpenFolder "VMeshPart" then throw "Error writing VMeshPart"

				levels[i].WriteUTF writer
				writer.CloseFolder() -- Close VMeshPart
				writer.CloseFolder() -- Close Level*
			)

			writer.CloseFolder() -- Close MultiLevel
		) else if levels.count == 1 then (
			if classOf levels[1] != VMeshRef then throw "Invalid VMeshRef object"
			if not writer.OpenFolder "VMeshPart" then throw "Error writing VMeshPart"
			
			levels[1].WriteUTF writer
			writer.CloseFolder() -- Close VMeshPart
		) else if MAXLancer.writeDummyVMeshRef then ( -- Write dummy VMeshRef for compatibility
			if not writer.OpenFolder "VMeshPart" then throw "Error writing VMeshPart"

			(VMeshRef()).WriteUTF writer
			writer.CloseFolder() -- Close VMeshPart
		)
	)

	OK
)

fn WriteWireframe writer wireframe = (
	if classOf writer != UTFWriter then throw "Invalid UTFWriter object"

	-- Write wireframe
	if classOf wireframe == VWireData and wireframe.indices.count > 0 then (
		if not writer.OpenFolder "VMeshWire" then throw "Error writing VMeshWire"

		wireframe.WriteUTF writer
		writer.CloseFolder() -- Close VMeshWire
	)

	OK
)
