/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Compound structure and mesh format used by deformable models (character body, head, arms, etc).
 * File extension: .dfm.
 */

DeformableAttributes = attributes "Deformable Mesh" attribID:#(0x4C58414D, 0x6873656E) (
	parameters DeformableParameters rollout:DeformableMeshRollout (
		mode     type:#integer animatable:false ui:modeList        default:1
		fraction type:#float   animatable:false ui:fractionSpinner
	)

	rollout DeformableMeshRollout "Deformable Mesh Parameters" (
		dropdownlist modeList "Primitive Type:" items:#("Triangle List", "Triangle Strip")
		spinner fractionSpinner "Fraction:" type:#float range:[0, 1, 0]
	)
)

struct DeformablePart (
	filename   = "",
	index      = 0, -- Bone ID
	name       = "",
	boneToRoot = Matrix3 1, -- Binding pose bone transformation
	LODbits    = 0,
	hardpoints = #(), -- Array of HardpointFixed/HardpointRevolute/HardpointPrismatic

	fn ReadUTF reader = (
		MAXLancer.WriteLog ("Reading deformable part: " + name)
		LODbits = reader.ReadFileInteger "Lod Bits" #unsigned

		if not reader.OpenFile "Bone to root" then throw "Deformable part is missing boneToRoot."
		ReadBoneToRoot reader.data boneToRoot

		local hardpoints
		ReadHardpoints reader &hardpoints

		this.hardpoints = hardpoints
	),

	fn WriteUTF writer = (
		MAXLancer.WriteLog ("Writing deformable part: " + name)
		writer.WriteFile "Lod Bits" LODbits #integer

		if not writer.OpenFile "Bone to root" then throw "Unable to create boneToRoot."
		WriteBoneToRoot writer.data boneToRoot
		writer.CloseFile()

		WriteHardpoints writer hardpoints
	),

	fn Build size:0.025 = (
		local result = Point name:name size:size transform:boneToRoot showLinks:true
		
		BuildHardpoints result hardpoints size:size
		result -- Return DeformablePartHelper
	)
)

struct DeformableFaceGroup (
	material = "",   -- Material_name
	indices  = #(),  -- Tristrip_indices or Face_indices
	tristrip = true, -- Interpret indices as tristrips instead of face indices

	fn GetFaceCount = if tristrip then indices.count - 2 else indices.count / 3,

	-- Convert triangle strip indices to triangle list indices
	fn StripToList = for i = 1 to indices.count - 2 collect if mod i 2 == 0 then [indices[i + 2], indices[i + 1], indices[i]] + 1 else [indices[i], indices[i + 1], indices[i + 2]] + 1,

	fn IndicesToList = for i = 1 to indices.count by 3 collect [indices[i], indices[i + 1], indices[i + 2]] + 1,

	fn GetFaces = if tristrip then StripToList() else IndicesToList(),

	fn ReadUTF reader = (
		material = reader.ReadFileString "Material_name"
		indices  = reader.ReadFileShorts "Tristrip_indices" #unsigned
		
		if indices == undefined then (
			indices = reader.ReadFileShorts "Face_indices" #unsigned
			tristrip = true
		)

		OK
	),

	fn WriteUTF writer = (
		writer.WriteFileString "Material_name"
		writer.WriteFileShorts (if tristrip then "Tristrip_indices" else "Face_indices") indices #unsigned

		OK
	)
)

