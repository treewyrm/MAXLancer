/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Compound structure used by rigid models, individual parts and compound hierarchies.
 * File extensions: .3db and .cmp.
 */

plugin Helper RigidPartHelper classID:#(0x4C58414D, 0x74726170) name:"Rigid" category:"MAXLancer" extends:dummy replaceUI:true (
	local displayMesh = TriMesh()
	local lastSize

	parameters RigidPartParameters rollout:PartRollout (
		compound    type:#boolean    animatable:false ui:compoundCheckbox   default:false
		multilevel  type:#boolean    animatable:false ui:multilevelCheckbox default:false
		zerocenter  type:#boolean    animatable:false ui:zerocenterCheckbox default:false
		size        type:#worldUnits animatable:false ui:sizeSpinner        default:5.0
		inertia     type:#worldUnits animatable:false ui:inertiaSpinner     default:1.0
		damageModel type:#node       animatable:false
	)

	parameters CameraPartParameters rollout:CameraRollout (
		isCamera type:#boolean animatable:false ui:isCameraCheckbox default:false
		fovX     type:#float   animatable:false ui:fovXSpinner      default:45.0
		fovY     type:#float   animatable:false ui:fovYSpinner      default:45.0
		zNear    type:#float   animatable:false ui:zNearSpinner     default:0.001
		zFar     type:#float   animatable:false ui:zFarSpinner      default:1000.0
	)

	fn filterRigidPart target = classOf target == RigidPartHelper
	fn filterHardpoint target = classOf target == HardpointHelper

	rollout PartRollout "Part Parameters" (
		spinner sizeSpinner     "Dummy Size"      type:#float range:[0, 1000, 2]
		spinner inertiaSpinner  "Hitbox Inertia?" type:#float range:[0, 100, 1] tooltip:"Hitbox part section unknown vector scaler. Zero on moveable parts causes colliding objects transformation nullified."

		checkbox compoundCheckbox   "Force Compound"        tooltip:"Exporting this part will force output to be compound model (.cmp)."
		checkbox multilevelCheckbox "Force MultiLevel"      tooltip:"Force single LOD into MultiLevel with explicit LOD ranges. Does not affect parts with multiple LODs."
		checkbox zerocenterCheckbox "Force LOD Center Zero" tooltip:"Force LOD bounding sphere center to zero. Enable for parts in starspheres."
	)

	rollout CameraRollout "Camera Parameters" (
		checkbox isCameraCheckbox "Is Camera?" tooltip:"If enabled this part is used for camera placement. Used by ship cockpit models."

		spinner fovXSpinner  "Fov X"     type:#float range:[0, 180, 45]
		spinner fovYSpinner  "Fov Y"     type:#float range:[0, 180, 45]
		spinner zNearSpinner "Near Clip" type:#float range:[0, 3.4e38, 0]
		spinner zFarSpinner  "Far Clip"  type:#float range:[0, 3.4e38, 1000]
	)

	on getDisplayMesh do (
		if size != lastSize then (
			local vertices = #([size, 0, 0], [0, size, 0], [0, 0, size], [-size, 0, 0], [0, -size, 0], [0, 0, -size])
			local faces = #([3, 1, 2], [3, 2, 4], [3, 4, 5], [3, 5, 1], [6, 2, 1], [6, 4, 2], [6, 5, 4], [6, 1, 5])
			setMesh displayMesh vertices:vertices faces:faces
		)

		lastSize = size
		displayMesh
	)

	tool create (
		on mousePoint click do (
			nodeTM.translation = gridPoint
			#stop 
		)
	)
)

/**
 * Individual rigid part (.3db). One or more can form RigidCompound.
 * A part can contain VMeshRefs for different LODs, HUD wireframe and hardpoints to attach other things.
 */
