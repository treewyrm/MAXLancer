/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 */

global MAXLancer = (
	local MAXLancerLog = StringStream ""

	-- Declare struct names
	local UTFHeader, UTFEntry, UTFReader, UTFWriter
	local ShaderLibrary
	local FLTexture, FLTextureLibrary
	local FLMaterialType, FLMaterialLibrary
	local FLMaterialAnimation, FLMaterialAnimationLibrary
	local VMeshAttributes, VMeshRef, VMeshPart, VMultiLevel, VWireData, VMeshWire, VMeshGroup, VMeshData, VMeshLibrary
	local HardpointHelper, HardpointFixed, HardpointRevolute, HardpointPrismatic
	local FixedJointController, AxisJointController, SphericJointController, LooseJointController
	local PartConstraint, JointFixed, JointRevolute, JointPrismatic, JointCylindric, JointSpheric, JointLoose, CompoundIterator
	local RigidPartHelper, RigidPart, RigidCompound
	local DeformableAttributes, DeformablePartHelper, DeformablePart, DeformableCompound
	local SurfaceNodeHelper, SurfacePoint, SurfaceFace, SurfaceHull, SurfaceNode, SurfacePart, SurfaceLibrary
	local AnimationFrame, AnimationChannel, AnimationJointMap, AnimationObjectMap, AnimationScript, AnimationLibrary

	include "Common.ms"
	include "INI.ms"
	include "FLCRC32.ms"
	include "Config.ms"
	include "UTF.ms"
	include "Texture.ms"
	include "Material.ms"
	include "Shader.ms"
	include "VMesh.ms"
	include "Hardpoint.ms"
	include "Transform.ms"
	include "Compound.ms"
	include "Rigid.ms"
	include "Deformable.ms"
	include "ConvexHull.ms"
	include "Surface.ms"
	include "Animation.ms"

	rollout MAXLancerLogRollout "MAXLancer Log" width:512 height:384 (
		local logFont = dotNetObject "System.Drawing.Font" "Consolas" 9

		dotNetControl logBox "System.Windows.Forms.Textbox" pos:[0,0] width:512 height:344 align:#left
		button saveButton "Save" pos:[8,352] width:88 height:24 align:#left
		button clearButton "Clear" pos:[104,352] width:88 height:24 align:#left
		button closeButton "Close" pos:[416,352] width:88 height:24 align:#left

		fn resize size = (
			logBox.width  = size.x
			logBox.height = size.y - 40
			closeButton.pos.y = clearButton.pos.y = saveButton.pos.y = logBox.height + 8
			closeButton.pos.x = size.x - 96
		)

		on clearButton pressed do (MAXLancerLog = StringStream ""; logBox.Clear())

		on saveButton pressed do (
			local filename = getSaveFileName title:"Save Log File" types:"Plain Text (*.txt)|*.txt|", stream

			if filename != undefined then (
				stream = fopen filename "wt"
				WriteString stream (MAXLancerLog as string)
				fclose stream
			)
		)

		on closeButton pressed do DestroyDialog MAXLancerLogRollout

		on MAXLancerLogRollout resized size do resize size

		on MAXLancerLogRollout open do (
			logBox.Font        = logFont
			logBox.ReadOnly    = true
			logBox.MultiLine   = true
			logBox.WordWrap    = false
			logBox.ScrollBars  = logBox.ScrollBars.Both
			logBox.BorderStyle = logBox.BorderStyle.None

			logBox.BackColor   = GetNetColorMan #window
			logBox.ForeColor   = GetNetColorMan #windowText
			logBox.Text        = MAXLancerLog as string

			resize (GetDialogSize MAXLancerLogRollout)
		)
	)

	struct ResourceFinder (
		filename  = "",                    -- File which requests resources
		type      = "resources",           -- Type of resource
		fileTypes = "All Files (*.*)|*.*", -- File types

		missing   = #(), -- Missing IDs
		search    = #(), -- Filenames to search through
		library,         -- Target library
		listRollout,     -- Dialog rollout

		allMaterials = false,
		
		fn Find = (
			do (
				for filename in search do library.LoadFile filename filter:missing allMaterials:allMaterials

				-- Remove names from missing entries that are no longer missing
				for i = missing.count to 1 by -1 where library.GetItem missing[i] != undefined do deleteItem missing i
				
				-- Ask user for more files to search through
				if missing.count > 0 then CreateDialog listRollout modal:true
			) while search.count > 0 and missing.count > 0
			
			missing.count == 0 -- Returns true if all missing entries were found
		),
		
		on create do listRollout = rollout LocateResourcesRollout "Missing Resources" width:224 height:284 (
			editText filenameEdit "" pos:[8, 8] width:208 height:18 labelOnTop:true readOnly:true
			label captionLabel "Missing Resources" pos:[8, 34] width:208 height:16
			listbox resourcesList "" pos:[8, 56] width:208 height:14 readOnly:true
			
			button locateButton "Locate" pos:[8, 252] width:64 height:24
			button ignoreButton "Ignore" pos:[80, 252] width:64 height:24
			button cancelButton "Cancel" pos:[152, 252] width:64 height:24
			
			on locateButton pressed do (
				local filenames = GetNetOpenFilenames caption:("Locate " + type) types:fileTypes multiple:true
			
				if filenames != undefined then (
					for filename in filenames do appendIfUnique search filename
					DestroyDialog LocateResourcesRollout
				)
			)

			on ignoreButton pressed do (
				for i = missing.count to 1 by -1 where library.GeneratePlaceholder missing[i] != undefined do deleteItem missing i
				DestroyDialog LocateResourcesRollout
			)

			on cancelButton pressed do (
				search.count = 0
				DestroyDialog LocateResourcesRollout
			)
			
			on LocateResourcesRollout open do (
				filenameEdit.text = filename
				captionLabel.text = "Missing " + formattedPrint missing.count format:"u" + " " + type

				ignoreButton.enabled = hasProperty library #GeneratePlaceholder and classOf library.GeneratePlaceholder == MAXScriptFunction
				
				local items = #()
				for i = 1 to items.count = missing.count do items[i] = case classOf missing[i] of (
					Integer: formattedPrint missing[i] format:"08X"
					String:  missing[i]
					default: missing[i] as string
				)
				
				resourcesList.items = items
			)

			-- Causes to stop on adding files
			-- on LocateResourcesRollout close do search.count = 0
		)
	)

	struct MAXLancerTools (
		version = 0.5,
		debug   = true,
		config  = INIConfig filename:(pathConfig.appendPath (GetDir #plugcfg) ("MAXLancer.ini")),
		shaders,      -- ShaderLibrary

		FLCRC,

		CreateGUID,
		FilterFiles,
		OpenINIFile,
		CreateINIFile,
		GetNetOpenFilenames,
		GetNetColorMan,
		GetPartParents,
		GetPartChildren,
		GetPartHardpoints,
		GetMeshElements,
		GetMeshMaterials,
		GetCompoundJoint,
		FindHardpoint,

		UTFEntry,
		UTFHeader,
		UTFReader,
		UTFWriter,
		VMeshLibrary,
		VMeshAttributes,
		FLMaterialMap,
		FLMaterialLibrary,
		FLMaterialAnimationLibrary,
		FLTexture,
		FLTextureLibrary,
		SurfaceLibrary,
		SurfaceNodeHelper,
		AnimationLibrary,
		HardpointHelper,
		HardpointFixed,
		HardpointRevolute,
		HardpointPrismatic,
		FixedJointController,
		AxisJointController,
		SphericJointController,
		LooseJointController,
		JointFixed,
		JointRevolute,
		JointPrismatic,
		JointCylindric,
		JointSpheric,
		JointLoose,
		CompoundIterator,
		RigidPartHelper,
		RigidPart,
		RigidCompound,
		DeformableAttributes,
		DeformablePart,
		DeformableCompound,

		convexGenerator,
		partSize,
		hardpointSize,
		exporterVersion,
		surfaceMaterial = Standardmaterial name:"Hull" selfIllumAmount:100 diffuse:(color 255 0 0) opacity:10,

		displayVertexLighting = true,
		displayVertexColors   = true,
		displayVertexAlpha    = true,

		freelancerPath,   -- Path to Freelancer installation
		texturesPath,     -- Path to textures
		shadersPath,      -- Path to HLSL shaders
		temporaryPath,    -- Path to temporary location
		textureToolsPath, -- Path to Nvidia Texture Tools

		-- Write log line
		fn WriteLog input = (
			format "%\r\n" input to:MAXLancerLog
			if MAXLancerLogRollout.inDialog then MAXLancerLogRollout.logBox.AppendText (input as string + "\r\n")
		),

		fn ShowLog = CreateDialog MAXLancerLogRollout style:#(#style_titlebar, #style_border, #style_sysmenu, #style_resizing),

		-- Hash any valid input
		fn Hash input crc:-1 caseSensitive:false force:false = FLCRC.Hash input crc:crc caseSensitive:caseSensitive force:force,

		-- Request to locate resources for library 
		fn FindResources filename missing library &search type fileTypes allMaterials:false = (ResourceFinder filename:filename missing:missing library:library search:search type:type fileTypes:fileTypes allMaterials:allMaterials).Find(),

		fn IsTransformScaled target approximation:10 = if isValidNode target then (
			local scaler = target.transform.scalepart -- Get scale from transform
			close_enough scaler.x 1.0 approximation and close_enough scaler.y 1.0 approximation and close_enough scaler.z 1.0 approximation -- Return boolean
		),

		-- Test if target node transform is rigid
		fn HasNodeOffsets target = if isValidNode target then (
			target.objectOffsetPos == [0, 0, 0] and isIdentity target.objectOffsetRot and target.objectOffsetScale == [1, 1, 1] and close_enough scaler.x 1.0 10 and close_enough scaler.y 1.0 10 and close_enough scaler.z 1.0 10
		),

		-- Get filename for temporary storage
		fn GetTemporaryFilename = (
			local result = pathConfig.appendPath temporaryPath (CreateShortID())
			if not doesFileExist temporaryPath then makeDir temporaryPath
			result
		),

		-- Create and return folder for temporary files
		fn CreateTemporaryFolder prefix:"" = (
			if not doesFileExist temporaryPath then throw "Temporary path does not exist."

			local result
			do result = pathConfig.appendPath temporaryPath (createShortID prefix:prefix) while doesFileExist result

			if not makeDir result then throw ("Unable to create temporary folder at: " + result)
			result -- Return String (temporary directory path)
		),		
		
		-- Get Freelancer path from registry
		fn GetFreelancerPath = (
			local path32 = "SOFTWARE\\Microsoft\\Microsoft Games\\Freelancer\\1.0"
			local path64 = "SOFTWARE\\WOW6432Node\\Microsoft\\Microsoft Games\\Freelancer\\1.0"
			local key
			local type
			local result 

			if (registry.openKey HKEY_LOCAL_MACHINE path32 key:&key or registry.openKey HKEY_LOCAL_MACHINE path64 key:&key) then
				registry.queryValue key "AppPath" type:&type value:&result
			
			result
		),

		-- Automatically uses selected object if it matches filter function
		fn PickSceneObject filter message: prompt: = (
			if classOf filter != MAXScriptFunction then throw "Invalid filter callback function."
				
			-- If only one object is selected we'll try to use it
			if selection.count == 1 and filter selection[1] then selection[1] else pickObject message:message prompt:prompt count:1 filter:filter select:true
		),

		-- Generate hull for array of point3
		fn GenerateHull vertices maxVertices: delIsoVerts:false = (
			case convexGenerator of (
				1: GenerateConvexHullNVPX vertices maxVertices:maxVertices delIsoVerts:delIsoVerts
				2: GenerateConvexHullQH vertices maxVertices:maxVertices delIsoVerts:delIsoVerts
			)
		),

		-- Collect names of parts and hardpoints into hashmap
		fn GetModelHashes root names hashes parts:true hardpoints:true = (
			local queue = #(root)
			local target

			while queue.count > 0 do (
				target = queue[queue.count]
				queue.count = queue.count - 1

				-- Collect part hashes
				if parts and appendIfUnique hashes (Hash target.name) then append names target.name

				-- Collect hardpoint hashes and add subparts to queue
				for child in target.children do case of (
					(hardpoints and classOf child == HardpointHelper): if appendIfUnique hashes (Hash child.name) then append names child.name
					(classOf child == classOf root): append queue child
				)
			)

			OK
		),

		-- Finds top node from hardpoint matching its parent class
		fn GetRootFromHardpoint target = (
			local child = if classOf target == HardpointHelper then target.parent

			-- Ascend to top 
			if child != undefined then
				while child.parent != undefined and classOf child.parent == classOf child do child = child.parent

			child -- Return HardpointHelper
		),

		

		-- Attaches or aligns source model to target hardpoint by source hardpoint
		fn AttachHardpoints sourceHardpoint targetHardpoint attach:true = (
			local sourceRoot = GetRootFromHardpoint sourceHardpoint
			local targetRoot = GetRootFromHardpoint targetHardpoint

			if isValidNode sourceRoot and isValidNode targetRoot and sourceRoot != targetRoot then (
				sourceRoot.transform = inverse (sourceHardpoint.transform * inverse sourceRoot.transform) * targetHardpoint.transform

				if attach then sourceRoot.parent = targetHardpoint -- Attach to hardpoint group root
			)

			invalidateTreeTM sourceRoot
			OK
		),

		mapped fn SetHardpointSize hardpoint baseSize arrowSize = if classOf hardpoint == HardpointHelper then (
			hardpoint.baseSize  = baseSize
			hardpoint.arrowSize = arrowSize
		),

		mapped fn SetRigidPartSize part size = if classOf part == RigidPartHelper then part.size = float size,

		mapped fn SetVMesh target = if superClassOf target == GeometryClass then custAttributes.add target VMeshAttributes,
		mapped fn UnsetVMesh target = if superClassOf target == GeometryClass then custAttributes.delete target VMeshAttributes,

		-- Load rigid model from file
		fn LoadRigidModel filename meshLib: materialLib: textureLib: = (
			if not doesFileExist filename then throw ("Rigid model file does not exist: " + filename)

			WriteLog ("Loading rigid model: " + filename)

			local reader = UTFReader()
			reader.Open filename
			
			local result = if reader.OpenFolder "Cmpnd" then RigidCompound() else RigidPart()
			result.ReadUTF reader
			reader.Close()

			local resolved    = true
			local search      = #(filename)
			local meshIDs     = #() -- Array of Integer
			local materialIDs = #() -- Array of Integer
			local textureIDs  = #() -- Array of Integer

			-- fn FindResources filename missing library &search type fileTypes

			if classOf meshLib == VMeshLibrary then (
				result.GetResourceIDs meshIDs materialIDs textureIDs -- Meshes
				resolved = MAXLancer.FindResources filename meshIDs meshLib &search "meshes" "Mesh Library (.vms)|*.vms|All Files (*.*)|*.*" 

				if resolved and classOf materialLib == FLMaterialLibrary then (
					result.GetResourceIDs meshIDs materialIDs textureIDs meshLib:meshLib -- Materials
					resolved = MAXLancer.FindResources filename materialIDs materialLib &search "materials" "Material Library (.mat)|*.mat|All Files (*.*)|*.*"

					if resolved and classOf textureLib == FLTextureLibrary then (
						result.GetResourceIDs meshIDs materialIDs textureIDs meshLib:meshLib materialLib:materialLib -- Textures
						resolved = MAXLancer.FindResources filename textureIDs textureLib &search "textures" "Texture Library (.txm)|*.txm|All Files (*.*)|*.*"
					)
				)
			)

			result -- Return RigidPart or RigidCompound
		),

		-- Load deformable from file
		fn LoadDeformableModel filename materialLib: textureLib: = (
			if not doesFileExist filename then throw ("Deformable model file does not exist: " + filename)

			WriteLog ("Loading deformable model: " + filename)

			local reader = UTFReader()
			reader.Open filename

			local result = DeformableCompound()
			result.ReadUTF reader
			reader.Close()

			local resolved    = true
			local search      = #(filename)
			local materialIDs = #() -- Array of Integer
			local textureIDs  = #() -- Array of Integer

			if classOf materialLib == FLMaterialLibrary then (
				result.GetResourceIDs materialIDs textureIDs -- Materials
				resolved = MAXLancer.FindResources filename materialIDs materialLib &search "materials" "Material Library (.mat)|*.mat|All Files (*.*)|*.*"
				
				if resolved and classOf textureLib == FLTextureLibrary then (
					result.GetResourceIDs materialIDs textureIDs materialLib:materialLib -- Textures
					resolved = MAXLancer.FindResources filename textureIDs textureLib &search "textures" "Texture Library (.txm)|*.txm|All Files (*.*)|*.*"
				)
			)

			result -- Return DeformableCompound
		),

		on create do (
			if heapSize < 268435456 then heapSize = 268435456
			WriteLog ("Heap: " + formattedPrint heapFree format:"u" + " of " + formattedPrint heapSize format:"u")

			WriteLog ("Config path: " + config.filename)

			exporterVersion  = config.LoadProperty "MAXLancer" "exporterVersion" default:"MAXLancer Tools"
			temporaryPath    = config.LoadProperty "MAXLancer" "temporaryPath" default:(pathConfig.appendPath (GetDir #temp) "MAXLancer")
			texturesPath     = config.LoadProperty "MAXLancer" "texturesPath" default:(pathConfig.appendPath (GetDir #image) "MAXLancer")
			textureToolsPath = config.LoadProperty "MAXLancer" "textureToolsPath" default:("C:\\NVTT\\")
			shadersPath      = config.LoadProperty "MAXLancer" "shadersPath" default:(pathConfig.appendPath (GetDir #renderassets) "MAXLancer")
			freelancerPath   = config.LoadProperty "MAXLancer" "freelancerPath" default:(GetFreelancerPath())

			if not doesFileExist textureToolsPath then messageBox "MAXLancer Texture Tools path is invalid. Please set correct path in Settings."
			if not doesFileExist shadersPath then messageBox "MAXLancer Shaders path is invalid. Please set correct path in Settings."
			
			WriteLog ("Temporary path: " + temporaryPath)
			WriteLog ("Textures path: " + texturesPath)
			WriteLog ("Texture tools path: " + textureToolsPath)
			WriteLog ("Shaders path: " + shadersPath)
			WriteLog ("Freelancer path: " + freelancerPath)

			convexGenerator = config.LoadProperty "MAXLancer" "convexGenerator" default:1    type:#number
			partSize        = config.LoadProperty "MAXLancer" "partSize"        default:0.25 type:#number
			hardpointSize   = config.LoadProperty "MAXLancer" "hardpointSize"   default:0.25 type:#number

			shaders = ShaderLibrary()
			shaders.LoadFile (pathConfig.appendPath shadersPath "shaders.xml")

			FLCRC = FLCRC32()
			FLCRC.LoadFile (pathConfig.normalizePath (pathConfig.appendPath (GetFilenamePath (getThisScriptFilename())) "FLCRC32.bin"))

			WriteLog "MAXLancer initialized."
		)
	)

	MAXLancerTools \
		CreateGUID:                 CreateGUID                 \
		FilterFiles:                FilterFiles                \
		OpenINIFile:                OpenINIFile                \
		CreateINIFile:              CreateINIFile              \
		GetNetOpenFilenames:        GetNetOpenFilenames        \
		GetNetColorMan:             GetNetColorMan             \
		GetPartParents:             GetPartParents             \
		GetPartChildren:            GetPartChildren            \
		GetPartHardpoints:          GetPartHardpoints          \
		GetMeshElements:            GetMeshElements            \
		GetMeshMaterials:           GetMeshMaterials           \
		GetCompoundJoint:           GetCompoundJoint           \
		FindHardpoint:              FindHardpoint              \
		UTFEntry:                   UTFEntry                   \
		UTFHeader:                  UTFHeader                  \
		UTFReader:                  UTFReader                  \
		UTFWriter:                  UTFWriter                  \
		VMeshLibrary:               VMeshLibrary               \
		VMeshAttributes:            VMeshAttributes            \
		FLMaterialMap:              FLMaterialMap              \
		FLMaterialLibrary:          FLMaterialLibrary          \
		FLMaterialAnimationLibrary: FLMaterialAnimationLibrary \
		FLTexture:                  FLTexture                  \
		FLTextureLibrary:           FLTextureLibrary           \
		SurfaceLibrary:             SurfaceLibrary             \
		AnimationLibrary:           AnimationLibrary           \
		SurfaceNodeHelper:          SurfaceNodeHelper          \
		HardpointHelper:            HardpointHelper            \
		HardpointFixed:             HardpointFixed             \
		HardpointRevolute:          HardpointRevolute          \
		HardpointPrismatic:         HardpointPrismatic         \
		FixedJointController:       FixedJointController       \
		AxisJointController:        AxisJointController        \
		SphericJointController:     SphericJointController     \
		LooseJointController:       LooseJointController       \
		JointFixed:                 JointFixed                 \
		JointRevolute:              JointRevolute              \
		JointPrismatic:             JointPrismatic             \
		JointCylindric:             JointCylindric             \
		JointSpheric:               JointSpheric               \
		JointLoose:                 JointLoose                 \
		CompoundIterator:           CompoundIterator           \
		RigidPartHelper:            RigidPartHelper            \
		RigidPart:                  RigidPart                  \
		RigidCompound:              RigidCompound              \
		DeformableAttributes:       DeformableAttributes       \
		DeformablePart:             DeformablePart             \
		DeformableCompound:         DeformableCompound
)