struct DeformableMesh (
	groups          = #(), -- Array of DeformableFaceGroup
	points          = #(), -- Array of Point3
	pointIndices    = #(), -- Array of Integer
	UV0             = #(), -- Array of Point2
	UV0Indices      = #(), -- Array of Integer
	UV1             = #(), -- Array of Point2
	UV1Indices      = #(), -- Array of Integer
	pointBoneFirst  = #(), -- Array of Integer
	pointBoneCount  = #(), -- Array of Integer (1 - 4)
	boneIndexChain  = #(), -- Array of Integer
	boneWeightChain = #(), -- Array of Integer (0 - 255)
	vertexNormals   = #(), -- Array of Point3
	deltaUMin       = 0,
	deltaUMax       = 1,
	deltaVMin       = 0,
	deltaVMax       = 1,
	boneXUScale     = 1,
	boneYVScale     = 1,
	UVVertexCount   = 0,
	UVBoneID        = #(),
	UVVertexID      = #(),
	UVDefaults      = #(),
	UVPlaneDistance = 0,

	fn GetFaceCount = (
		local result = 0
		for i = 1 to groups.count do result += groups[i].GetFaceCount()
		result -- Return integer
	),

	fn ReadUVs reader target uvs = if reader.OpenFile target then for i = 1 to reader.size / 8 do ReadPoint2 reader.data (uvs[i] = [0, 0]),
	fn ReadPositions reader target positions = if reader.OpenFile target then for i = 1 to reader.size / 12 do ReadPosition reader.data (positions[i] = [0, 0, 0]),

	fn ReadUTF reader = (
		-- Read face groups
		if not reader.OpenFolder "Face_groups" then throw "Deformable model mesh is missing Face_groups."

		local groupCount = reader.ReadFileInteger "Count" #unsigned
		if classOf groupCount != Integer then throw "Deformable model mesh face groups is missing Count."

		local faceGroup

		for i = 1 to groupCount do (
			if not reader.OpenFolder ("Group" + formattedPrint (i - 1) format:"u") then throw "Deformable model mesh face groups is missing Group."

			faceGroup = DeformableFaceGroup()
			faceGroup.ReadUTF reader

			append groups faceGroup

			reader.CloseFolder() -- Close Group*
		)

		reader.CloseFolder() -- Close Face_groups

		-- Read geometry
		if not reader.OpenFolder "Geometry" then throw "Deformable model is missing Geometry."

		-- Vertices and positions
		pointIndices  = reader.ReadFileLongs "Point_indices" #unsigned

		ReadPositions reader "Points" points
		ReadPositions reader "Vertex_normals" vertexNormals

		-- Texture maps
		UV0Indices = reader.ReadFileLongs "UV0_indices" #unsigned
		if classOf UV0Indices == Array then ReadUVs reader "UV0" UV0

		UV1Indices = reader.ReadFileLongs "UV1_indices" #unsigned
		if classOf UV1Indices == Array then ReadUVs reader "UV1" UV1

		-- Bones and weights
		pointBoneFirst  = reader.ReadFileLongs "Point_bone_first" #unsigned
		pointBoneCount  = reader.ReadFileLongs "Point_bone_count" #unsigned
		boneIndexChain  = reader.ReadFileLongs "Bone_id_chain" #unsigned
		boneWeightChain = reader.ReadFileFloats "Bone_weight_chain"

		-- Texture UV manipulation
		deltaUMin = reader.ReadFileFloat "min_du"
		deltaUMax = reader.ReadFileFloat "max_du"
		deltaVMin = reader.ReadFileFloat "min_dv"
		deltaVMax = reader.ReadFileFloat "max_dv"

		-- Bone X/Y to texture U/V mapping scale
		boneXUScale = reader.ReadFileFloat "bone_x_to_u_scale"
		boneYVScale = reader.ReadFileFloat "bone_y_to_v_scale"

		UVVertexCount   = reader.ReadFileInteger "uv_vertex_count" #unsigned
		UVBoneID        = reader.ReadFileLongs "uv_bone_id" #unsigned
		UVVertexID      = reader.ReadFileLongs "uv_vertex_id" #unsigned
		UVDefaults      = reader.ReadFileFloats "uv_default_list"
		UVPlaneDistance = reader.ReadFileFloat "uv_plane_distance"

		reader.CloseFolder() -- Close Geometry
		OK
	),

	fn WriteUVs writer target uvs = if writer.OpenFile target then for i = 1 to uvs.count do WritePoint2 reader.data uvs[i],
	fn WritePositions writer target positions = if writer.OpenFile target then for i = 1 to positions.count do WritePosition reader.data positions[i],

	fn WriteUTF writer = (
		if groups.count < 1 then throw "Mesh has no face groups."

		if not writer.OpenFolder "Face_groups" then throw "Unable to create face group folder."

		writer.WriteFileInteger "Count" groups.count #unsigned

		for i = 1 to groups.count do (
			if not writer.OpenFolder ("Group" + formattedPrint (i - 1) format:"u") then throw "Unable to create material group folder."
			groups[i].WriteUTF writer
			writer.CloseFolder() -- Close Group*
		)

		writer.CloseFolder() -- Close Face_groups

		if not writer.OpenFolder "Geometry" then throw "Unable to create geometry folder."

		-- Vertices and positions
		writer.WriteFileLongs "Point_indices" pointIndices #unsigned

		WritePositions writer "Points" points
		WritePositions writer "Vertex_normals" vertexNormals

		-- Texture maps
		if UV0Indices.count > 0 and UV0.count > 0 then (
			writer.WriteFileLongs "UV0_indices" UV0Indices #unsigned
			WriteUVs writer "UV0" UV0
		)

		if UV1Indices.count > 0 and UV1.count > 0 then (
			writer.WriteFileLongs "UV1_indices" UV1Indices #unsigned
			WriteUVs writer "UV1" UV1
		)

		-- Bones and weights 
		writer.WriteFileLongs "Point_bone_first" pointBoneFirst #unsigned
		writer.WriteFileLongs "Point_bone_count" pointBoneCount #unsigned
		writer.WriteFileLongs "Bone_id_chain" boneIndexChain #unsigned
		writer.WriteFileFloats "Bone_weight_chain" boneWeightChain

		-- Texture UV manipulation
		if classOf deltaUMin == Float then writer.WriteFileFloat "min_du" deltaUMin
		if classOf deltaUMax == Float then writer.WriteFileFloat "max_du" deltaUMax
		if classOf deltaVMin == Float then writer.WriteFileFloat "min_dv" deltaVMin
		if classOf deltaVMax == Float then writer.WriteFileFloat "max_dv" deltaVMax

		-- Bone X/Y to texture U/V mapping scale
		if classOf boneXUScale == Float then writer.WriteFileFloat "bone_x_to_u_scale" boneXUScale
		if classOf boneYVScale == Float then writer.WriteFileFloat "bone_y_to_v_scale" boneYVScale

		writer.CloseFolder() -- Close Geometry
		OK
	),

	-- Build mesh
	fn Build materialLib: textureLib: = (
		local materials = #() -- Array of string
		local ranges    = #() -- Array of Point2
		local faces     = #() -- Array of Point3
		local facesUV0  = #() -- Array of Point3
		local facesUV1  = #() -- Array of Point3

		local groupFaces -- Array of Point3

		-- Assemble vertices, faces and attributes
		for g = 1 to groups.count do (
			groupFaces = groups[g].GetFaces()

			append materials groups[g].material
			append ranges ([1, groupFaces.count] + faces.count)

			for face in groupFaces do (
				append faces ([pointIndices[face.x], pointIndices[face.y], pointIndices[face.z]] + 1)

				if classOf UV0Indices == Array and UV0Indices.count > 0 then append facesUV0 ([UV0Indices[face.x], UV0Indices[face.y], UV0Indices[face.z]] + 1)
				if classOf UV1Indices == Array and UV1Indices.count > 0 then append facesUV1 ([UV1Indices[face.x], UV1Indices[face.y], UV1Indices[face.z]] + 1)
			)
		)

		-- Build mesh
		local result = mesh vertices:points faces:faces material:(MultiMaterial numsubs:materials.count)

		-- Remove automatic smoothing groups
		for f = 1 to getNumFaces result do setFaceSmoothGroup result f 0

 		-- Apply vertex normal
		for v = 1 to getNumVerts result do setNormal result v vertexNormals[v]

		-- Apply UV0 texture map
		if classOf facesUV0 == Array and facesUV0.count > 0 do (
			meshOp.setMapSupport result 1 true
			meshOp.setNumMapVerts result 1 UV0.count

			for v = 1 to UV0.count do meshOp.setMapVert result 1 v [UV0[v].x, UV0[v].y, 0]
			for f = 1 to getNumFaces result do meshOp.setMapFace result 1 f facesUV0[f]

			meshOp.buildMapFaces result 1
		)

		-- Apply UV1 texture map
		if classOf facesUV1 == Array and facesUV1.count > 0 do (
			meshOp.setNumMaps result 3
			meshOp.setMapSupport result 2 true
			meshOp.setNumMapVerts result 2 UV1.count

			for v = 1 to UV1.count do meshOp.setMapVert result 2 v [UV1[v].x, UV1[v].y, 0]
			for f = 1 to getNumFaces result do meshOp.setMapFace result 2 f facesUV1[f]

			meshOp.buildMapFaces result 2
		)

		-- Apply materials
		for m = 1 to materials.count do (
			result.material.names[m] = materials[m]

			if classOf materialLib == FLMaterialLibrary then result.material.materialList[m] = materialLib.Build materials[m] textureLib:textureLib

			-- Apply sub-material ID to faces
			for f = ranges[m].x to ranges[m].y do setFaceMatID result f m
		)

		custAttributes.add result DeformableAttributes
		meshOp.removeDegenerateFaces result -- Clean up mesh
		result -- Return Editable_mesh
	),

	fn ApplySkin target parts binds = (
		if classOf target != Editable_mesh then throw "Invalid target mesh."
		if classOf parts != Array then throw "Invalid bones array type."
		if classOf binds != Array then throw "Invalid binding transformations array type."
		if parts.count != binds.count then throw "Mismatching number of bones and binding transforms."

		local skinMod = Skin()
		local part

		max modify mode
		select target
		addModifier target skinMod ui:on

		for i = 1 to parts.count do (
			if not isValidNode (part = parts[i]) then throw ("Missing bone index " + formattedPrint i format:"u")
				
			MAXLancer.WriteLog ("Adding bone " + formattedPrint (i - 1) format:"u" + ": " + part.name)

			skinOps.AddBone skinMod part 0
		)
		
		for v = 1 to getNumVerts target do (
			local boneIDs = (for b = 1 to pointBoneCount[v] collect boneIndexChain[pointBoneFirst[v] + b] + 1)
			local boneWeights = (for b = 1 to pointBoneCount[v] collect boneWeightChain[pointBoneFirst[v] + b])

			-- format "%: % -> %\n" v boneIDs boneWeights
		)

		for v = 1 to getNumVerts target do skinOps.ReplaceVertexWeights skinMod v (for b = 1 to pointBoneCount[v] collect boneIndexChain[pointBoneFirst[v] + b] + 1) (for b = 1 to pointBoneCount[v] collect boneWeightChain[pointBoneFirst[v] + b])
		for i = 1 to binds.count do skinUtils.SetBoneBindTM target parts[i] binds[i]


		OK
	),

	-- Parse mesh
	fn Parse target materialLib: textureLib: = (
		-- Points and Vertex_normals have same size!

		local materials  = #() -- Array of submaterials
		local faces      = #() -- Array of face BitArrays for each submaterial
		
		-- Collect faces into bitArrayed grouped by submaterials
		GetMeshMaterials target materials faces
		for item in materials do materialLib.AddMaterial (materialLib.Parse item textureLib:textureLib)	

		local normalsMod = Edit_Normals() -- Edit_Normals modifier to read explicit vertex normals
		addModifier target normalsMod
		select target
		max modify mode

		local hasUV0 = meshOp.getMapSupport target 1
		local hasUV1 = meshOp.getMapSupport target 2

		-- Collect vertices
		points = for v = 1 to getNumVerts target collect getVert target v

		-- Collect texture maps
		UV0 = if hasUV0 then for i = 1 to meshOp.getNumMapVerts target 1 collect meshOp.getMapVert target 1 i
		UV1 = if hasUV1 then for i = 1 to meshOp.getNumMapVerts target 2 collect meshOp.getMapVert target 2 i

		local faceGroup  -- DeformableFaceGroup
		local face       -- Face indices (point3)
		local position   -- Vertex position (point3)
		local pointIndex -- Vertex index

		local startIndex = 1
		local hashes     = #()
		local hash

		for m = 1 to materials.count do (
			faceGroup = DeformableFaceGroup material:materials[m].name tristrip:false

			for f in faces do (
				face    = getFace target f
				faceUV0 = if hasUV0 then meshOp.getMapFace target 1 f
				faceUV1 = if hasUV1 then meshOp.getMapFace target 2 f

				-- Face verteices/edges
				for i = 1 to 3 do (
					position   = meshOp.getVert target face[i]
					normal     = normalsMod.GetNormal (normalsMod.GetNormalID f i)
					hash       = MAXLancer.Hash

					pointIndex = 0

					for p = startIndex to points.count while pointIndex == 0 where hashes[p] ==  points[p] == position and vertexNormals[p] == normal do pointIndex = p

					append pointIndices (pointIndex - 1)
					append vertexNormals ()

					if hasUV0 then append UV0Indices ((meshOp.getMapVert target 1 faceUV0[i]) - 1)
					if hasUV1 then append UV1Indices ((meshOp.getMapVert target 2 faceUV1[i]) - 1)

					append faceGroup.indices (pointIndices.count - 1)
				)
			)

			startIndex = amax faceGroup.indices + 1
			append groups faceGroup
		)

		OK
	)
)

