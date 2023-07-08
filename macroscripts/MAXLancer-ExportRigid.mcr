/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Export models into Freelancer formats.
 */
macroscript ExportRigid category:"MAXLancer" tooltip:"Export Rigid" buttontext:"Export Rigid" iconName:"MAXLancer/export_rigid" (
	global MAXLancer

	local target -- RigidPartHelper

	-- Export .3db/.cmp
	rollout ExportRigidRollout "Export Rigid Model" width:440 height:392 (
		local compound       = false
		local indexCount     = 0 -- Number of indices in all mesh references
		local triangleCount  = 0 -- Number of triangles in all hulls
		local partCount      = 0 -- Number of parts
		local meshCount      = 0 -- Number of mesh references
		local materialCount  = 0 -- Number of exportable materials
		local wireCount      = 0 -- Number of HUD wireframes
		local lineCount      = 0 -- Number of lines in all wireframes
		local hardpointCount = 0 -- Number of hardpoints
		local hullCount      = 0 -- Number of convex hulls
		local animationCount = 0 -- Number of animation layers
		local progressCount  = 0 -- Process counter is based off indices
		local damageParts    = #() -- Array of RigidPartHelper
		
		local extraModels -- TreeNode

		dotNetControl treeBox "System.Windows.Forms.TreeView" pos:[8, 8] width:272 height:360

		groupBox modelGroup "Model Resources:" pos:[288, 8] width:144 height:184
		checkbox hardpointsCheckbox "Hardpoints" pos:[296, 28] width:128 height:16 toolTip:"Export model hardpoints to attach equipment."
		checkbox meshesCheckbox "Meshes" pos:[296, 48] width:128 height:16 toolTip:"Export meshes and embed mesh library into model file."
		checkbox smoothingGroupsCheckbox "Smoothing Groups" pos:[296, 68] width:128 height:16 tooltip:"Export smoothing groups. Only used by 3ds Max."
		checkbox wireframesCheckbox "Wireframes" pos:[296, 88] width:128 height:16 toolTip:"Export HUD wireframes from spline objects or LOD visible edges."
		checkbox materialsCheckbox "Materials and Textures" pos:[296, 108] width:128 height:16 toolTip:"Export and embed materials and textures into model file. Required for THN scenery objects and starspheres."
		checkbox materialAnimCheckbox "Material Animations" pos:[296, 128] width:128 height:16 toolTip:"Export material animations."
		checkbox destructibleCheckbox "Destructible Parts" pos:[296, 148] width:128 height:16 toolTip:"Export destructible parts attached to Dp* hardpoints."
		checkbox animationsCheckbox "Compound Animations" pos:[296, 168] width:128 height:16 toolTip:"Export compound animations and embed animation library into model file."

		groupBox surfaceGroup "Surfaces:" pos:[288, 200] width:144 height:64
		checkbox surfacesCheckbox "Collision Surfaces" pos:[296, 220] width:128 height:16 toolTip:"Export surface hulls into hitbox."
		checkbox surfacesForceConvex "Force Convex" pos:[296, 240] width:128 height:16 toolTip:"Rebuilds elements of surface hulls."
		-- checkbox surfacesSimple "Aftermath Format" pos:[296, 260] width:128 height:16 toolTip:"Alternative surface format for Aftermath mod (export only)."

		groupBox miscGroup "Miscellaneous:" pos:[288, 272] width:144 height:64
		checkbox timestampsCheckbox "Timestamp Fragments" pos:[296, 292] width:128 height:16 toolTip:"Add timestamp marker to embedded .3db filenames."
		checkbox versionCheckbox "Add Exporter Version" pos:[296, 312] width:128 height:16 checked:true toolTip:"Add exporter version entry into model file."

		button exportButton "Export Model" pos:[288, 344] width:144 height:24
		progressBar exportProgress "" pos:[8, 376] width:424 height:8
		
		fn ProgressCallback count = (
			exportProgress.value = (progressCount += count) * 100.0 / (indexCount + triangleCount + lineCount)
			windows.processPostedMessages()
		)
		
		fn ExportModel target filename compound:true = (
			local result       = if compound then MAXLancer.CreateRigidCompound() else MAXLancer.CreateRigidPart()
			local meshLib      = MAXLancer.CreateVMeshLibrary()
			local materialLib  = MAXLancer.CreateMaterialLibrary()
			local textureLib   = MAXLancer.CreateTextureLibrary()
			local animationLib = if compound then MAXLancer.CreateAnimationLibrary()
			local surfaceLib   = MAXLancer.CreateSurfaceLibrary() -- if surfacesSimple.checked then MAXLancer.CreateSimpleSurfaceLibrary() else MAXLancer.CreateSurfaceLibrary()
			local writer       = MAXLancer.CreateUTFWriter()
			
			result.filename = filename
			
			-- Parse model
			result.Parse target \
				hardpoints:      hardpointsCheckbox.checked \
				wireframes:      wireframesCheckbox.checked \
				smoothingGroups: smoothingGroupsCheckbox.checked \
				meshLib:         (if meshesCheckbox.checked then meshLib) \
				materialLib:     (if materialsCheckbox.checked then materialLib) \
				textureLib:      (if materialsCheckbox.checked then textureLib) \
				progress:        ProgressCallback
			
			-- Open UTF writer
			writer.Open filename

			-- Write VMeshLibrary
			if meshesCheckbox.checked then meshLib.WriteUTF writer

			-- Write material and texture libraries
			if materialsCheckbox.checked and materialLib != undefined and textureLib != undefined then (
				materialLib.WriteUTF writer
				textureLib.WriteUTF writer
			)
		
			-- Parse and write compound animation library
			if animationsCheckbox.checked and animationLib != undefined then (
				animationLib.Parse target
				animationLib.WriteUTF writer
			)
		
			-- Add Exporter Version
			if versionCheckbox.checked and classOf MAXLancer.exporterVersion == string and MAXLancer.exporterVersion.count > 0 then (
				writer.Reset()
				writer.WriteFileString "Exporter Version" MAXLancer.exporterVersion
			)
		
			result.WriteUTF writer timestamps:timestampsCheckbox.checked
			writer.Close()
		
			-- Parse and write surfaces
			if surfacesCheckbox.checked and surfaceLib != undefined then (
				surfaceLib.Parse target compound forceConvex:surfacesForceConvex.checked progress:ProgressCallback
				surfaceLib.SaveFile (getFilenamePath filename + getFilenameFile filename + ".sur") -- (if surfacesSimple.checked then ".rcd" else ".sur"))
			)
			
			-- Update filename
			setUserProp target #filename filename
			
			OK
		)

		on exportButton pressed do try (
			gc light:false
			
			local filename = getUserProp target #filename
			local start

			-- Replace with unsupplied for filename is optional argument for getSaveFileName
			filename = if filename == undefined then unsupplied else (getFilenamePath filename) + (getFilenameFile filename)

			-- Confirm export filename
			filename = getSaveFileName caption:"Export Freelancer Model:" filename:filename types:(if compound then "Compound Rigid Model (.cmp)|*.cmp|" else "Rigid Model (.3db)|*.3db|")
			
			local prefix = getFilenamePath filename + getFilenameFile filename
			
			if filename != undefined then (
				start = timeStamp()
				
				ExportModel target filename compound:compound
				
				-- Export destructible parts ([filename]_[name].3db)
				for target in damageParts while destructibleCheckbox.checked do
					ExportModel target (prefix + "_" + target.name + ".3db") compound:false

				DestroyDialog ExportRigidRollout
				gc light:false -- Free up some memory
				messageBox ("Model exported in " + formattedPrint (0.001 * (timeStamp() - start)) format:".2f" + " seconds to:\r\n" + filename) beep:false
			)
			
			OK
		) catch (
			DestroyDialog ExportRigidRollout
			messageBox (getCurrentException())
			if MAXLancer.debug then throw()
		)
		
		fn SortByName a b = stricmp a.name b.name

		fn ListHardpoints part parent = (
			local hardpoints = MAXLancer.GetPartHardpoints part
			local child
			local type

			if hardpoints.count > 0 do (
				child = parent.Nodes.add ("Hardpoints (" + formattedPrint hardpoints.count format:"u" + ")")
				hardpointCount += hardpoints.count
				
				qsort hardpoints SortByName

				for hardpoint in hardpoints do (
					type = case hardpoint.type of (
						1: "Fixed"
						2: "Revolute"
						3: "Prismatic"
					)

					child.Nodes.add (hardpoint.name + " (" + type + ")")
				)
			)

			OK
		)

		fn ListHulls part parent = (
			local center     -- Point3
			local hardpoints -- Array of Integer
			local elements   -- Array of BitArray
			local child      -- TreeViewNode
			local subchild   -- TreeViewNode

			local items = MAXLancer.GetPartSurfaces part &hardpoints &center
			
			if items.count > 0 do (
				child = parent.Nodes.add ("")

				qsort items SortByName
				
				local count = 0

				for item in items do if MAXLancer.IsHardpointHelper item then (
					subchild = child.Nodes.add ("*" + item.name + " (" + formattedPrint (getNumFaces item.hullMesh) format:"u" + " faces)")
					
					triangleCount += getNumFaces item.hullMesh
					hullCount += 1
					count += 1
					
					subchild.Text = "*" + subchild.Text
				) else if classOf item == Editable_mesh then (
					elements = MAXLancer.GetMeshElements item

					triangleCount += getNumFaces item
					hullCount += elements.count
					count += elements.count

					for faces in elements do (
						subchild = child.Nodes.add (item.name + " (" + formattedPrint faces.numberSet format:"u" + " faces)")
						if item.parent != part then subchild.Text += ": " + item.parent.name

						if findItem hardpoints (MAXLancer.Hash item.name) > 0 then subchild.Text = "*" + subchild.Text
					)
				)
				
				child.Text = "Hulls (" + formattedPrint count format:"u" + "): " + formattedPrint center format:".3f"
			)

			OK
		)

		fn ListMaterial index name parent = (
			parent.Nodes.add (formattedPrint index format:"02u" + ": " + name)
			materialCount += 1
			OK
		)

		fn ListLevel level index parent previousRange:0 = (
			local child
			local mCount = 0
			-- local materials
			-- local faces

			indexCount += case level.mode of (
				1: getNumVerts level
				4: 3 * getNumFaces level
				default: 0
			)

			-- Face count is incorrect if level is editable poly. //  + " (" + formattedPrint (getNumFaces level) format:"u" + " faces)"
			child = parent.Nodes.add ("Level " + formattedPrint index format:"u" + ": " + level.name)
			child.Nodes.add ("Range: " + formattedPrint previousRange format:"f" + "-" + formattedPrint level.range format:"f")

			-- List materials
			case classOf level.material of (
				Multimaterial: for m in level.material.materialList do ListMaterial (mCount += 1) m.name child
				default: ListMaterial 1 level.material.name child
			)
			
			OK
		)

		fn ListLevels part parent = (
			local wireframe 
			local levels = MAXLancer.GetPartLevels part &wireframe
			local child
			local type
			local range = 0

			-- List LODs
			if levels.count > 0 then (
				child = parent.Nodes.add ("Levels (" + formattedPrint levels.count format:"u" + ")")
				meshCount += levels.count

				for i = 1 to levels.count do (
					ListLevel levels[i] i child previousRange:range
					range = levels[i].range
				)
			)

			if wireframe != undefined then (
				type = case superClassOf wireframe of (
					GeometryClass: (
						lineCount += wireframe.edges.count 
						"Edges"
					)
					Shape: (
						for s = 1 to numSplines wireframe do lineCount += numSegments wireframe s
						"Line"
					)
				)

				parent.Nodes.add ("Wireframe (" + type + "): " + wireframe.name)
				wireCount += 1
			)

			OK
		)

		fn ListAnimations part parent = (
			local layers = MAXLancer.GetAnimations part

			if layers.count > 0 do (
				parent = parent.Nodes.Add ("Animations (" + layers.count as String + ")")
				animationCount += 1

				for name in layers do parent.Nodes.Add name
			)

			OK
		)
		
		fn ListCamera part parent = (
			local child = parent.Nodes.Add ("Camera")

			child.Nodes.Add ("Fov X: " + formattedPrint part.fovX format:".2f")
			child.Nodes.Add ("Fov Y: " + formattedPrint part.fovY format:".2f")
			child.Nodes.Add ("zNear Clip: " + formattedPrint part.zNear format:".2f")
			child.Nodes.Add ("zFar Clip: " + formattedPrint part.zFar format:".2f")

			OK
		)

		fn ListPart part parent = (
			partCount += 1

			if part.isCamera then ListCamera part parent else (
				ListLevels     part parent
				ListHardpoints part parent
				ListHulls      part parent
			)

			if compound then ListAnimations part parent

			OK
		)

		fn ListDamageModel part parent = (
			local model     -- RigidPartHelper
			local hardpoint -- HardpointHelper
			local duplicateName = false

			MAXLancer.GetPartDamageModel part &model &hardpoint

			if model != undefined and hardpoint != undefined then (

				-- Check duplicate name
				for damagePart in damageParts while not duplicateName where MAXLancer.Hash damagePart.name == MAXLancer.Hash model.name do duplicateName = true
				if duplicateName then throw ("Duplicate damage part name: " + model.name)

				-- Check DpConnect hardpoint in damage part
				if MAXLancer.FindHardpoint model "DpConnect" == undefined then throw ("Damage part " + model.name + " is missing DpConnect hardpoint.")

				-- Check dmg_hp presence
				if not MAXLancer.IsHardpointHelper hardpoint then throw ("Damage part has no target hardpoint: " + model.name)

				-- Check dmg_hp to be in part parent
				if hardpoint.parent != part.parent then throw ("Damage hardpoint " + hardpoint.name + " has invalid parent object.")

				parent.Nodes.Add ("Damage part: " + model.name)
				ListPart model (treeBox.Nodes.Add (part.name + " (" + hardpoint.name + "): " + model.name))

				append damageParts model
			)

			OK
		)

		fn ListCompound root parent = (
			local queue = #(DataPair parent root)
			local child -- Part list node
			local part  -- RigidPartHelper
			local joint -- Part joint
			local type  -- Part type
			
			while queue.count > 0 do (
				parent = queue[queue.count].v1
				part   = queue[queue.count].v2
				queue.count = queue.count - 1

				joint = MAXLancer.GetCompoundJoint part root:(root == part)
				type  = MAXLancer.GetJointType joint				
				child = parent.Nodes.Add (part.name + " (" + type + ")")
				
				ListPart part child

				if part != root then ListDamageModel part child
				if part == root then child.Expand()

				for subpart in part.children where MAXLancer.IsRigidPartHelper subpart do append queue (DataPair child subpart)
			)

			OK
		)

		on ExportRigidRollout open do (
			gc light:false
			
			treeBox.BackColor = MAXLancer.GetNetColorMan #window
			treeBox.ForeColor = MAXLancer.GetNetColorMan #windowText
			
			try (

				-- Detect compound model export or explicit flag in root
				compound = (MAXLancer.GetPartChildren target).count > 0 or target.compound

				-- List parts and contents to export
				if compound then ListCompound target treeBox else ListPart target treeBox

				-- Setup interface
				meshesCheckbox.checked       = meshesCheckbox.enabled       = meshCount > 0
				wireframesCheckbox.checked   = wireframesCheckbox.enabled   = wireCount > 0
				hardpointsCheckbox.checked   = hardpointsCheckbox.enabled   = hardpointCount > 0
				surfacesCheckbox.checked     = surfacesCheckbox.enabled     = hullCount > 0
				materialAnimCheckbox.checked = materialAnimCheckbox.enabled = false
				animationsCheckbox.checked   = animationsCheckbox.enabled   = animationCount > 0
				timestampsCheckbox.checked   = timestampsCheckbox.enabled   = compound
				destructibleCheckbox.checked = destructibleCheckbox.enabled = damageParts.count > 0
				materialsCheckbox.enabled    = materialCount > 0

				OK
			) catch (
				DestroyDialog ExportRigidRollout
				messageBox (getCurrentException())
				if MAXLancer.debug then throw()
			)
		)
	)

	on execute do if MAXLancer != undefined then (
		target = if selection.count == 1 then selection[1]
		if MAXLancer.IsRigidPartHelper target then CreateDialog ExportRigidRollout else messageBox "Please select root rigid part helper to export."
	) else messageBox "MAXLancer is not initialized."
)