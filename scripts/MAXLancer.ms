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
	local FixedJointController, AxisJointController, SphericJointController, LooseJointController, HardpointLinkController
	local PartConstraint, CameraPart, JointFixed, JointRevolute, JointPrismatic, JointCylindric, JointSpheric, JointLoose, CompoundIterator
	local RigidPartHelper, RigidPart, RigidCompound
	local DeformableAttributes, DeformablePartHelper, DeformablePart, DeformableCompound
	local SurfaceNodeHelper, SurfacePoint, SurfaceFace, SurfaceHull, SurfaceNode, SurfacePart, SurfaceLibrary
	local SimpleSurfaceLibrary
	local AnimationFrame, AnimationChannel, AnimationJointMap, AnimationObjectMap, AnimationScript, AnimationLibrary
	local ThornWriter

	local FLCRC
	local shaders
	local initialized = false
	local errorCount = 0

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
	include "SimpleSurface.ms"
	include "Animation.ms"
	include "Thorn.ms"

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

		on create do (
			listRollout = rollout LocateResourcesRollout "Missing Resources" width:224 height:316 (
				edittext filenameEdit "" pos:[8,8] width:208 height:18 labelOnTop:true readOnly:true
				label captionLabel "Missing Resources" pos:[8,34] width:208 height:16
				listbox resourcesList "" pos:[8,56] width:208 height:14 readOnly:true
						
				button locateButton "Locate" pos:[8,252] width:100 height:24
				button ignoreButton "Ignore" pos:[116,252] width:100 height:24
				button searchButton "Auto-search" pos:[8,284] width:100 height:24
				button cancelButton "Cancel" pos:[116,284] width:100 height:24
				
				on locateButton pressed do (
					local filenames = GetNetOpenFilenames caption:("Locate " + type) types:fileTypes multiple:true
				
					if filenames != undefined then (
						for filename in filenames do appendIfUnique search filename
						DestroyDialog LocateResourcesRollout
					)
				)

				on searchButton pressed do (
					local entries = case classOf library of (
						FLTextureLibrary:  MAXLancer.SearchTextures  missing displayProgress:false
						FLMaterialLibrary: MAXLancer.SearchMaterials missing displayProgress:false
						VMeshLibrary:      MAXLancer.SearchVMeshes   missing displayProgress:false
					)

					for entry in entries do for filename in entry do appendIfUnique search filename
					DestroyDialog LocateResourcesRollout
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
	)

	struct MAXLancerTools (
		version   = 0.97,
		debug     = true,
		config    = INIConfig filename:(pathConfig.appendPath (GetDir #plugcfg) ("MAXLancer.ini")),
		verbosity = 0,

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
		ListMaterials,
		FindHardpoint,

		GetRandomColorHSL,
		GetAtlasOffsets,
		GetSphereRandomPoint,
		GetSphereBalls,
		SpherifyVector,
		GenerateWireframe,

		VMeshAttributes,
		DeformableAttributes,
		FixedJointController,
		AxisJointController,
		SphericJointController,
		LooseJointController,
		HardpointLinkController,

		convexGenerator = 1,
		partSize        = 1.0,
		hardpointSize   = 1.0,
		exporterVersion = "",
		surfaceMaterial = Standardmaterial name:"Hull" selfIllumAmount:100 diffuse:(color 255 0 0) opacity:10,

		displayVertexLighting = true,
		displayVertexColors   = true,
		displayVertexAlpha    = true,

		animationSamplingRate      = 30,
		animationSamplingThreshold = 0.0,
		animationSamplingOverwrite = false, -- When non-linear controller is being sampled this flag will cause sampled controller to be written over previous one

		hashDecimal = 3,
		writeDummyVMeshRef = true, -- Write dummy VMeshRef on export if part has no LOD

		-- Default properties applied to renderMaterial when importing
		defaultRenderMaterial  = false,
		defaultRenderMetalness = 0.25,
		defaultRenderRoughness = 0.75,

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

		fn WriteError input = (
			errorCount += 1
			format "ERROR: %\r\n" input to:MAXLancerLog
			if MAXLancerLogRollout.inDialog then MAXLancerLogRollout.logBox.AppendText ("ERROR: " + input as string + "\r\n")
		),

		fn CreateRigidPartHelper name = RigidPartHelper name:name,
		fn IsRigidPartHelper target = isValidNode target and classOf target == RigidPartHelper,
		fn IsRootRigidPartHelper target = isValidNode target and classOf target == RigidPartHelper and classOf parent != RigidPartHelper,
		fn HasValidController target = isValidNode target and findItem #(FixedJointController, AxisJointController, SphericJointController, LooseJointController) (classOf target.transform.controller) > 0,

		fn CreateHardpointHelper name = HardpointHelper name:name,
		fn IsHardpointHelper target = isValidNode target and classOf target == HardpointHelper,

		fn CreateUTFReader = UTFReader(),
		fn CreateUTFWriter = UTFWriter(),

		fn CreateThornWriter = ThornWriter(),

		fn CreateRigidCompound = RigidCompound(),
		fn IsRigidCompound target = classOf target == RigidCompound,

		fn CreateRigidPart = RigidPart(),
		fn IsRigidPart target = classOf target == RigidPart,
		fn IsRigidLevel target = superClassOf target == GeometryClass and (custAttributes.get target VMeshAttributes) != undefined,

		fn CreateDeformableCompound = DeformableCompound(),
		fn IsDeformableCompound target = classOf target == DeformableCompound,

		fn CreateTextureLibrary = FLTextureLibrary(),
		fn CreateMaterialLibrary = FLMaterialLibrary(),
		fn CreateVMeshLibrary = VMeshLibrary(),
		fn CreateAnimationLibrary = AnimationLibrary(),
		fn CreateSurfaceLibrary = SurfaceLibrary(),
		fn CreateSimpleSurfaceLibrary = SimpleSurfaceLibrary(),

		GetTextureType = FLTextureLibrary.GetTextureType,
		GetPartSurfaces = SurfaceLibrary.GetPartSurfaces,
		GetPartLevels = VMeshLibrary.GetPartLevels,
		GetAnimations = AnimationLibrary.GetAnimations,

		fn GetJointType joint = (
			case classOf joint of (
				JointFixed:     "Fixed"
				JointRevolute:  "Revolute"
				JointPrismatic: "Prismatic"
				JointCylindric: "Cylindric"
				JointSpheric:   "Spheric"
				JointLoose:     "Loose"
				default:        "Unknown"
			)
		),

		fn GetShaders = shaders,

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

		-- Collect rigid model LOD meshes
		fn GetModelLevels root = (
			local result = #()
			local queue  = #(root)
			local target

			while queue.count > 0 do (
				target = queue[queue.count]
				queue.count = queue.count - 1

				for child in target.children do case of (
					(IsRigidLevel child): append result child
					(classOf child == classOf root): append queue child
				)
			)

			result -- Return array of Editable_mesh with VMeshAttributes
		),

		-- Get root rigid part helper and target hardpoint for damage model of rigid part
		fn GetPartDamageModel target &root &hardpoint = if IsRigidPartHelper target and target.damageModel != undefined and classOf target.damageModel.transform.controller == HardpointLinkController then (
			root = target.damageModel
			hardpoint = root.transform.controller.target
			OK
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

		-- Finds top 
		fn GetRootHelper target = (
			while target.parent != undefined and classOf target == RigidPartHelper and classOf target.parent != RigidPartHelper do target = target.parent

			target -- Return Node
		),

		-- Finds top node from hardpoint matching its parent class
		fn GetRootFromHardpoint target = (
			local child = if classOf target == HardpointHelper then target.parent

			-- Ascend to top 
			if child != undefined then
				while child.parent != undefined and classOf child.parent == classOf child do child = child.parent

			child -- Return Node
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

		mapped fn SetVMesh target = if isValidNode target then custAttributes.add target VMeshAttributes,
		mapped fn UnsetVMesh target = if isValidNode target then custAttributes.delete target VMeshAttributes,

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

		fn SearchResources names folderName location:freelancerPath masks:#("*") displayProgress:true = (
			local files = FilterFiles location recursive:true directoryMask:"*" fileMasks:masks
			local result = for n in names collect #()
			local hashes = for n in names collect Hash n
			local matches = #()
			local index = 0
			local reader = UTFReader()

			matches.count = names.count

			if displayProgress then progressStart "Seaching resources"

			WriteLog ("Auto-search (" + folderName + "): " + location)

			for filename in files do (
				if getFileSize filename > 0 then (
					try (
						reader.Open filename
						
						if reader.OpenFolder folderName then (
							for entryname in reader.GetFolders() where (index = findItem hashes (Hash entryname)) > 0 do (
								matches[index] = entryname
								append result[index] filename
							)
							
							reader.CloseFolder()
						)
					) catch (
						WriteError (getCurrentException())
					)

					reader.Close()
				)

				index += 1
				if displayProgress and not progressUpdate (100.0 * index / files.count) then break
			)

			if displayProgress then progressEnd()

			for index = 1 to names.count where result[index].count > 0 and classOf matches[index] == String do (
				WriteLog ((formattedPrint index format:"02u") + ": " + matches[index])

				for filename in result[index] do WriteLog("  " + substring filename (location.count + 2) -1)
			)

			result
		),

		-- Search for materials
		fn SearchMaterials materials location:freelancerPath masks:#("*.mat") displayProgress:true = SearchResources materials "Material library" location:location masks:masks displayProgress:displayProgress,

		-- Search for textures
		fn SearchTextures textures location:freelancerPath masks:#("*.mat", "*.txm") displayProgress:true = SearchResources textures "Texture library" location:location masks:masks displayProgress:displayProgress,

		-- Search for mesh buffers
		fn SearchVMeshes meshes location:freelancerPath masks:#("*.mat", "*.txm") displayProgress:true = SearchResources meshes "VMeshLibrary" location:location masks:masks displayProgress:displayProgress,

		fn Initialize = (
			errorCount = 0
			MAXLancerLog = StringStream ""

			WriteLog "Initializing MAXLancer."
			WriteLog ("Config path:        " + config.filename)

			local crcFilename = pathConfig.normalizePath (pathConfig.appendPath (GetFilenamePath (getThisScriptFilename())) "FLCRC32.bin")

			if doesFileExist crcFilename then WriteLog ("FLCRC32 path:       " + crcFilename)
			else WriteError ("Missing hash table file: " + crcFilename)

			-- Initialize FLCRC32 hash table
			FLCRC = FLCRC32()
			FLCRC.LoadFile crcFilename

			if FLCRC.hashes.count != 0x100 then WriteError ("Invalid hash list: " + crcFilename)

			exporterVersion    = config.LoadProperty "MAXLancer" "exporterVersion"    default:("MAXLancer Tools " + version as string)
			temporaryPath      = config.LoadProperty "MAXLancer" "temporaryPath"      default:(pathConfig.appendPath (GetDir #temp) "MAXLancer")
			texturesPath       = config.LoadProperty "MAXLancer" "texturesPath"       default:(pathConfig.appendPath (GetDir #image) "MAXLancer")
			textureToolsPath   = config.LoadProperty "MAXLancer" "textureToolsPath"   default:(pathConfig.appendPath (GetFilenamePath (getThisScriptFilename())) "tools")
			shadersPath        = config.LoadProperty "MAXLancer" "shadersPath"        default:(pathConfig.appendPath (GetDir #maxroot) "maps\\fx\\MAXLancer")
			freelancerPath     = config.LoadProperty "MAXLancer" "freelancerPath"     default:(GetFreelancerPath())
			convexGenerator    = config.LoadProperty "MAXLancer" "convexGenerator"    default:1    type:#number
			partSize           = config.LoadProperty "MAXLancer" "partSize"           default:0.25 type:#number
			hardpointSize      = config.LoadProperty "MAXLancer" "hardpointSize"      default:0.25 type:#number
			hashDecimal        = config.LoadProperty "MAXLancer" "hashDecimal"        default:3    type:#integer
			writeDummyVMeshRef = config.LoadProperty "MAXLancer" "writeDummyVMeshRef" default:true type:#boolean

			animationSamplingRate      = config.LoadProperty "MAXLancer" "animationSamplingRate"      default:30    type:#number
			animationSamplingThreshold = config.LoadProperty "MAXLancer" "animationSamplingThreshold" default:0.0   type:#number
			animationSamplingOverwrite = config.LoadProperty "MAXLancer" "animationSamplingOverwrite" default:false type:#boolean

			defaultRenderMaterial  = config.LoadProperty "Render" "defaultRenderMaterial"  default:false type:#boolean
			defaultRenderMetalness = config.LoadProperty "Render" "defaultRenderMetalness" default:0.25  type:#number
			defaultRenderRoughness = config.LoadProperty "Render" "defaultRenderRoughness" default:0.75  type:#number

			if not doesFileExist temporaryPath then makeDir temporaryPath all:true

			WriteLog ("Temporary path:     " + temporaryPath)

			if doesFileExist freelancerPath and getFileAttribute freelancerPath #directory then WriteLog ("Freelancer path:    " + freelancerPath)
			else WriteError ("Missing freelancer path: " + freelancerPath)

			if not doesFileExist texturesPath then makeDir texturesPath all:true

			if doesFileExist texturesPath and getFileAttribute texturesPath #directory then WriteLog ("Textures path:      " + texturesPath)
			else WriteError ("Missing textures path: " + texturesPath)

			if doesFileExist textureToolsPath and getFileAttribute textureToolsPath #directory then WriteLog ("Texture tools path: " + textureToolsPath)
			else WriteError ("Missing texture tools path: " + textureToolsPath)

			if doesFileExist shadersPath and getFileAttribute shadersPath #directory then (
				WriteLog ("Shaders path:       " + shadersPath)

				local shadersFilename = pathConfig.appendPath shadersPath "shaders.xml"

				if classOf shaders == ShaderLibrary and shaders.filename == shadersFilename then (
					WriteLog ("Shaders already loaded")
				) else if doesFileExist shadersFilename then (
					shaders = ShaderLibrary()
					shaders.LoadFile shadersFilename
				) else WriteError ("Missing shader config: " + shadersFilename)
			) else WriteError ("Missing shaders path: " + shadersPath)

			
			if errorCount > 0 then (
				messageBox ("One or more errors were detected at the startup. Details are provided in MAXLancer log.") title:"Errors detected"
				ShowLog()
				initialized = false
			) else (
				WriteLog "MAXLancer initialized."
				initialized = true
			)
		),

		on create do (

			-- Incrase heap size to ~256MB to avoid slow automatic growth
			if heapSize < 268435456 then heapSize = 268435456

			WriteLog ("Heap: " + formattedPrint heapFree format:"u" + " of " + formattedPrint heapSize format:"u")
			Initialize()
		)
	)

	-- Return new tools instance
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
		ListMaterials:              ListMaterials              \
		GetCompoundJoint:           GetCompoundJoint           \
		GetRandomColorHSL:          GetRandomColorHSL          \
		GetAtlasOffsets:            GetAtlasOffsets            \
		GetSphereRandomPoint:       GetSphereRandomPoint       \
		GetSphereBalls:             GetSphereBalls             \
		SpherifyVector:             SpherifyVector             \
		GenerateWireframe:          GenerateWireframe          \
		FindHardpoint:              FindHardpoint              \
		VMeshAttributes:            VMeshAttributes            \
		FixedJointController:       FixedJointController       \
		AxisJointController:        AxisJointController        \
		SphericJointController:     SphericJointController     \
		LooseJointController:       LooseJointController       \
		HardpointLinkController:    HardpointLinkController    \
		DeformableAttributes:       DeformableAttributes
)
