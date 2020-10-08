/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Export materials from scene/selected objects into Freelancer material library.
 */
macroscript ExportMaterials category:"MAXLancer" tooltip:"Export Materials" buttontext:"Export Materials" iconName:"MAXLancer/export_materials" (
	global MAXLancer

	local filename -- Filename of import subject

	rollout ExportMaterialsRollout "Export Materials and Textures" width:352 height:476 (
		local textureLib
		local materialLib
		local meshes        = #() -- List of scene meshes
		local materialFaces = #()

		dotNetControl treeBox "System.Windows.Forms.TreeView" pos:[8, 8] width:336 height:416 align:#left

		checkbox texturesCheckbox  "Export Textures" pos:[8,432] width:184 height:16 align:#left
		checkbox materialsCheckbox "Export Materials" pos:[8,452] width:184 height:16 align:#left

		button exportButton "Export Resources" pos:[200,444] width:144 height:24 align:#left

		fn GetPropertyDisplay property target &displayName &displayValue = (
			displayName = case property of (
				#DiffuseTexture:  "Diffuse Texture"
				#EmissionTexture: "Emission Texture"
				#DetailTexture:   "Detail Texture"
				#NomadTexture:    "Nomad Texture"
				#DiffuseColor:    "Diffuse Color"
				#EmissionColor:   "Emission Color"
				#AmbientColor:    "Ambient Color"
			)

			displayValue = case classOf target of (
				(MAXLancer.FLMaterialMap): target.filename
				color: (
					"R: " + formattedPrint (target.r / 255) format:".3f" + \
					" G: " + formattedPrint (target.g / 255) format:".3f" + \
					" B: " + formattedPrint (target.b / 255) format:".3f" + \
					" A: " + formattedPrint (target.a / 255) format:".3f"
				)
			)

			OK
		)

		fn ListMaterial target parent = (
			-- parent = parent.Nodes.add ("0x" + formattedPrint (MAXLancer.hash target.name) format:"08X" + ": " + target.name)
			parent = parent.Nodes.add target.name
			parent.Nodes.add ("Type: " + MAXLancer.shaders.GetTypeByMaterial target)

			local propertyName
			local propertyValue
			local displayName
			local displayValue

			-- Look through properties to display
			for propertyName in getPropNames target where (propertyValue = getProperty target propertyName) != undefined do (
				GetPropertyDisplay propertyName propertyValue &displayName &displayValue

				if displayName != undefined and displayValue != undefined then
					parent.Nodes.add (displayName + ": " + displayValue)
			)

			local index = 0
			for i = 1 to materialLib.materials.count while index == 0 where stricmp materialLib.materials[i].name target.name == 0 do index = i

			if index > 0 then (
				parent = parent.Nodes.add ("Meshes (" + formattedPrint meshes[index].count format:"u" + ")")

				for i = 1 to meshes[index].count do
					parent.Nodes.add (meshes[index][i].name + " (" + formattedPrint materialFaces[index][i].numberSet format:"u" + " faces)")
			)

			OK
		)

		fn ListTexture target parent = (
			local type = case MAXLancer.FLTextureLibrary.GetTextureType target.external of (
				#DDS_RGBA:  "Uncompressed RGBA in DDS"
				#DDS_DXT1:  "Compressed DXT1 in DDS"
				#DDS_DXT1A: "Compressed DXT1a in DDS"
				#DDS_DXT3:  "Compressed DXT3 in DDS"
				#DDS_DXT5:  "Compressed DXT5 in DDS"
				#TGA_MAPS:  "Uncompressed RGB(A) in Targa + mipmaps"
				#MIPS:      "Unmodified DDS"
				#MIP0:      "Unmodified Targa"
				default:    "Unknown format"
			)
			
			-- parent = parent.Nodes.add ("0x" + formattedPrint (MAXLancer.hash target.filename) format:"08X" + ": " + target.filename)
			parent = parent.Nodes.add target.filename

			parent.Nodes.add ("Filename: " + target.external)
			parent.Nodes.add ("Export mode: " + type)
		)

		on exportButton pressed do if materialsCheckbox.checked or texturesCheckbox.checked then (
			local filename = getSaveFileName caption:"Export Freelancer Materials:" types:"Material Library (.mat)|*.mat|"
			local writer

			if filename != undefined then (
				writer = MAXLancer.UTFWriter()
				writer.Open filename
				
				if materialsCheckbox.checked then materialLib.WriteUTF writer
				if texturesCheckbox.checked then textureLib.WriteUTF writer

				writer.Close()

				DestroyDialog ExportMaterialsRollout
				messageBox ("Materials exported to:\r\n" + filename) beep:false
			)

			OK
		)

		on ExportMaterialsRollout open do (
			treeBox.BackColor = MAXLancer.GetNetColorMan #window
			treeBox.ForeColor = MAXLancer.GetNetColorMan #windowText
			
			textureLib  = MAXLancer.FLTextureLibrary()
			materialLib = MAXLancer.FLMaterialLibrary()
			
			local parent
			local queue = getCurrentSelection()
			local index = 0

			local materials
			local faces
			
			if queue.count == 0 then queue = for o in objects where o.parent == undefined collect o

			-- Collect materials from selected objects or all objects in scene
			while queue.count > 0 do (
				item = queue[queue.count]
				queue.count = queue.count - 1

				if classOf item == Editable_mesh and custAttributes.get item MAXLancer.VMeshAttributes != undefined then (
					MAXLancer.GetMeshMaterials item &materials &faces

					for m = 1 to materials.count do (
						if materialLib.GetMaterial materials[m].name == undefined then (
							append materialLib.materials (materialLib.Parse materials[m] textureLib:textureLib)
							append meshes #(item)
							append materialFaces #(faces[m])
						) else (
							index = 0
							for i = 1 to materialLib.materials.count while index == 0 where stricmp materialLib.materials[i].name materials[m].name == 0 do index = i
							if index > 0 then (
								append meshes[index] item
								append materialFaces[index] faces[m]
							)
						)
					)
				)

				for child in item.children do append queue child
			)
			
			texturesCheckbox.checked  = texturesCheckbox.enabled  = textureLib.textures.count > 0
			materialsCheckbox.checked = materialsCheckbox.enabled = materialLib.materials.count > 0

			-- List collected materials
			parent = treeBox.Nodes.add ("Materials (" + formattedPrint materialLib.materials.count format:"u" + ")")
			for item in materialLib.materials do ListMaterial item parent
			parent.Expand()

			-- List collected textures
			parent = treeBox.Nodes.add ("Textures (" + formattedPrint textureLib.textures.count format:"u" + ")")
			for item in textureLib.textures do ListTexture item parent
			parent.Expand()
			
			OK
		)
	)

	on execute do if MAXLancer != undefined then CreateDialog ExportMaterialsRollout else messageBox "MAXLancer is not initialized."
)