struct RigidPart (
	filename   = "",  -- External name or fragment name if a part of compound model
	name       = "",  -- Object name (string, ex: "Li_elite_port_wing")
	index      = 0,   -- Part index in compound model
	ranges     = #(), -- Render mesh view ranges (Array of float)
	levels     = #(), -- Render mesh LODs (Array of VMeshRef)
	hardpoints = #(), -- Array of HardpointFixed/HardpointRevolute/HardpointPrismatic
	wireframe,        -- HUD wireframe (VWireData)
	camera,           -- Cockpit camera

	fn GetFilenameExtension = if classOf camera == CameraPart then ".cam" else ".3db",

	fn GetHashList hashes names = (
		if appendIfUnique hashes (MAXLancer.hash name) then append names name
		for hardpoint in hardpoints where appendIfUnique hashes (MAXLancer.hash hardpoint.name) do append names hardpoint.name
		OK
	),

	-- Get referenced resources IDs (meshes, materials and textures)
	fn GetResourceIDs meshIDs materialIDs textureIDs meshLib: materialLib: = (
		if classOf meshIDs != Array then throw "MeshIDs is not Array."
		if classOf materialIDs != Array then throw "MaterialIDs is not Array."
		if classOf textureIDs != Array then throw "TextureIDs is not Array."

		-- Wireframe doesn't have to have meshID of any VMeshRefs
		if classOf wireframe == VWireData and wireframe.meshID != 0 then appendIfUnique meshIDs wireframe.meshID

		-- Collect VMeshRefs meshID
		for level in levels where level.meshID != 0 do (
			appendIfUnique meshIDs level.meshID

			-- Lookup materialIDs used by VMeshRef in VMeshLibrary
			if classOf meshLib == VMeshLibrary then for materialID in meshLib.GetMaterialIDs level do (
				appendIfUnique materialIDs materialID

				-- Lookup textureIDs used by materials
				if classOf materialLib == FLMaterialLibrary and (material = materialLib.GetMaterial materialID) != undefined then
					for textureID in materialLib.GetTextureIDs material do appendIfUnique textureIDs textureID
			)
		)

		OK
	),

	-- Get combined boundaries for all levels
	fn GetBoundaries &minimum &maximum &center &radius = (
		minimum = maximum = center = radius = undefined

		for level in levels do (
			minimum = if minimum == undefined then copy level.minimum else [amin minimum.x level.minimum.x, amin minimum.y level.minimum.y, amin minimum.z level.minimum.z]
			maximum = if maximum == undefined then copy level.maximum else [amax maximum.x level.maximum.x, amax maximum.y level.maximum.y, amax maximum.z level.maximum.z]

			if center == undefined and radius == undefined then (
				center = copy level.center
				radius = level.radius
			) else MergeSpheres center radius level.center level.radius &center &radius
		)

		OK
	),

	-- Read RigidPart from UTF root in .3db or embedded .3db fragment in .cmp
	fn ReadUTF reader = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		MAXLancer.WriteLog ("Reading rigid part: " + name)

		if reader.OpenFolder "Camera" then (
			(camera = CameraPart()).ReadUTF reader
			reader.CloseFolder() -- Close Camera
		) else (
			ReadLevels     reader &levels &ranges
			ReadWireframe  reader &wireframe
			ReadHardpoints reader &hardpoints
		)

		OK
	),

	-- Write RigidPart into UTF root in .3db or embedded .3db fragment in .cmp
	fn WriteUTF writer = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		MAXLancer.WriteLog ("Writing rigid part: " + name)

		if classOf camera == CameraPart then (
			if not writer.OpenFolder "Camera" then throw "Error writing Camera"

			camera.WriteUTF writer
			writer.CloseFolder() -- Close Camera
		) else (
			WriteLevels     writer levels ranges
			WriteWireframe  writer wireframe
			WriteHardpoints writer hardpoints
		)		

		OK
	),

	-- Build RigidPartHelper from RigidPart
	fn Build hardpoints:true wireframes:true boundaries:false smoothingGroups:false meshLib: materialLib: textureLib: size:(MAXLancer.partSize) hardpointSize:(MAXLancer.hardpointSize) origin:(Matrix3 1) progress: = (
		local helperName = if name.count > 0 then name else filename

		MAXLancer.WriteLog ("Building rigid part: " + helperName)

		local result = RigidPartHelper name:helperName size:size transform:origin
		AddToLayer "Parts" result

		if classOf camera == CameraPart then (
			result.isCamera = true
			result.fovX     = camera.fovX
			result.fovY     = camera.fovY
			result.zNear    = camera.zNear
			result.zFar     = camera.zFar
		) else (
			if hardpoints then BuildHardpoints result this.hardpoints size:hardpointSize
			if classOf meshLib == VMeshLibrary then meshLib.BuildLevels result levels ranges wireframe wireframes:wireframes boundaries:boundaries smoothingGroups:smoothingGroups materialLib:materialLib textureLib:textureLib progress:progress
		)

		result -- Return RigidPartHelper
	),

	-- Parse RigidPart from RigidPartHelper
	fn Parse target hardpoints:true wireframes:true smoothingGroups:false meshLib: materialLib: textureLib: progress: = (
		if classOf target != RigidPartHelper then throw "Invalid RigidPartHelper object."

		MAXLancer.WriteLog ("Parsing rigid part: " + target.name)
		name = target.name

		/**
		 * Passing levels/ranges/wireframe directly seem to cause malfunction in
		 * MaxScript here (Bad structure member thunk member). There's something
		 * weird going on with passing struct parameters by reference into
		 * functions in struct instances. The workaround is to define them locally,
		 * pass into function and only then set into properties.
		 */

		if target.isCamera then camera = CameraPart fovX:target.fovX fovY:target.fovY zNear:target.zNear zFar:target.zFar else (
			local partLevels     -- Array of VMeshRef
			local partRanges     -- Array of Float
			local partWireframe  -- VWireData

			if hardpoints then ParseHardpoints target &this.hardpoints
			if classOf meshLib == VMeshLibrary then meshLib.ParseLevels target filename &partLevels &partRanges &partWireframe wireframes:wireframes smoothingGroups:smoothingGroups materialLib:materialLib textureLib:textureLib progress:progress
			
			levels    = partLevels
			ranges    = partRanges
			wireframe = partWireframe
		)

		OK
	),

	-- Load RigidPart from .3db file
	fn LoadFile target = (
		MAXLancer.WriteLog ("Loading rigid model: " + target)

		name = getFilenameFile target
		filename = filenameFromPath target
		
		local reader = UTFReader()
		reader.Open target
		ReadUTF reader
		reader.Close()

		OK
	),

	-- Save RigidPart into .3db file
	fn SaveFile target = (
		MAXLancer.WriteLog ("Saving rigid model: " + target)

		filename = filenameFromPath target

		local writer = UTFWriter()
		writer.Open target
		WriteUTF writer
		writer.Close()
		OK
	)
)

