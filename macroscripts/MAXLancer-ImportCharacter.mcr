/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Import deformable character model
 */
macroscript ImportCharacter category:"MAXLancer" tooltip:"Import Character" buttontext:"Import Character" iconName:"MAXLancer/import_models" (
	global MAXLancer

	rollout ImportCharacterRollout "Import Character" width:384 height:184 (
		local materialLib -- FLMaterialLibrary
		local textureLib  -- FLTextureLibrary

		local root      -- Bone
		local body      -- DeformableCompound
		local head      -- DeformableCompound
		local leftHand  -- DeformableCompound
		local rightHand -- DeformableCompound

		local faceCount     = 0
		local progressCount = 0

		button loadBodyButton "Load Body" pos:[8,8] width:120 height:24
		editText bodyFilename "" pos:[136,12] width:240 height:16 readOnly:true

		button loadHeadButton "Load Head" pos:[8,40] width:120 height:24 enabled:false
		editText headFilename "" pos:[136,44] width:240 height:16 readOnly:true

		button loadLeftHandButton "Load Left Hand" pos:[8,72] width:120 height:24 enabled:false
		editText leftHandFilename "" pos:[136,76] width:240 height:16 readOnly:true

		button loadRightHandButton "Load Right Hand" pos:[8,104] width:120 height:24 enabled:false
		editText rightHandFilename "" pos:[136,108] width:240 height:16 readOnly:true

		spinner scaleSpinner "Scale:" pos:[8,140] range:[1, 3.4e38, 1] fieldWidth:80 height:16

		button buildButton "Build Character" pos:[216,136] width:160 height:24 enabled:false align:#left
		progressBar buildProgress "" pos:[8,168] width:368 height:8
		
		fn LoadPart caption = (
			local filename = getOpenFileName caption:caption types:"Deformable Model (.dfm)|*.dfm|"
			if filename != undefined then MAXLancer.LoadDeformableModel filename materialLib:materialLib textureLib:textureLib
		)
		
		on loadBodyButton pressed do (
			body = LoadPart "Select Body Model:"
			bodyFilename.text = body.filename
			
			if body != undefined then (

				loadHeadButton.enabled = body.GetHardpoint "hp_neck" != undefined and body.GetHardpoint "hp_head" != undefined
				loadLeftHandButton.enabled = body.GetHardpoint "hp_left a" != undefined and body.GetHardpoint "hp_left b" != undefined
				loadRightHandButton.enabled = body.GetHardpoint "hp_right a" != undefined and body.GetHardpoint "hp_right b" != undefined

				buildButton.enabled = true
			) else buildButton.enabled = false
		)

		on loadHeadButton pressed do (
			head = LoadPart "Select Head Model:"
			headFilename.text = head.filename
		)

		on loadLeftHandButton pressed do (
			leftHand = LoadPart "Select Left Hand Model:"
			leftHandFilename.text = leftHand.filename
		)

		on loadRightHandButton pressed do (
			rightHand = LoadPart "Select Left Hand Model:"
			rightHandFilename.text = rightHand.filename
		)
			
		fn ProgressCallback count = (
			buildProgress.value = (progressCount += count) * 100.0 / faceCount
			windows.processPostedMessages()
		)

		on buildButton pressed do try (
			progressCount = buildProgress.value = 0

			local start = timeStamp()
			
			-- Count faces for progress bar
			faceCount = body.GetFaceCount()
			if head != undefined then      faceCount += head.GetFaceCount()
			if leftHand != undefined then  faceCount += leftHand.GetFaceCount()
			if rightHand != undefined then faceCount += rightHand.GetFaceCount()
			
			local resultName = getFilenameFile body.filename
			if head != undefined then resultName += "_" + getFilenameFile head.filename

			local size = scaleSpinner.value
			local result = point name:resultName size:1 box:false cross:true axistripod:false centermarker:false scale:[size, size, size] isSelected:true

			root = body.BuildCostume head leftHand rightHand materialLib:materialLib textureLib:textureLib progress:ProgressCallback
			root.parent = result

			select result
			DestroyDialog ImportCharacterRollout
			gc light:false
			messageBox ("Character imported in " + formattedPrint (0.001 * (timeStamp() - start)) format:".2f" + " seconds") beep:false
		) catch (
			DestroyDialog ImportCharacterRollout
			messageBox (getCurrentException())
			throw()
		)
		
		on ImportCharacterRollout open do (
			materialLib = MAXLancer.CreateMaterialLibrary()
			textureLib  = MAXLancer.CreateTextureLibrary()
			OK
		)
	)

	on execute do if MAXLancer != undefined then CreateDialog ImportCharacterRollout else messageBox "MAXLancer is not initialized."
)