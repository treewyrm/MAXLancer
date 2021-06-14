/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Import Freelancer models into 3Ds MAX.
 */
macroscript ImportRigid category:"MAXLancer" tooltip:"Import Rigid" buttontext:"Import Rigid" iconName:"MAXLancer/import_rigid" (
	global MAXLancer

	local filename -- Filename of import subject
	local maxHullList = 60
	local hardpointHullColor = (dotNetClass "System.Drawing.Color").LightSteelBlue
	
	-- Import .3db/.cmp
	rollout ImportRigidRollout "Import Rigid Model" width:440 height:352 (

		local model        -- RigidPart/RigidCompound
		local meshLib      -- VMeshLibrary
		local materialLib  -- FLMaterialLibrary
		local textureLib   -- FLTextureLibrary
		local animationLib -- AnimationLibrary
		local surfaceLib   -- SurfaceLibrary

		local compound       = false
		local indexCount     = 0 -- Number of indices in all mesh references
		local triangleCount  = 0 -- Number of triangles in all hulls
		local partCount      = 0 -- Number of parts
		local meshCount      = 0 -- Number of mesh references
		local wireCount      = 0 -- Number of HUD wireframes
		local hardpointCount = 0 -- Number of hardpoints
		local hullCount      = 0 -- Number of surface hulls
		local hullPartCount  = 0 -- Number of surface parts
		local animationCount = 0 -- Number of animation scripts
		local progressCount  = 0 -- Progress counter is based on number of mesh indices and hull triangles processed

		local hashes = #() -- Array of hashes (integer)
		local names  = #() -- Array of names (string)

		dotNetControl treeBox "System.Windows.Forms.TreeView" pos:[8, 8] width:272 height:320

		GroupBox modelGroup "Model Components:" pos:[288, 8] width:144 height:124
		checkbox hardpointsCheckbox "Hardpoints" pos:[296, 28] width:128 height:16 enabled:false tooltip:"Attachment points for equipment and other use."
		checkbox meshesCheckbox "Meshes" pos:[296, 48] width:64 height:16 enabled:false tooltip:"LOD display meshes."

		checkbox boundariesCheckbox "Bounds" pos:[360, 48] width:64 height:16 enabled:false tooltip:"LOD meshes boundary sphere and box."
		checkbox wireframesCheckbox "Wireframes" pos:[296, 68] width:128 height:16 tooltip:"HUD wireframes (as Spline objects)."
		checkbox materialsCheckbox "Materials and Textures" pos:[296, 88] width:128 height:16 enabled:false tooltip:"Materials and textures."
		checkbox animationsCheckbox "Compound Animations" pos:[296, 108] width:128 height:16 enabled:false tooltip:"Multipart animation (enable in animation layers)."
	
		GroupBox surfaceGroup "Surface Components:" pos:[288, 144] width:144 height:144
		checkbox hullsCheckbox "Collision Hulls" pos:[296, 164] width:128 height:16 enabled:false tooltip:"Collision detection meshes."
		checkbox dupesCheckbox "Keep Duplicates" pos:[296, 184] width:128 height:16 enabled:false tooltip:"Retain duplicates of meshes in ascendent fixed parts."
		checkbox wrapsCheckbox "Group Hulls" pos:[296, 204] width:128 height:16 enabled:false tooltip:"Group meshes for optimization."
		checkbox centersCheckbox "Centers of Mass" pos:[296, 224] width:128 height:16 enabled:false tooltip:"Part center of mass, used for aiming reticle."
		checkbox extentsCheckbox "Boundary Extents" pos:[296, 244] width:128 height:16 enabled:false tooltip:"Part boundary box extents."
		checkbox nodesCheckbox "Hierarchy Volumes" pos:[296, 264] width:128 height:16 enabled:false tooltip:"Boundary box."

		button importButton "Import Model" pos:[288, 304] width:144 height:24
		progressBar buildProgress "" pos:[8, 336] width:424 height:8

		fn ProgressCallback count = (
			buildProgress.value = (progressCount += count) * 100.0 / (indexCount + triangleCount)
			windows.processPostedMessages()
		)

		on importButton pressed do try (
			importButton.enabled = false
			
			gc light:false

			local meshIDs     = #() -- Array of integer (meshIDs used by VMeshRef and VWireData)
			local materialIDs = #() -- Array of integer (materialIDs used by VMeshData/VMeshGroup)
			local textureIDs  = #() -- Array of integer (textureIDs used by *t_name in materials)
			local resolved    = true
			local search      = #(filename)

			local result -- RigidPartHelper
			local start  -- timestamp
			local flags  -- Integer

			-- Locate meshes, materials and textures
			if meshesCheckbox.checked or wireframesCheckbox.checked then (

				model.GetResourceIDs meshIDs materialIDs textureIDs -- Getting meshes
				resolved = MAXLancer.FindResources filename meshIDs meshLib &search "meshes" "Mesh Library (.vms)|*.vms|All Files (*.*)|*.*"

				if materialsCheckbox.checked and resolved then (

					model.GetResourceIDs meshIDs materialIDs textureIDs meshLib:meshLib -- Getting materials

					materialLib.ReadScene filter:materialIDs textureLib:textureLib -- Read materials from scene

					resolved = MAXLancer.FindResources filename materialIDs materialLib &search "materials" "Material Library (.mat)|*.mat|All Files (*.*)|*.*"
					
					if resolved then (

						model.GetResourceIDs meshIDs materialIDs textureIDs meshLib:meshLib materialLib:materialLib -- Getting textures
						resolved = MAXLancer.FindResources filename textureIDs textureLib &search "textures" "Texture Library (.txm)|*.txm|All Files (*.*)|*.*"
					)
				)
			)

			if resolved then (
				start = timeStamp()

				-- Build LODs, hardpoints, wireframes
				result = model.Build \
					hardpoints:  hardpointsCheckbox.checked \
					wireframes:  wireframesCheckbox.checked \
					boundaries:  boundariesCheckbox.checked \
					meshLib:     (if meshesCheckbox.checked then meshLib) \
					materialLib: (if materialsCheckbox.checked then materialLib) \
					textureLib:  (if materialsCheckbox.checked then textureLib) \
					progress:    ProgressCallback
				
				-- Buils surfaces
				if centersCheckbox.checked or extentsCheckbox.checked or hullsCheckbox.checked or wrapsCheckbox.checked or nodesCheckbox.checked then
					surfaceLib.Build result (MAXLancer.IsRigidCompound model) \
						centers:  centersCheckbox.checked \
						extents:  extentsCheckbox.checked \
						nodes:    nodesCheckbox.checked \
						hulls:    hullsCheckbox.checked \
						wraps:    wrapsCheckbox.checked \
						dupes:    dupesCheckbox.checked \
						progress: ProgressCallback

				-- Build animations
				if animationsCheckbox.checked then animationLib.Build result

				if materialsCheckbox.checked then (
					local slot = 0
					for id in materialIDs while (slot += 1) <= 24 do setMeditMaterial slot (materialLib.Build id textureLib:textureLib useCache:true)
				)

				-- Remember filename to autofill export's getSaveFileName filename
				setUserProp result #filename filename

				select result
				DestroyDialog ImportRigidRollout
				gc light:false
				messageBox ("Model imported in " + formattedPrint (0.001 * (timeStamp() - start)) format:".2f" + " seconds from:\r\n" + filename) beep:false
			) else importButton.enabled = true

			OK
		) catch (
			importButton.enabled = true
			
			DestroyDialog ImportRigidRollout
			messageBox (getCurrentException())
			if MAXLancer.debug then throw()
		)

		fn SortByName a b property: = stricmp (getProperty a property) (getProperty b property)
		
		fn GetNameFromHash hash = (
			local index = findItem hashes hash
			if index > 0 then names[index] else "0x" + formattedPrint hash format:"08X"
		)
		
		fn SortHulls a b = stricmp (GetNameFromHash a.hullID) (GetNameFromHash b.hullID)

		fn ListLevel level parent = (
			indexCount += level.indexCount

			parent.Nodes.add ("Mesh: 0x" + formattedPrint level.meshID format:"08X")
			parent.Nodes.add ("Groups: " + formattedPrint level.groupStart format:"u" + " to " + formattedPrint (level.groupStart + level.groupCount) format:"u")
			parent.Nodes.add ("Indices: " + formattedPrint level.indexStart format:"u" + " to " + formattedPrint (level.indexStart + level.indexCount) format:"u")
			parent.Nodes.add ("Vertices: " + formattedPrint level.vertexStart format:"u" + " to " + formattedPrint (level.vertexStart + level.vertexCount) format:"u")		
			OK
		)

		fn ListLevels part parent = (
			local levels = part.levels
			local child

			if classOf levels == Array and levels.count > 0 do (
				child = parent.Nodes.add ("Levels (" + formattedPrint levels.count format:"u" + ")")
				meshCount += levels.count

				-- Without loading VMeshData we don't know how many mesh groups it actually has
				for i = 1 to levels.count do ListLevel levels[i] (child.Nodes.add ("Level " + formattedPrint (i - 1) format:"u"))
			)

			if part.wireframe != undefined then (
				parent.Nodes.add ("Wireframe (" + formattedPrint part.wireframe.indices.count format:"u" + " indices)")
				wireCount += 1
			)

			OK
		)

		fn ListHardpoints part parent = (
			local hardpoints = part.hardpoints
			local child

			if hardpoints.count > 0 do (
				child = parent.Nodes.add ("Hardpoints (" + formattedPrint hardpoints.count format:"u" + ")")
				hardpointCount += hardpoints.count

				for hardpoint in hardpoints do child.Nodes.add hardpoint.name
			)

			OK
		)

		-- List collision hulls for part
		fn ListHulls part parent = (
			local surface = surfaceLib.GetPart part.name
			local hulls   = if surface != undefined then surface.GetHulls() else #()
			local child
			local subchild
			local count = 0

			if hulls.count > 0 do (
				child = parent.Nodes.add ("Hulls (" + formattedPrint hulls.count format:"u" + "): " + formattedPrint surface.center format:".3f")

				hullPartCount += 1
				hullCount += hulls.count

				qsort hulls SortHulls

				for hull in hulls do (
					triangleCount += hull.faces.count

					if count > maxHullList then continue -- Limit each part hull listing

					subchild = child.Nodes.add (GetNameFromHash hull.hullID + " (" + formattedPrint hull.faces.count format:"u" + " faces)")				
					if findItem surface.hardpoints hull.hullID then subchild.ForeColor = hardpointHullColor

					count += 1
					if count == maxHullList then child.Nodes.add "..."
				)
			)

			OK
		)
		
		-- List animation scripts for part
		fn ListAnimations part parent = (
			local layers = for animationScript in animationLib.scripts where (if part == model.root then animationScript.GetObjectMap part.name else animationScript.GetJointMap (model.GetPartParent part).name part.name) != undefined collect animationScript.name
			local child

			if layers.count > 0 then (
				child = parent.Nodes.Add "Animations"
				animationCount += 1

				for layerName in layers do child.Nodes.Add layerName
			)
			
			OK
		)

		-- List RigidPart
		fn ListPart part parent = (
			partCount += 1

			ListLevels     part parent
			ListHardpoints part parent
			ListHulls      part parent

			if MAXLancer.IsRigidCompound model then ListAnimations part parent

			OK
		)
		
		-- List RigidCompound
		fn ListCompound root parent = (
			local queue = #(DataPair parent root)
			local part
			local child
			local type
			
			while queue.count > 0 do (
				parent = queue[queue.count].v1
				part   = queue[queue.count].v2

				queue.count = queue.count - 1

				type = if part == model.root then "Compound Root" else MAXLancer.GetJointType (model.GetPartJoint part)
				child = parent.Nodes.add (part.name + " (" + type + ")")
				ListPart part child
				
				if part == model.root then child.Expand()
				for partChild in model.GetPartChildren part do append queue (DataPair child partChild)
			)
			
			OK
		)

		on ImportRigidRollout open do (
			gc light:false -- Free up some memory
			
			treeBox.BackColor = MAXLancer.GetNetColorMan #window
			treeBox.ForeColor = MAXLancer.GetNetColorMan #windowText
			
			try (
				local reader = MAXLancer.CreateUTFReader()
				reader.Open filename

				-- Detect model type instead of relying on file extension
				model = if reader.OpenFolder "Cmpnd" then MAXLancer.CreateRigidCompound() else MAXLancer.CreateRigidPart()
				model.ReadUTF reader
				reader.Close()

				-- Initialize libraries
				meshLib      = MAXLancer.CreateVMeshLibrary()
				materialLib  = MAXLancer.CreateMaterialLibrary()
				textureLib   = MAXLancer.CreateTextureLibrary()
				animationLib = MAXLancer.CreateAnimationLibrary()
				surfaceLib   = MAXLancer.CreateSurfaceLibrary()

				-- Rigid collision surfaces are always stored externally in .sur file matching model filename
				-- Probably they should have kept it inside UTF files
				local surfaceFilename = getFilenamePath filename + getFilenameFile filename + ".sur"

				if doesFileExist surfaceFilename then (
					surfaceLib.LoadFile surfaceFilename
					model.GetHashList hashes names
				)

				-- Compound animations are always stored within .cmp file and unlike .dfm they cannot be kept
				-- externally in .anm file as there is no mechanism to reference them in archetypes.
				if MAXLancer.IsRigidCompound model then (
					animationLib.LoadFile filename
					ListCompound model.root treeBox
				) else ListPart model treeBox

				-- Set interface
				meshesCheckbox.checked     = meshesCheckbox.enabled     = meshCount > 0
				wireframesCheckbox.checked = wireframesCheckbox.enabled = wireCount > 0
				materialsCheckbox.checked  = materialsCheckbox.enabled  = meshCount > 0
				hardpointsCheckbox.checked = hardpointsCheckbox.enabled = hardpointCount > 0
				animationsCheckbox.checked = animationsCheckbox.enabled = animationCount > 0
				boundariesCheckbox.enabled = meshesCheckbox.enabled
				
				centersCheckbox.checked = hullsCheckbox.checked = dupesCheckbox.enabled = centersCheckbox.enabled = extentsCheckbox.enabled = hullsCheckbox.enabled = wrapsCheckbox.enabled = nodesCheckbox.enabled = hullCount > 0

				OK
			) catch (
				DestroyDialog ImportRigidRollout
				messageBox (getCurrentException())
				if MAXLancer.debug then throw()
			)
			
			OK
		)
	)

	on execute do if MAXLancer != undefined then (
		filename = getOpenFileName caption:"Import Rigid Model:" types:"Rigid Models (.3db,.cmp)|*.3db;*.cmp|Single-part Model (.3db)|*.3db|Compound Model (.cmp)|*.cmp|"
		if filename != undefined and doesFileExist filename then CreateDialog ImportRigidRollout
	) else messageBox "MAXLancer is not initialized."
)