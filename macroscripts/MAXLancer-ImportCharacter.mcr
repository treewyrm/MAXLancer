/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Import deformable character model
 */
macroscript ImportCharacter category:"MAXLancer" tooltip:"Import Character" buttontext:"Import Character" iconName:"MAXLancer/import_models" (
	global MAXLancer

	rollout ImportCharacterRollout "Import Character" width:136 height:184 (
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
		button loadHeadButton "Load Head" pos:[8,40] width:120 height:24 enabled:false
		button loadLeftHandButton "Load Left Hand" pos:[8,72] width:120 height:24 enabled:false
		button loadRightHandButton "Load Right Hand" pos:[8,104] width:120 height:24 enabled:false
		button buildButton "Build Character" pos:[8,136] width:120 height:24 enabled:false
		progressBar buildProgress "" pos:[8,168] width:120 height:8
		
		fn LoadPart caption = (
			local filename = getOpenFileName caption:caption types:"Deformable Model (.dfm)|*.dfm|"
			if filename != undefined then MAXLancer.LoadDeformableModel filename materialLib:materialLib textureLib:textureLib
		)
		
		on loadBodyButton pressed do (
			body = LoadPart "Select Body Model:"
			
			if body != undefined then (

				loadHeadButton.enabled = body.GetHardpoint "hp_neck" != undefined and body.GetHardpoint "hp_head" != undefined
				loadLeftHandButton.enabled = body.GetHardpoint "hp_left a" != undefined and body.GetHardpoint "hp_left b" != undefined
				loadRightHandButton.enabled = body.GetHardpoint "hp_right a" != undefined and body.GetHardpoint "hp_right b" != undefined

				buildButton.enabled = true
			) else buildButton.enabled = false
		)

		on loadHeadButton pressed do      head      = LoadPart "Select Head Model:"
		on loadLeftHandButton pressed do  leftHand  = LoadPart "Select Left Hand Model:"
		on loadRightHandButton pressed do rightHand = LoadPart "Select Left Hand Model:"
			
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
			
			root = body.BuildCostume head leftHand rightHand materialLib:materialLib textureLib:textureLib progress:ProgressCallback

			select root
			DestroyDialog ImportCharacterRollout
			gc light:false
			messageBox ("Character imported in " + formattedPrint (0.001 * (timeStamp() - start)) format:".2f" + " seconds")
		) catch (
			DestroyDialog ImportCharacterRollout
			messageBox (getCurrentException())
			throw()
		)
		
		on ImportCharacterRollout open do (
			materialLib = MAXLancer.FLMaterialLibrary()
			textureLib  = MAXLancer.FLTextureLibrary()
			OK
		)
	)

	on execute do if MAXLancer != undefined then CreateDialog ImportCharacterRollout else messageBox "MAXLancer is not initialized."
)