macroscript BatchHardpoints category:"MAXLancer" tooltip:"Batch Hardpoints" buttontext:"Batch Hardpoints" iconName:"MAXLancer/export_models" (
	global MAXLancer

	fn GetPathTo target caption = (
		local filepath = getSavePath initialDir:target.text caption:caption
		if filepath != undefined then target.text = filepath
		OK
	)

	rollout BatchHardpointsRollout "Batch Hardpoints" width:600 height:500 (

		edittext pathInput "" fieldWidth:272 labelOnTop:true
		button pathBrowse "Browse" width:80 height:18 align:#right offset:[0, -24]
		
		edittext hardpointInput "" fieldWidth:272 labelOnTop:true text:"HpOrigin"

		dotNetControl messagesBox "System.Windows.Forms.Textbox" pos:[0,0] align:#left
		dotNetControl searchProgress "System.Windows.Forms.ProgressBar" pos:[8, 0] height:8 align:#left

		button processButton "Process" width:106 height:18

		fn WriteLine input = messagesBox.AppendText (input as string + "\r\n")

		fn resize size = (
			pathInput.pos.x = 8
			pathInput.pos.y = 8
			pathInput.width = size.x - 128
			
			pathBrowse.pos.x = size.x - 112
			pathBrowse.pos.y = 8
			pathBrowse.width = 106
			
			hardpointInput.pos.x = 8
			hardpointInput.pos.y = 32
			hardpointInput.width = size.x - 128
			
			processButton.pos.x = size.x - 112
			processButton.pos.y = 32
			
			messagesBox.pos.x = 8
			messagesBox.pos.y = 56
			messagesBox.width = size.x - 16
			messagesBox.height = size.y - messagesBox.pos.y - 20
			
			searchProgress.pos.x = 8
			searchProgress.pos.y = size.y - 16
			searchProgress.width = size.x - 16
		)

		on BatchHardpointsRollout resized size do resize size
			
		on BatchHardpointsRollout open do (
			messagesBox.Font       = logFont
			messagesBox.ReadOnly   = true
			messagesBox.MultiLine  = true
			messagesBox.WordWrap   = false
			messagesBox.ScrollBars = messagesBox.ScrollBars.Both

			messagesBox.BackColor  = MAXLancer.GetNetColorMan #window
			messagesBox.ForeColor  = MAXLancer.GetNetColorMan #windowText

			resize (GetDialogSize BatchHardpointsRollout)
		)

		on pathBrowse pressed do (
			GetPathTo pathInput "Models path"
		)

		on processButton pressed do (
			messagesBox.Clear()

			local files = MAXLancer.FilterFiles pathInput.text recursive:true directoryMask:"*" fileMasks:#("*.3db", "*.cmp")
			local model        -- RigidPart/RigidCompound
			local meshLib      -- VMeshLibrary
			local materialLib  -- FLMaterialLibrary
			local textureLib   -- FLTextureLibrary
			local animationLib -- AnimationLibrary

			WriteLine ("Processing " + files.count as string + " files")
			
			searchProgress.Minimum = searchProgress.Value = 0
			searchProgress.Maximum = files.count
			searchProgress.Step = 1

			local reader -- UTFReader
			local writer -- UTFWriter
			
			local safeToWrite = false
			local root -- RigidPart
			local origin

			for filename in files do (

				safeToWrite = false

				try (
					WriteLine ("Reading " + filename)

					reader = MAXLancer.CreateUTFReader()
					reader.Open filename

					-- Detect model type instead of relying on file extension
					model = if reader.OpenFolder "Cmpnd" then MAXLancer.CreateRigidCompound() else MAXLancer.CreateRigidPart()
					model.ReadUTF reader

					-- Initialize libraries
					meshLib      = MAXLancer.CreateVMeshLibrary()
					materialLib  = MAXLancer.CreateMaterialLibrary()
					textureLib   = MAXLancer.CreateTextureLibrary()
					animationLib = MAXLancer.CreateAnimationLibrary()

					meshLib.ReadUTF reader
					materialLib.ReadUTF reader
					textureLib.ReadUTF reader
					animationLib.ReadUTF reader

					reader.Close()
					safeToWrite = true

				) catch (
					WriteLine ("ERROR (" + filename + "): " + getCurrentException())
					reader.Close()
				)

				if safeToWrite then (
					try (
						if MAXLancer.IsRigidCompound model then root = model.root else root = model
						
						if MAXLancer.IsRigidPart root then (
							origin = root.addHardpoint hardpointInput.text type:#fixed
						)
						
						WriteLine ("Writing " + filename)

						writer = MAXLancer.CreateUTFWriter()
						writer.Open filename

						meshLib.WriteUTF writer
						animationLib.WriteUTF writer
						materialLib.WriteUTF writer
						textureLib.WriteUTF writer

						writer.Reset()
						writer.WriteFileString "Exporter Version" MAXLancer.exporterVersion

						model.WriteUTF writer timestamps:true

						writer.Close()
					) catch (
						WriteLine ("ERROR (" + filename + "): " + getCurrentException())
						writer.Close()
					)
				)
				
				windows.processPostedMessages()
				searchProgress.PerformStep()
			)
		)
	)

	on execute do if MAXLancer != undefined then CreateDialog BatchHardpointsRollout style:#(#style_titlebar, #style_border, #style_sysmenu, #style_resizing) else messageBox "MAXLancer is not initialized."
)