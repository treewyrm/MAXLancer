/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Import Freelancer models into 3Ds MAX.
 */
macroscript ImportDeformable category:"MAXLancer" tooltip:"Import Deformable" buttontext:"Import Deformable" iconName:"MAXLancer/import_deformable" (
	global MAXLancer

	local filename -- Filename of import subject
	
	fn FormatSeconds ms = formattedPrint (0.001 * ms) format:".2f"

	-- Import .dfm
	rollout ImportDeformableRollout "Import Deformable Model" width:440 height:360 (
		local model       -- DeformableCompound
		local materialLib -- FLMaterialLibrary
		local textureLib  -- FLTextureLibrary

		local progressCount = 0
		local faceCount     = 0
		local meshCount     = 0

		edittext filenameText "Filename:" pos:[8,12] width:424 height:17 readOnly:true align:#left
		progressBar buildProgress "" pos:[8,12] width:424 height:16 visible:false align:#left
		
		dotNetControl treeBox "System.Windows.Forms.TreeView" pos:[8,40] width:272 height:312 align:#left

		GroupBox modelGroup "Model Components:" pos:[288,40] width:144 height:164 align:#left
		-- checkbox hardpointsCheckbox "Hardpoints" pos:[296,60] width:128 height:16 checked:true align:#left
		-- checkbox meshesCheckbox "Meshes" pos:[296,80] width:128 height:16 checked:true align:#left
		-- checkbox skeletonCheckbox "Skeleton" pos:[296,120] width:128 height:16 checked:true align:#left
		-- checkbox bindPoseCheckbox "Bind to Pose" pos:[296,140] width:128 height:16 checked:true align:#left
		-- checkbox showLinksCheckbox "Show Bone Links" pos:[296,160] width:128 height:16 checked:true align:#left
		checkbox materialsCheckbox "Materials and Textures" pos:[296,180] width:128 height:16 checked:true align:#left

		button importButton "Import Model" pos:[288,328] width:144 height:24 align:#left

		fn ProgressCallback count = (
			buildProgress.value = (progressCount += count) * 100.0 / faceCount
			windows.processPostedMessages()
		)

		on importButton pressed do try (

			local materialIDs = #()
			local textureIDs  = #()
			local resolved    = true
			local search      = #(filename)			
			local flags       = 0
			local start       = 0
			local result

			-- Initialize libraries
			materialLib = MAXLancer.FLMaterialLibrary()
			textureLib  = MAXLancer.FLTextureLibrary()

			-- Textures and materials must be embedded into .dfm file, Freelancer
			-- provides no way to link to external material library.
			if materialsCheckbox.checked then (
				model.GetResourceIDs materialIDs textureIDs -- Getting materials

				resolved = MAXLancer.FindResources filename materialIDs materialLib &search "materials" "Material Library (.mat)|*.mat|All Files (*.*)|*.*"
				
				if resolved then (
					model.GetResourceIDs materialIDs textureIDs materialLib:materialLib -- Getting textures

					resolved = MAXLancer.FindResources filename textureIDs textureLib &search "textures" "Texture Library (.txm)|*.txm|All Files (*.*)|*.*"
				)
			)

			if resolved then (
				start = timeStamp()

				buildProgress.value   = 0
				buildProgress.visible = not (filenameText.visible = false)

				result = model.Build materialLib:materialLib textureLib:textureLib progress:ProgressCallback

				-- Add materials to material editor slots
				if materialsCheckbox.checked then (
					local slot = 0
					for id in materialIDs while slot <= 24 do setMeditMaterial (slot += 1) (materialLib.Build id textureLib:textureLib useCache:true)
				)

				select result
				DestroyDialog ImportDeformableRollout
				gc light:true
				-- messageBox ("Model imported in " + FormatSeconds (timeStamp() - start) + " seconds from:\r\n" + filename)
			)
		) catch (
			DestroyDialog ImportDeformableRollout
			messageBox (getCurrentException())
			if MAXLancer.debug then throw()
		)

		fn ListCompound = (
			local queue = #(DataPair treeBox model.root)
			local parent
			local part
			local child
			local root
			local type
			
			while queue.count > 0 do (
				parent = queue[queue.count].v1
				part   = queue[queue.count].v2
				queue.count = queue.count - 1
				
				type = case classOf (model.GetPartJoint part) of (
					UndefinedClass: "Root"
					(MAXLancer.JointFixed): "Fixed"
					(MAXLancer.JointRevolute): "Revolute"
					(MAXLancer.JointPrismatic): "Prismatic"
					(MAXLancer.JointCylindric): "Cylindric"
					(MAXLancer.JointSpheric): "Spheric"
					(MAXLancer.JointLoose): "Loose"
				)
				
				child = parent.Nodes.add (part.name + " (" + type + ")")

				if parent == treeBox then root = child
				for partChild in model.GetPartChildren part do append queue (DataPair child partChild)
			)
			
			root.Expand()
			
			OK
		)

		fn ListMeshes = (
			local meshNode
			local groupNode

			for i = 1 to model.meshes.count do (
				meshNode = treeBox.Nodes.Add ("Mesh" + formattedPrint (i - 1) format:"u")
				meshCount += 1

				for g = 1 to model.meshes[i].groups.count do (
					groupNode = meshNode.Nodes.Add ("Group" + formattedPrint (g - 1) format:"u")
					groupNode.Nodes.Add ("Material: " + model.meshes[i].groups[g].material)

					if model.meshes[i].groups[g].tristrip then
						groupNode.Nodes.Add ("Triangle strip indices: " + formattedPrint model.meshes[i].groups[g].indices.count format:"u")
					else
						groupNode.Nodes.Add ("Triangle list indices: " + formattedPrint model.meshes[i].groups[g].indices.count format:"u")
				)
			)
		)

		on ImportDeformableRollout open do (
			treeBox.BackColor = MAXLancer.GetNetColorMan #window
			treeBox.ForeColor = MAXLancer.GetNetColorMan #windowText
			
			try (
				filenameText.text = filename

				model = MAXLancer.DeformableCompound()
				model.LoadFile filename

				faceCount = model.GetFaceCount()

				ListCompound()
				ListMeshes()

				OK
			) catch (
				DestroyDialog ImportDeformableRollout
				messageBox (getCurrentException())
				if MAXLancer.debug then throw()
			)
			
			OK
		)
	)

	on execute do if MAXLancer != undefined then (
		filename = getOpenFileName caption:"Import Deformable Model:" types:"Deformable Model (.dfm)|*.dfm|"

		if filename != undefined and doesFileExist filename then CreateDialog ImportDeformableRollout
	) else messageBox "MAXLancer is not initialized."
)