/**
 * Compound rigid model (.cmp).
 * At minimum contains single root part. Additional parts are attached via constraint joints.
 */
struct RigidCompound (
	filename,          -- Filename for loading and saving
	root,              -- Root RigidPart
	constraints = #(), -- Array of Constraint

	fn GetParts = GetCompoundParts root constraints,
	fn GetPart id = GetCompoundPartByID root constraints id,
	fn GetPartParent part = GetCompoundPartParent part constraints,
	fn GetPartChildren part = GetCompoundPartChildren part constraints,
	fn GetPartJoint part = GetCompoundPartJoint part constraints,
	fn GetHardpoint id = GetComoundHardpointByID root constraints id,

	-- Get hashes and names of parts and hardpoints in model
	fn GetHashList hashes names = for part in GetParts() do part.GetHashList hashes names,

	-- Get referenced resources IDs (meshes, materials and textures)
	fn GetResourceIDs meshIDs materialIDs textureIDs meshLib: materialLib: = for part in GetParts() do part.GetResourceIDs meshIDs materialIDs textureIDs meshLib:meshLib materialLib:materialLib,

	-- Get combined boundary from all parts VMeshRef in default state
	fn GetBoundaries &minimum &maximum &center &radius = (
		if classOf root != RigidPart then throw "Compound model is missing Root part."

		-- Reset all to undefined
		minimum = maximum = center = radius = undefined

		local iterator = CompoundIterator root:root constraints:constraints
		local vMin       -- Part space bounding box minimum (Point3)
		local vMax       -- Part space bounding box maximum (Point3)
		local vCenter    -- Part space bounding sphere center (Point3)
		local vRadius    -- Part space bounding sphere radius (float)
		local bMin       -- Root space bounding box minimum (Point3)
		local bMax       -- Root space bounding box maximum (Point3)
		local bBox = #() -- Bounding box vertices (Array of Point3)

		while iterator.Next() do (
			if iterator.current.child.levels.count == 0 then continue 

			-- Collect min/max in part space
			iterator.current.child.GetBoundaries &vMin &vMax &vCenter &vRadius

			-- Pick box vertices from minimum/maximum
			bBox = #(
				[vMin.x, vMin.y, vMin.z],
				[vMax.x, vMin.y, vMin.z],
				[vMax.x, vMax.y, vMin.z],
				[vMax.x, vMax.y, vMax.z],
				[vMin.x, vMax.y, vMax.z],
				[vMin.x, vMin.y, vMax.z],
				[vMin.x, vMax.y, vMin.z],
				[vMax.x, vMin.y, vMax.z]
			)

			-- Transform box vertices and get new bounding box
			bMin = [ 3.4e38,  3.4e38,  3.4e38]
			bMax = [-3.4e38, -3.4e38, -3.4e38]

			for i = 1 to 8 do (
				bBox[i] *= iterator.current.transform
				bMin.x = amin bMin.x bBox[i].x
				bMin.y = amin bMin.y bBox[i].y
				bMin.z = amin bMin.z bBox[i].z
				bMax.x = amax bMax.x bBox[i].x
				bMax.y = amax bMax.y bBox[i].y
				bMax.z = amax bMax.z bBox[i].z
			)
			
			-- Set or extend existing bounding
			minimum = if minimum == undefined then copy bMin else [amin minimum.x bMin.x, amin minimum.y bMin.y, amin minimum.z bMin.z]
			maximum = if maximum == undefined then copy bMax else [amax maximum.x bMax.x, amax maximum.y bMax.y, amax maximum.z bMax.z]

			-- Transform sphere center
			vCenter *= iterator.current.transform
			
			-- Set or extend existing sphere
			if center == undefined and radius == undefined then (
				center = copy vCenter
				radius = vRadius
			) else MergeSpheres center radius vCenter vRadius &center &radius

			-- Debug visuals
			-- Non-aligned: (Dummy name:(iterator.current.child.name + "_Box") pivot:(-0.5 * (vMin + vMax)) boxSize:(vMax - vMin)).transform = iterator.current.transform
			-- Aligned:     Dummy name:(iterator.current.child.name + "_BoxAA") pos:(0.5 * (bMin + bMax)) boxSize:(bMax - bMin)
			-- Sphere:      SphereGizmo name:(iterator.current.child.name + "_Sphere") pos:vCenter radius:vRadius
		)

		OK
	),

	-- Build RigidCompound model into scene
	fn Build hardpoints:true wireframes:true boundaries:false smoothingGroups:false meshLib: materialLib: textureLib: progress: origin:(Matrix3 1) size:(MAXLancer.partSize) hardpointSize:(MAXLancer.hardpointSize) = (
		if classOf root != RigidPart then throw "Compound model is missing Root part."

		MAXLancer.WriteLog ("Building compound model: " + filename)

		local iterator = CompoundIterator root:root constraints:constraints origin:origin
		local result -- Root helper
		local part

		while iterator.Next() do (
			if classOf iterator.current.child != RigidPart then continue

			MAXLancer.WriteLog ("Building part: " + iterator.current.child.name)

			iterator.parent = part = iterator.current.child.Build \
				hardpoints:hardpoints wireframes:wireframes boundaries:boundaries \
				smoothingGroups:smoothingGroups \
				meshLib:meshLib materialLib:materialLib textureLib:textureLib \
				size:size hardpointSize:hardpointSize origin:iterator.current.transform progress:progress 

			-- Part is root
			if iterator.current.child == root then (
				result = part
				result.compound = true
				result.transform.controller = LooseJointController()
			) else (
				part.parent = iterator.current.parent
				SetCompoundJoint iterator.parent iterator.current.joint
			)
		)

		result -- Return Root RigidPartHelper
	),

	fn Parse target hardpoints:true wireframes:true smoothingGroups:false meshLib: materialLib: textureLib: progress: = (
		if classOf target != RigidPartHelper then throw "Invalid RigidPartHelper object."

		MAXLancer.WriteLog ("Parsing compound model: " + target.name)

		constraints = #()

		local iterator = SceneIterator root:target
		local result -- PartConstraint

		while iterator.Next() do (
			if classOf iterator.current.child != RigidPartHelper then continue

			MAXLancer.WriteLog ("Parsing part: " + iterator.current.child.name)

			(iterator.parent = RigidPart filename:filename).Parse iterator.current.child \
				hardpoints:hardpoints wireframes:wireframes smoothingGroups:smoothingGroups \
				meshLib:meshLib materialLib:materialLib textureLib:textureLib \
				progress:progress

			-- Part is root
			if iterator.current.child == target then root = iterator.parent
			else (
				result = PartConstraint parent:iterator.current.parent child:iterator.parent joint:(GetCompoundJoint iterator.current.child root:(target == iterator.current.child))
				append constraints result
			)
		)

		OK
	),

	-- Load rigid compound model (Cmpnd)
	fn ReadUTF reader = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		MAXLancer.WriteLog ("Reading compound rigid model: " + reader.filename)
		filename = reader.filename

		reader.Reset()
		root = ReadCompound reader constraints RigidPart
		OK
	),

	-- Write rigid compound model (Cmpnd) and part fragments
	fn WriteUTF writer timestamps:false = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."
		if root == undefined then throw "Compound model is missing Root part."

		MAXLancer.WriteLog ("Writing compound rigid model: " + writer.filename)

		writer.Reset()
		WriteCompound writer root constraints timestamps:timestamps
		OK
	),

	-- Load RigidCompound from .cmp file
	fn LoadFile target = (
		MAXLancer.WriteLog ("Loading compound rigid model: " + target)

		local reader = UTFReader()
		reader.Open target
		ReadUTF reader
		reader.Close()
		OK
	),

	-- Save RigidCompound into .cmp file
	fn SaveFile target timestamps:false = (
		MAXLancer.WriteLog ("Saving compound rigid model: " + target)

		local writer = UTFWriter()
		writer.Open target
		WriteUTF writer timestamps:timestamps
		writer.Close()
		OK
	)
)