struct DeformableCompound (
	filename,          -- Filename
	root,              -- Root part (DeformablePart)
	scaler      = 1.0, -- Model scale
	constraints = #(), -- Array of Constraint
	fractions   = #(), -- Array of Float
	meshes      = #(), -- Array of DeformableMesh

	fn GetFaceCount = (
		local result = 0
		for i = 1 to meshes.count do result += meshes[i].GetFaceCount()
		result -- Return integer
	),

	fn GetLastBoneIndex = (
		local result = 0
		for i = 1 to meshes.count do result = amax (amax meshes[i].boneIndexChain) result
		result -- Return integer
	),

	fn GetParts = GetCompoundParts root constraints,
	fn GetPart id = GetCompoundPartByID root constraints id,
	fn GetPartParent part = GetCompoundPartParent part constraints,
	fn GetPartChildren part = GetCompoundPartChildren part constraints,
	fn GetPartJoint part = GetCompoundPartJoint part constraints,
	fn GetHardpoint id = GetComoundHardpointByID root constraints id,

	fn GetResourceIDs materialIDs textureIDs materialLib: = (
		local id
		local mat

		for m in meshes do for g in m.groups do (
			if appendIfUnique materialIDs (id = MAXLancer.Hash g.material) and classOf materialLib == FLMaterialLibrary and (mat = materialLib.GetMaterial id) != undefined then (
				for t in materialLib.GetTextureIDs mat do appendIfUnique textureIDs t
			)
		)

		OK
	),

	fn ParseSkeleton skinMod = (
		MAXLancer.WriteLog "Parsing skeleton"

		local boneCount = skinOps.GetNumberBones skinMod
		local boneNames = #()
		local boneNodes = #()
		local boneName
		local item

		for i = 1 to boneCount do (
			boneName = skinOps.GetBoneName skinMod i 0
			if not appendIfUnique boneNames (toLower boneNames) then throw ("Duplicate bone name: " + boneName)

			item = getNodeByName boneName
			if not isValidNode boneName then throw ("Missing node for bone: " + boneName)

			boneNodes[i] = item
		)

		OK
	),

	fn Parse targets flags materialLib: progress: = (

		local skinMod
		local boneCount

		-- Parse skin from first target, other LODs must simply have same number of bones assigned to them.

		for i = 1 to targets.count do (
			MAXLancer.WriteLog ("Parsing deformable mesh " + formattedPrint (i - 1) format:"u")

			if (skinMod = GetModifierType targets[i] skin) == undefined then throw (targets[i].name + " has no skin modifier.")
			boneCount = skinOps.GetNumberBones skinMod
		)

		OK
	),

	fn BuildMeshes parts binds materialLib: textureLib: progress: maxLevel: = (
		if maxLevel == unsupplied then maxLevel = meshes.count

		local target -- Editable_mesh

		for i = 1 to maxLevel do (
			if meshes[i] == undefined then throw ("Missing mesh fraction " + formattedPrint (i - 1) format:"u")

			-- Generating mesh
			target = meshes[i].Build materialLib:materialLib textureLib:textureLib
			(GetLayer ("Fraction" + formattedPrint (i - 1) format:"u") hidden:(i > 1)).AddNode target

			-- Applying skin bones and pose binds
			meshes[i].ApplySkin target parts binds
			
			if classOf progress == MAXScriptFunction then progress (meshes[i].GetFaceCount())
		)

		OK
	),

	fn BuildSkeleton parts binds size:0.0125 = (
		if classOf parts != Array then throw "Invalid bones array type."
		if classOf binds != Array then throw "Invalid binding transformations array type."

		local layer  = GetLayer "Parts"
		local queue  = for constraint in constraints where constraint.parent == root collect constraint
		local result = root.Build size:size
		local constraint -- JointConstraint
		local target     -- Bone Helper

		local rootIndex   = root.index + 1
		local parentIndex = 0
		local childIndex  = 0

		parts.count = binds.count = 0

		parts[rootIndex] = result
		binds[rootIndex] = Matrix3 1

		result.transform.controller = LooseJointController()
		layer.AddNode result

		while queue.count > 0 do (
			constraint = queue[queue.count]
			queue.count = queue.count - 1

			parentIndex = constraint.parent.index + 1
			childIndex  = constraint.child.index + 1

			if parts[parentIndex] == undefined then throw ("Invalid parent bone index in " + constraint.child.name)
			if parts[childIndex] != undefined then throw ("Duplicate bone index in " + constraint.child.name)

			MAXLancer.WriteLog ("Building bone: " + constraint.parent.name + " to " + constraint.child.name + " (" + formattedPrint constraint.child.index format:"u" + ")")

			parts[childIndex] = target = constraint.child.Build size:size
			binds[childIndex] = constraint.child.boneToRoot

			target.parent = parts[parentIndex]

			layer.AddNode target
			SetCompoundJoint target constraint.joint

			for subconstraint in constraints where subconstraint.parent == constraint.child do append queue subconstraint
		)

		result -- Return deformable root
	),

	fn Build materialLib: textureLib: progress: = (
		local parts = #()
		local binds = #()

		local result = BuildSkeleton parts binds

		-- Generate placeholders 
		for i = 1 to GetLastBoneIndex() + 1 where parts[i] == undefined do (
			parts[i] = Dummy name:("Bone_" + formattedPrint i format:"02u") boxSize:[0.05, 0.05, 0.05]
			binds[i] = Matrix3 1
		)

		BuildMeshes parts binds materialLib:materialLib textureLib:textureLib progress:progress

		result -- Return deformable root
	),

	fn GetHardpointBoneTM id = (
		id = MAXLancer.Hash id
		
		local result
		
		for part in GetCompoundParts root constraints while result == undefined do
			for hardpoint in part.hardpoints while result == undefined where MAXLancer.Hash hardpoint.name == id do
				result = hardpoint.transform * part.boneToRoot

		result -- Return Matrix3
	),

	-- Build deformable model as attached via hardpoints
	fn BuildChild parent child attachmentName connectorName: materialLib: textureLib: progress: = (
		local parts  = #()
		local binds  = #()
		local result = child.BuildSkeleton parts binds

		local source = FindHardpoint result attachmentName
		if source == undefined then throw ("Child model is missing source hardpoint " + attachmentName)

		local target = FindHardpoint parent attachmentName
		if target == undefined then throw ("Parent model is missing target hardpoint " + attachmentName)

		-- Attach child skeleton to target hardpoint relative to source hardpoint
		result.transform = inverse source.transform * target.transform
		result.parent    = target

		-- Undefined bone index found in heads and hands can be reverse attached to connector hardpoint
		if connectorName != unsupplied then (

			local hardpoint = FindHardpoint parent connectorName
			if hardpoint == undefined then throw ("Parent model is missing bind hardpoint " + connectorName)

			-- Get transformation of connector hardpoint relative to part if part is linked by attachment hardpoints
			local bindTM = GetHardpointBoneTM connectorName * inverse (inverse (child.GetHardpointBoneTM attachmentName) * GetHardpointBoneTM attachmentName)

			-- Find undefined bone index and inject connector hardpoint with bind transform
			for i = 1 to child.GetLastBoneIndex() + 1 where parts[i] == undefined do (parts[i] = hardpoint; binds[i] = bindTM)
		)

		-- Generate deformable meshes 
		child.BuildMeshes parts binds materialLib:materialLib textureLib:textureLib progress:progress

		result -- Return child root bone
	),

	fn BuildCostume head leftHand rightHand materialLib: textureLib: progress: = (
		local parts  = #()
		local binds  = #()
		local result = BuildSkeleton parts binds

		BuildMeshes parts binds materialLib:materialLib textureLib:textureLib progress:progress
		
		if classOf head == DeformableCompound then      BuildChild result head "hp_head" connectorName:"hp_neck" materialLib:materialLib textureLib:textureLib progress:progress
		if classOf leftHand == DeformableCompound then  BuildChild result leftHand "hp_left b" connectorName:"hp_left a" materialLib:materialLib textureLib:textureLib progress:progress
		if classOf rightHand == DeformableCompound then BuildChild result rightHand "hp_right b" connectorName:"hp_right a" materialLib:materialLib textureLib:textureLib progress:progress

		result -- Return costume body root bone
	),

	fn ReadMultiLevelUTF reader = (
		if not reader.OpenFolder "MultiLevel" then throw "Deformable model is missing MultiLevel."
		MAXLancer.WriteLog "Reading MultiLevel"

		fractions = reader.ReadFileFloats "Fractions"
		fractions = #(0) -- TODO: REMOVE THIS AFTER FIXING ANIMATIONS

		local item

		for i = 1 to fractions.count do (
			if not reader.OpenFolder ("Mesh" + formattedPrint (i - 1) format:"u") then throw "Deformable model is missing Mesh."

			(item = DeformableMesh()).ReadUTF reader
			append meshes item

			reader.CloseFolder() -- Close Mesh*
		)
		
		reader.CloseFolder() -- Close MultiLevel
	),

	fn ReadUTF reader = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		MAXLancer.WriteLog ("Reading deformable model: " + reader.filename)
		filename = reader.filename

		ReadMultiLevelUTF reader
		root = ReadCompound reader constraints DeformablePart scaler:&scaler
		OK
	),

	fn WriteMultiLevelUTF writer = (
		if not writer.OpenFolder "MultiLevel" then throw "Unable to open MultiLevel folder."
		MAXLancer.WriteLog "Writing MultiLevel"

		-- fractions.count
		for i = 1 to fractions.count do (
			if not writer.OpenFolder ("Mesh" + formattedPrint (i - 1) format:"u") then throw "Unable to open Mesh folder."

			if classOf meshes[i] != DeformableMesh then throw ("Fraction " + (formattedPrint (i - 1) format:"u") + " is missing deformable mesh.")
			meshes[i].WriteUTF writer

			writer.CloseFolder() -- Close Mesh*
		)
	
		writer.CloseFolder() -- Close MultiLevel
		OK
	),

	fn WriteUTF writer = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		MAXLancer.WriteLog ("Writing deformable model: " + writer.filename)
		filename = writer.filename

		WriteMultiLevelUTF writer
		WriteCompound writer root constraints

		OK
	),

	-- Load from .dfm file
	fn LoadFile target = (
		MAXLancer.WriteLog ("Loading deformable model: " + target)

		local reader = UTFReader()
		reader.Open target
		ReadUTF reader
		reader.Close()
		OK
	),

	-- Save into .dfm file
	fn SaveFile target = (
		MAXLancer.WriteLog ("Saving deformable model: " + target)

		local writer = UTFWriter()
		writer.Open target
		WriteUTF writer
		writer.Close()
		OK
	)
)
