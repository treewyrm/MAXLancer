/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Export models into Freelancer formats.
 */
macroscript ExportRigid category:"MAXLancer" tooltip:"Export Rigid" buttontext:"Export Rigid" iconName:"MAXLancer/export_rigid" (
	global MAXLancer

	local hardpointHullColor = (dotNetClass "System.Drawing.Color").LightSteelBlue
	local target -- RigidPartHelper

	-- Export .3db/.cmp
	rollout ExportRigidRollout "Export Rigid Model" width:440 height:352 (
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
		local materialCount  = 0 -- Number of exportable materials
		local wireCount      = 0 -- Number of HUD wireframes
		local lineCount      = 0 -- Number of lines in all wireframes
		local hardpointCount = 0 -- Number of hardpoints
		local hullCount      = 0 -- Number of convex hulls
		local animationCount = 0 -- Number of animation layers

		local progressCount  = 0 -- Process counter is based off indices

		dotNetControl treeBox "System.Windows.Forms.TreeView" pos:[8, 8] width:272 height:320

		groupBox modelGroup "Model Resources:" pos:[288, 8] width:144 height:144
		checkbox hardpointsCheckbox "Hardpoints" pos:[296, 28] width:128 height:16 toolTip:"Export model hardpoints to attach equipment."
		
		checkbox meshesCheckbox "Meshes" pos:[296, 48] width:128 height:16 toolTip:"Export meshes and embed mesh library into model file."
		checkbox wireframesCheckbox "Wireframes" pos:[296, 68] width:128 height:16 toolTip:"Export HUD wireframes from spline objects or LOD visible edges."
		checkbox materialsCheckbox "Materials and Textures" pos:[296, 88] width:128 height:16 toolTip:"Export and embed materials and textures into model file. Required for THN scenery objects and starspheres."
		checkbox materialAnimCheckbox "Material Animations" pos:[296, 108] width:128 height:16 toolTip:"Export material animations."
		checkbox animationsCheckbox "Compound Animations" pos:[296, 128] width:128 height:16 toolTip:"Export compound animations and embed animation library into model file."
		
		groupBox surfaceGroup "Surfaces:" pos:[288, 160] width:144 height:64
		checkbox surfacesCheckbox "Collision Surfaces" pos:[296, 180] width:128 height:16 toolTip:"Export surface hulls into hitbox."
		checkbox surfacesForceConvex "Force Convex" pos:[296, 200] width:128 height:16 toolTip:"Rebuilds elements of surface hulls."

		groupBox miscGroup "Miscellaneous:" pos:[288, 232] width:144 height:64
		checkbox timestampsCheckbox "Timestamp Fragments" pos:[296, 252] width:128 height:16 toolTip:"Add timestamp marker to embedded .3db filenames."
		checkbox versionCheckbox "Add Exporter Version" pos:[296, 272] width:128 height:16 checked:true toolTip:"Add exporter version entry into model file."
	
		button exportButton "Export Model" pos:[288, 304] width:144 height:24
		progressBar exportProgress "" pos:[8, 336] width:424 height:8
		
		fn ProgressCallback count = (
			exportProgress.value = (progressCount += count) * 100.0 / (indexCount + triangleCount + lineCount)
			windows.processPostedMessages()
		)

		on exportButton pressed do try (
			gc light:false
			
			local filename = getUserProp target #filename
			local result
			local writer
			local mode = 0
			local start

			-- Replace with unsupplied for filename is optional argument for getSaveFileName
			filename = if filename == undefined then unsupplied else (getFilenamePath filename) + (getFilenameFile filename)

			-- Confirm export filename
			filename = getSaveFileName caption:"Export Freelancer Model:" filename:filename types:(if compound then "Compound Rigid Model (.cmp)|*.cmp|" else "Rigid Model (.3db)|*.3db|")
			
			if filename != undefined then (
				start = timeStamp()

				-- Initialize libraries
				meshLib      = MAXLancer.CreateVMeshLibrary()
				materialLib  = MAXLancer.CreateMaterialLibrary()
				textureLib   = MAXLancer.CreateTextureLibrary()
				animationLib = MAXLancer.CreateAnimationLibrary()
				surfaceLib   = MAXLancer.CreateSurfaceLibrary()

				-- Parse into model
				result = if compound then MAXLancer.CreateRigidCompound() else MAXLancer.CreateRigidPart()
				result.filename = filename

				-- Parse model
				result.Parse target \
					hardpoints:  hardpointsCheckbox.checked \
					wireframes:  wireframesCheckbox.checked \
					meshLib:     (if meshesCheckbox.checked then meshLib) \
					materialLib: (if materialsCheckbox.checked then materialLib) \
					textureLib:  (if materialsCheckbox.checked then textureLib) \
					progress:    ProgressCallback

				-- Open UTF writer
				writer = MAXLancer.CreateUTFWriter()
				writer.Open filename

				-- Write VMeshLibrary
				if meshesCheckbox.checked then meshLib.WriteUTF writer

				-- Write material and texture libraries
				if materialsCheckbox.checked then (
					materialLib.WriteUTF writer
					textureLib.WriteUTF writer
				)
			
				-- Parse and write compound animation library
				if animationsCheckbox.checked then (
					animationLib.Parse target
					animationLib.WriteUTF writer
				)
			
				-- Add Exporter Version
				if versionCheckbox.checked then (
					writer.Reset()
					writer.WriteFileString "Exporter Version" MAXLancer.exporterVersion
				)
			
				-- Write .3db/.cmp
				result.WriteUTF writer timestamps:timestampsCheckbox.checked
				writer.Close()
			
				-- Parse and write surfaces
				if surfacesCheckbox.checked then (
					surfaceLib.Parse target compound forceConvex:surfacesForceConvex.checked progress:ProgressCallback
					surfaceLib.SaveFile (getFilenamePath filename + getFilenameFile filename + ".sur")
				)
			
				-- Update filename
				setUserProp target #filename filename

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
					subchild = child.Nodes.add (item.name + " (" + formattedPrint (getNumFaces item.hullMesh) format:"u" + " faces)")
					
					triangleCount += getNumFaces item.hullMesh
					hullCount += 1
					count += 1
					
					subchild.ForeColor = hardpointHullColor
				) else if classOf item == Editable_mesh then (
					elements = MAXLancer.GetMeshElements item

					triangleCount += getNumFaces item
					hullCount += elements.count
					count += elements.count

					for faces in elements do (
						subchild = child.Nodes.add (item.name + " (" + formattedPrint faces.numberSet format:"u" + " faces)")
						if item.parent != part then subchild.Text += ": " + item.parent.name

						if findItem hardpoints (MAXLancer.Hash item.name) > 0 then subchild.ForeColor = hardpointHullColor
					)
				)
				
				child.Text = "Hulls (" + formattedPrint count format:"u" + "): " + formattedPrint center format:".3f"
			)

			OK
		)

		fn ListLevel level index parent = (
			local child
			local materials
			local faces

			indexCount += case level.mode of (
				1: getNumVerts level
				4: 3 * getNumFaces level
				default: 0
			)

			child = parent.Nodes.add ("Level " + formattedPrint index format:"u" + ": " + level.name + " (" + formattedPrint (getNumFaces level) format:"u" + " faces)")
			child.Nodes.add ("Range: " + formattedPrint level.range format:"f")

			MAXLancer.GetMeshMaterials level &materials &faces

			-- List LOD materials and face count
			for m = 1 to materials.count do (
				child.Nodes.add (formattedPrint m format:"02u" + ": " + materials[m].name + " (" + formattedPrint faces[m].numberSet format:"u" + " faces)")

				if classOf materials[m] == DxMaterial then materialCount += 1
			)

			OK
		)

		fn ListLevels part parent = (
			local wireframe 
			local levels = MAXLancer.GetPartLevels part &wireframe
			local child
			local type

			-- List LODs
			if levels.count > 0 do (
				child = parent.Nodes.add ("Levels (" + formattedPrint levels.count format:"u" + ")")
				meshCount += levels.count

				for i = 1 to levels.count do ListLevel levels[i] i child
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
				parent = parent.Nodes.Add "Animations"
				animationCount += 1

				for name in layers do parent.Nodes.Add name
			)

			OK
		)

		fn ListPart part parent = (
			partCount += 1

			ListLevels     part parent
			ListHardpoints part parent
			ListHulls      part parent

			if compound then ListAnimations part parent

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
				child = parent.Nodes.add (part.name + " (" + type + ")")
				ListPart part child
				
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