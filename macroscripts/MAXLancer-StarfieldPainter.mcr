/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Painting tool to generate triangle array mesh for starfield background.
 */
macroscript StarfieldPainter category:"MAXLancer" tooltip:"Starfield Painter" buttontext:"Starfield Painter" iconName:"MAXLancer/starfield_painter" (

	local enabled = false

	local triangleVertices    = for a = 0 to 240 by 120 collect [sin a, cos a, 0]
	local triangleCoordinates = for v in triangleVertices collect v * (rotateZMatrix 15) * 0.75 + [0.5, 0.5, 0]

	-- Create array of offset vectors for texure atlas given size and bitmask of excluded tiles
	fn GetAtlasOffsets size exclusions:#{} = for i = 0 to size * size - 1 where findItem exclusions (i + 1) == 0 collect [mod i size, i / size, 0] / size

	-- Convert string to bitArray
	fn StringToBitArray source = (
		local result = #{}
		local parts = filterString source ","
		
		for i = 1 to parts.count do (
			if matchPattern parts[i] pattern:"*..*" then (
				local range = filterString parts[i] ".."
				
				if range.count == 2 then (
					local minimum = range[1] as integer
					local maximum = range[2] as integer
					
					if classOf minimum == integer and classOf maximum == integer and minimum > 0 and maximum > 0 and maximum > minimum then
						result += #{minimum..maximum}
				)
			) else (
				local index = parts[i] as integer
				if classOf index == integer and index > 0 then result[index] = true
			)
		)

		result
	)

	fn ResetCamera = if viewport.IsPerspView() then (viewport.SetFOV 90; viewport.SetTM (rotateXMatrix -90))
	
	/*
	-- Get matrix of a point on sphere and rotation inwards
	fn GetScreenSphereTM radius screenPosition = (
		local inverseViewTM  = inverse (getViewTM())
		local viewPosition   = mapScreenToView screenPosition -radius
		local worldPosition  = normalize (viewPosition * inverseViewTM - inverseViewTM.translation) * radius + inverseViewTM.translation
		local worldDirection = normalize (worldPosition - inverseViewTM.translation)

		translate (MatrixFromNormal worldDirection) worldPosition
	)
	*/
	
	-- Same as above but with dispersion angle
	fn GetScreenSphereTM radius screenPosition dispersionAngle:0 = (
		local localTM = transMatrix [0, 0, radius]

		if dispersionAngle > 0 then rotateX localTM (random 0 dispersionAngle)
		rotateZ localTM (random 0 360)
		
		local inverseViewTM  = inverse (getViewTM())		
		local localPosition  = normalize (mapScreenToView screenPosition -radius) * radius
		local worldDirection = normalize (localPosition * inverseViewTM - inverseViewTM.translation)
		
		translate (localTM * (MatrixFromNormal worldDirection)) inverseViewTM.translation
	)

	rollout StarfieldPainterRollout "Starfield Painter" width:192 height:264
	(
		local textureGridOffsets
		local textureGridSize

		label distanceLabel "Paint Distance" pos:[8,8] width:88 height:16 align:#left
		spinner distanceSpinner "" pos:[96,8] width:88 height:16 range:[0,1000,100] type:#float align:#left
		
		label scaleLabel "Star Sprite Scale" pos:[8,28] width:88 height:16 align:#left
		spinner scaleSpinner "" pos:[96,28] width:88 height:16 range:[0,100,0.75] type:#float align:#left

		label dispersionLabel "Dispersion Angle" pos:[8,48] width:88 height:16 align:#left
		spinner dispersionSpinner "" pos:[96,48] width:88 height:16 range:[0,180,0] type:#float align:#left

		label separationLabel "Min Distance" pos:[8,68] width:88 height:16 align:#left
		spinner separationSpinner "" pos:[96,68] width:88 height:16 range:[0,100,1.5] type:#float align:#left
		
		groupBox atlasGroupBox "Texture Atlas" pos:[8,88] width:176 height:112 align:#left	
		radiobuttons atlasGridSizeButtons "Grid Size:" pos:[16,108] width:160 height:46 labels:#("1x1", "2x2", "3x3", "4x4", "5x5", "6x6", "7x7", "8x8") default:8 columns:4 align:#left
		label atlasGridExclusionLabel "Excluded IDs:" pos:[16,160] width:160 height:16 align:#left
		edittext atlasGridExclusionsEdit "" pos:[16,176] width:160 labelOnTop:true align:#left text:"1..8, 7, 15, 23, 31, 39, 47, 55, 63"
		
		pickbutton layerButton "Pick Mesh Layer" pos:[8, 208] width:176 height:24 align:#left autoDisplay:true
		
		button paintButton "Paint Stars" pos:[8,232] width:88 height:24 align:#left
		button resetCameraButton "Reset Camera" pos:[96,232] width:88 height:24 align:#left
		
		on resetCameraButton pressed do ResetCamera()
		
		on layerButton rightclick do layerButton.object = undefined
		
		fn paintStar screenPosition dispersionAngle:(dispersionSpinner.value) = (
			local inverseViewTM  = inverse (getViewTM())
			local sphereTM       = GetScreenSphereTM distanceSpinner.value screenPosition dispersionAngle:dispersionAngle
			local allowPlacement = true
			local layer          = layerButton.object

			-- Ensure min distance to every other triangle
			if isValidNode layer then
				if getNumVerts layer >= 12288 then allowPlacement = false else
				if separationSpinner.value > 0 then
					for f = getNumFaces layer to 1 by -1 while allowPlacement where distance (meshOp.getFaceCenter layer f) sphereTM.translation <= separationSpinner.value do allowPlacement = false
					
			if allowPlacement then (
				local result = mesh vertices:triangleVertices faces:#([1, 2, 3]) material:(medit.GetCurMtl()) \
					transform:sphereTM pivot:inverseViewTM.translation

				in coordsys local scale result.mesh ([1, 1, 1] * scaleSpinner.value)
				in coordsys local rotate result.mesh (EulerAngles 0 0 (random 0 360))

				-- Apply texture grid divisor and offset				
				local offset = textureGridOffsets[random 1 textureGridOffsets.count]
				meshop.setMapSupport result 1 true
					
				for i = 1 to 3 do meshOp.setMapVert result 1 i (triangleCoordinates[i] / textureGridSize + offset)
				
				-- Attach to layer or make result a layer
				if not isValidNode layer then layerButton.object = result else meshOp.attach layer result
			)
			
			OK
		)

		fn eraseStar screenPosition = (
			local layer = layerButton.object
			
			if isValidNode layer then (
				local sphereTM = GetScreenSphereTM distanceSpinner.value screenPosition
				local faces    = #{}

				for f = getNumFaces layer to 1 by -1 where distance (meshOp.getFaceCenter layer f) sphereTM.translation <= separationSpinner.value do faces[f] = true

				if faces.numberSet > 0 then (
					meshOp.deleteFaces layer faces
					update layer
				)
			)
		)
		
		tool StarPainter prompt:"Draw stars" (
			local previousGrid
			local painterGrid
			
			on freeMove do redrawViews()
			
			on start do (
				previousGrid = activeGrid

				-- Not used but necessary to prevent tool from cancelling at mousePoint when isCPEdgeOnInView() evaluates to true
				activeGrid = painterGrid = grid displayPlane:0 transform:(transMatrix [0, 0, -distanceSpinner.value] * inverse (getViewTM())) isHidden:true
			)

			/*
			on mousePoint clickNum do (
				if not shiftKey and (clickNum == 1 or clickNum > 2) then paintStar viewPoint
			)
			*/
			
			on mouseMove clickNum do if lButton then 
				if shiftKey then eraseStar viewPoint else paintStar viewPoint
			
			on stop do (
				activeGrid = previousGrid
				if isValidNode painterGrid then delete painterGrid
			)
		)
		
		on paintButton pressed do if viewport.IsPerspView() then (
			textureGridSize    = atlasGridSizeButtons.state
			textureGridOffsets = GetAtlasOffsets textureGridSize exclusions:(StringToBitArray atlasGridExclusionsEdit.text)
			
			startTool StarPainter
		) else messageBox "Paint tool requires perspective projection viewport selected."

		on StarfieldPainterRollout open do (
			enabled = true
			updateToolbarButtons()
			if MAXLancer != undefined then MAXLancer.config.LoadRollout StarfieldPainterRollout
		)

		on StarfieldPainterRollout close do (
			enabled = false
			updateToolbarButtons()
			if MAXLancer != undefined then MAXLancer.config.SaveRollout StarfieldPainterRollout
		)
	)
	
	on execute do CreateDialog StarfieldPainterRollout

	on isChecked do enabled

	on closeDialogs do DestroyDialog StarfieldPainterRollout
)