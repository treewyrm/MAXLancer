/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Search resources in UTF files.
 */
macroscript FindResources category:"MAXLancer" tooltip:"Find Resources" buttontext:"Find Resources" iconName:"MAXLancer/toolbar" (
	global MAXLancer

	rollout FindResourcesRollout "Find Resources" width:600 height:600 (
		local logFont = dotNetObject "System.Drawing.Font" "Consolas" 9
		
		edittext searchInput "" pos:[8,12] width:456 labelOnTop:true align:#left
		button searchButton "Search" pos:[472,8] width:120 height:24 align:#left
		button findMeshCollisionsButton "Check Meshes" pos:[472, 34] width:120 height:24 align:#left
		
		checkbox materialLibrariesCheckbox "Material libraries" pos:[16,40] width:128 height:16 align:#left checked:true
		checkbox textureLibrariesCheckbox "Texture libraries" pos:[144,40] width:128 height:16 align:#left
		checkbox modelFilesCheckbox "Model files" pos:[272,40] width:128 height:16 align:#left

		dotNetControl messagesBox "System.Windows.Forms.Textbox" pos:[0,0] align:#left
		
		label statusLabel "Status" pos:[8,368] width:584 height:16 align:#left
		
		dotNetControl searchProgress "System.Windows.Forms.ProgressBar" pos:[8, 0] height:8 align:#left

		fn WriteLine input = messagesBox.AppendText (input as string + "\r\n")
		
		fn resize size = (
			searchProgress.pos.y = size.y - 16
			statusLabel.pos.y = searchProgress.pos.y - 24
			searchProgress.width = statusLabel.width = size.x - 16
			
			searchButton.pos.x = size.x - 128
			findMeshCollisionsButton.pos.x = size.x - 128
			searchInput.width = searchButton.pos.x - 16
			
			messagesBox.pos.x = 8
			messagesBox.pos.y = 64
			messagesBox.width = size.x - 16
			messagesBox.height = size.y - messagesBox.pos.y - (size.y - statusLabel.pos.y + 8)
		)

		on findMeshCollisionsButton pressed do (
			messagesBox.Clear()

			local start = timeStamp()
			local files = MAXLancer.FilterFiles MAXLancer.freelancerPath recursive:true directoryMask:"*" fileMasks:#("*.3db", "*.cmp")

			WriteLine ("Scanning " + files.count as string + " files")
			
			searchProgress.Minimum = searchProgress.Value = 0
			searchProgress.Maximum = files.count
			searchProgress.Step = 1

			local reader = MAXLancer.CreateUTFReader()
			local filenames = #()
			local vmeshes   = #()
			local vmeshCRCs = #()

			for filename in files do (
				statusLabel.text = filename

				try (
					reader.Open filename

					if reader.OpenFolder "VMeshLibrary" then (
						local meshNames  = #() -- Array of strings
						local meshHashes = #() -- Array of hashes
						local index = 0

						append filenames filename
						append vmeshes   meshNames
						append vmeshCRCs meshHashes

						for entryname in reader.GetFolders() do (
							local crc = MAXLancer.Hash entryname
							local duplicates = #()

							for i = 1 to filenames.count do (
								index = findItem vmeshCRCs[i] crc

								if index > 0 then append duplicates (DataPair i index)
							)
							
							if duplicates.count > 0 then (
								WriteLine ("Duplicate mesh (" + entryname + ") in (" + filename + ") found in:")
								
								for i = 1 to duplicates.count do (
									local fileIndex = duplicates[i].v1
									local meshIndex = duplicates[i].v2
									
									WriteLine("\t" + filenames[fileIndex]);
								)
							)

							append meshNames entryname
							append meshHashes crc

							-- WriteLine ("Mesh (" + entryname + "): " + filename); entryNames[index] = entryname
						)

						reader.CloseFolder()
					)

					reader.Close()					
				) catch (
					WriteLine ("ERROR (" + filename + "): " + getCurrentException())
					reader.Close()
				)

				searchProgress.PerformStep()
			)

			statusLabel.text = "Completed in " + formattedPrint (0.001 * (timeStamp() - start)) format:".2f" + " seconds."
		)
		
		on searchButton pressed do (
			local start = timeStamp()
			local masks = #()
			
			local subjects = for part in filterString searchInput.text ";" collect trimLeft (trimRight part)
			
			if materialLibrariesCheckbox.checked then join masks #("*.mat")
			if textureLibrariesCheckbox.checked then join masks #("*.mat", "*.txm")
			if modelFilesCheckbox.checked then join masks #("*.3db", "*.cmp", "*.dfm")
			
			messagesBox.Clear()
			
			local hashes = for subject in subjects collect (
				local hash = MAXLancer.Hash subject
				WriteLine ("Searching for: 0x" + formattedPrint hash format:"08X" + " (" + subject + ")")
				hash
			)
			
			local files = MAXLancer.FilterFiles MAXLancer.freelancerPath recursive:true directoryMask:"*" fileMasks:masks
				
			WriteLine ("Scanning " + files.count as string + " files")
			
			searchProgress.Minimum = searchProgress.Value = 0
			searchProgress.Maximum = files.count
			searchProgress.Step = 1
			
			local reader = MAXLancer.CreateUTFReader()
			local meshes = MAXLancer.CreateVMeshLibrary()
			local usedByMesh = false
			local index = 0
			local entryNames = #()
			
			for filename in files do (
				statusLabel.text = filename
				meshes.meshes.count = 0
				
				try (
					reader.Open filename

					if reader.OpenFolder "Material library" then (
						for entryname in reader.GetFolders() where (index = findItem hashes (MAXLancer.hash entryname)) > 0 do (WriteLine ("Material (" + entryname + "): " + filename); entryNames[index] = entryname)
						reader.CloseFolder()
					)
					
					if reader.OpenFolder "Texture library" then (
						for entryname in reader.GetFolders() where (index = findItem hashes (MAXLancer.hash entryname)) > 0 do (WriteLine ("Texture (" + entryname + "): " + filename); entryNames[index] = entryname)
						reader.CloseFolder()
					)
					
					if reader.OpenFolder "VMeshLibrary" then (
						for entryname in reader.GetFolders() where (index = findItem hashes (MAXLancer.hash entryname)) > 0 do (WriteLine ("Mesh (" + entryname + "): " + filename); entryNames[index] = entryname)
						reader.CloseFolder()
					)
					
					meshes.ReadUTF reader buffers:false
					
					for subject in subjects do (
						usedByMesh = false
						
						for vmesh in meshes.meshes while not usedByMesh do
							for vgroup in vmesh.groups while not usedByMesh where vgroup.materialID == MAXLancer.hash subject do usedByMesh = true
								
							
						if usedByMesh then WriteLine (subject + " is used by mesh in: " + filename)
					)
					
					reader.Close()					
				) catch (
					WriteLine ("ERROR (" + filename + "): " + getCurrentException())
					reader.Close()
				)

				searchProgress.PerformStep()
			)
			
			for i = 1 to hashes.count where entryNames[i] != undefined do
				WriteLine ("Found 0x" + formattedPrint hashes[i] format:"08X" + " as: " + entryNames[i])
			
			statusLabel.text = "Completed in " + formattedPrint (0.001 * (timeStamp() - start)) format:".2f" + " seconds."
		)

		on FindResourcesRollout resized size do resize size
			
		on FindResourcesRollout open do (
			messagesBox.Font        = logFont
			messagesBox.ReadOnly    = true
			messagesBox.MultiLine   = true
			messagesBox.WordWrap    = false
			messagesBox.ScrollBars  = messagesBox.ScrollBars.Both

			messagesBox.BackColor   = MAXLancer.GetNetColorMan #window
			messagesBox.ForeColor   = MAXLancer.GetNetColorMan #windowText

			resize (GetDialogSize FindResourcesRollout)
		)
	)
	
	on execute do if MAXLancer != undefined then CreateDialog FindResourcesRollout style:#(#style_titlebar, #style_border, #style_sysmenu, #style_resizing) else messageBox "MAXLancer is not initialized."
)