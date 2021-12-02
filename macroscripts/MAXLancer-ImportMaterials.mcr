/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Import materials and textures into 3Ds MAX material editor.
 */
macroscript ImportMaterials category:"MAXLancer" tooltip:"Import Materials" buttontext:"Import Materials" iconName:"MAXLancer/import_materials" (
	global MAXLancer

	local filename -- Filename of import subject

	rollout ImportMaterialsRollout "Import Materials" width:320 height:448 (
		local textureLib
		local materialLib
		local targets -- Array of objects

		dotNetControl materialsListView "System.Windows.Forms.ListView" pos:[8, 8] width:304 height:376

		checkbox overwriteCheckbox "Overwrite matching materials in scene or selection" checked:true pos:[8, 392] width:304 height:16 tooltip:"Automatically replaces matching materials for objects in scene."

		button selectAllButton "Select All" pos:[8, 416] width:88 height:24
		button selectNoneButton "Select None" pos:[104, 416] width:88 height:24
		button importButton "Import" pos:[224, 416] width:88 height:24

		on selectAllButton pressed do for i = 1 to materialsListView.Items.count do (materialsListView.Items.Item (i - 1)).Checked = true
		on selectNoneButton pressed do for i = 1 to materialsListView.Items.count do (materialsListView.Items.Item (i - 1)).Checked = false
			
		on importButton pressed do (
			local count = materialsListView.CheckedItems.count

			if count == 0 then messageBox "Select material(s) to import." else try (
				local names    = for i = 1 to count collect (materialsListView.CheckedItems.Item (i - 1)).Text
				local textures = #()
				local resolved = true
				local slot     = 0
				local search   = #(filename)
				
				-- TODO: Bring up locate files dialogue if referenced textures are in another file				
				for m = 1 to names.count do join textures (materialLib.GetTextureIDs (materialLib.GetMaterial names[m]))
				
				resolved = MAXLancer.FindResources filename textures textureLib &search "textures" "Texture Library (.txm)|*.txm|All Files (*.*)|*.*"

				if resolved then (
					local materials = for id in names collect materialLib.Build id textureLib:textureLib useCache:false
					local hashes = for m in materials collect MAXLancer.Hash m.name
					local index
					local slotIndex = activeMeditSlot

					for m = 1 to materials.count while slotIndex <= 24 do (
						setMeditMaterial slotIndex materials[m]
						slotIndex += 1
					)

					if overwriteCheckbox.checked then (
						for target in targets do case classOf target.material of (
							Multimaterial: for i = 1 to target.material.count where (index = findItem hashes (MAXLancer.Hash target.material.materialList[i].name)) > 0 do target.material.materialList[i] = materials[index]
							UndefinedClass: () -- Nothing to do
							default: if (index = findItem hashes (MAXLancer.Hash target.material.name)) > 0 then target.material = materials[index]
						)
					)

					DestroyDialog ImportMaterialsRollout
					messageBox (formattedPrint count format:"u" + " materials were imported into material editor.")
				)

				OK
			) catch (
				DestroyDialog ImportMaterialsRollout
				messageBox (getCurrentException())
				if MAXLancer.debug then throw()
			)
		)

		on ImportMaterialsRollout open do (
			targets = #()

			if selection.count > 0 then for target in selection do case of (
				(MAXLancer.IsRigidPartHelper target): join targets (MAXLancer.GetModelLevels target)
				(MAXLancer.IsRigidLevel target): append targets target
			)

			local hashes    = #()
			local materials = #()
			local faces     = #()
			
			for target in targets do (
				MAXLancer.GetMeshMaterials target &materials &faces
				for m in materials do appendIfUnique hashes (MAXLancer.Hash m.name)
			)
			
			materialsListView.BackColor = MAXLancer.GetNetColorMan #window
			materialsListView.ForeColor = MAXLancer.GetNetColorMan #windowText
			
			materialsListView.View        = (dotNetClass "System.Windows.Forms.View").Details
			-- materialsListView.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").None
			
			materialsListView.CheckBoxes = true
			materialsListView.GridLines  = false
			
			materialsListView.columns.Add "Name" 224
			materialsListView.columns.Add "Type" 130
			
			overwriteCheckbox.checked = overwriteCheckbox.enabled = materials.count > 0

			try (
				local listItem
				local listItems = #()

				textureLib  = MAXLancer.CreateTextureLibrary()
				materialLib = MAXLancer.CreateMaterialLibrary()

				materialLib.LoadFile filename

				for target in materialLib.materials do (
					listItem = dotNetObject "System.Windows.Forms.ListViewItem" target.name
					listItem.subitems.Add ((MAXLancer.GetShaders()).GetTypeByMaterial target)
					append listItems listItem
					
					if findItem hashes (MAXLancer.Hash target.name) > 0 then listItem.Checked = true
				)

				materialsListView.items.AddRange listItems
				materialsListView.Update()
			) catch (
				DestroyDialog ImportMaterialsRollout
				messageBox (getCurrentException())
				if MAXLancer.debug then throw()
			)
		)
	)

	fn LocateFile = (
		filename = getOpenFileName caption:"Import Freelancer Materials:" types:"UTF Files (.mat,.3db,.cmp,.dfm)|*.mat;*.3db;*.cmp;*.dfm|Material Library (.mat)|*.mat|Single-part Model (.3db)|*.3db|Compound Model (.cmp)|*.cmp|Deformable Model (.dfm)|*.dfm|"
		if filename != undefined and doesFileExist filename then CreateDialog ImportMaterialsRollout
	)

	on execute do if MAXLancer != undefined then LocateFile() else messageBox "MAXLancer is not initialized."
)