/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Painting tool to generate curved planes for starsphere mesh.
 */
macroscript StarscapePainter category:"MAXLancer" tooltip:"Starscape Painter" buttontext:"Starscape Painter" iconName:"MAXLancer/starscape_painter" (

	local enabled = false

	-- Create array of offset vectors for texure atlas given size and bitmask of excluded tiles
	fn GetAtlasOffsets size exclusions:#{} = for i = 0 to size * size - 1 where findItem exclusions (i + 1) == 0 collect [mod i size, i / size, 0] / size

	-- Input vector need to be in [-1, 1] range
	fn SpherifyVector v = (
		local dv = v * v
			
		local x = v.x * sqrt (1 - dv.y * 0.5 - dv.z * 0.5 + dv.y * dv.z / 3)
		local y = v.y * sqrt (1 - dv.z * 0.5 - dv.x * 0.5 + dv.z * dv.x / 3)
		local z = v.z * sqrt (1 - dv.x * 0.5 - dv.y * 0.5 + dv.x * dv.y / 3)
			
		[x, y, z]
	)
	
	fn GetPointOnSphere radius position &worldPos &worldDir = (
		local inverseViewTM = inverse (getViewTM())
		local viewPosition  = mapScreenToView position -radius
		
		worldPos = normalize (viewPosition * inverseViewTM - inverseViewTM.translation) * radius + inverseViewTM.translation
		worldDir = normalize (worldPos - inverseViewTM.translation)
		Ok
	)
	
	rollout StarscapePainterRollout "Starscape Painter" width:208 height:432 (
		local brushGridDivisor -- atlasSizeButtons.state
		local brushGridOffset  -- Point3 UV map offset
		local brushColor       -- random colorPrimaryPicker.color colorSecondaryPicker.color
		local brushAngle
		local brush
		local layer
		
		groupBox planeGroupBox "Plane Settings" pos:[8,7] width:192 height:297 align:#left
		
		label distanceLabel "Distance" pos:[16,24] width:88 height:16 align:#left
		spinner distanceSpinner "" pos:[104,24] width:88 height:16 range:[0,1000,100] type:#float align:#left
		
		label segmentsLabel "Segments" pos:[16,44] width:88 height:16 align:#left
		spinner segmentsSpinner "" pos:[104,44] width:88 height:16 range:[1,8,4] type:#integer align:#left
				
		slider sizeSlider "Size" pos:[16,64] width:187 height:44 range:[0, 1, 0.25] type:#float align:#left

		checkbox curveCheckbox "Curved Plane" pos:[16,112] width:88 height:16 checked:true align:#left
		checkbox randomRotationCheckbox "Random Rotate" pos:[104,112] width:88 height:16 checked:true align:#left
		checkbox flipNormals "Flip Normals" pos:[16,132] width:88 height:16 checked:true across:2 align:#left
		checkbox vertexColorCheckbox "Vertex Color" pos:[104,132] width:88 height:16 checked:true align:#left

		colorPicker colorPrimaryPicker "" pos:[16,160] width:88 height:20 color:white alpha:true across:2 align:#left
		colorPicker colorSecondaryPicker "" pos:[104,160] width:88 height:20 color:white alpha:true align:#left
			
		radiobuttons atlasGridSizeButtons "Texture Atlas Grid Size:" pos:[24,188] width:160 height:46 labels:#("1x1", "2x2", "3x3", "4x4", "5x5", "6x6", "7x7", "8x8") default:2 columns:4 align:#left

		button paintButton "Paint Planes" pos:[16,240] width:88 height:24 across:2 align:#left
		button newLayerButton "New Layer" pos:[104,240] width:88 height:24 align:#left
		button resetViewportButton "Reset Viewport" pos:[32,272] width:144 height:24 align:#left
			
		groupBox generatorGroupBox "Random Generator" pos:[8,312] width:192 height:112 align:#left

		label countLabel "Count" pos:[16,328] width:88 height:16 align:#left
		spinner countSpinner "" pos:[104,328] width:88 height:16 range:[1,1000,40] type:#integer align:#left
		
		label sizeVarianceLabel "Size Variance" pos:[16,348] width:88 height:16 align:#left	
		spinner sizeVarianceSpinner "" pos:[104,348] width:88 height:16 range:[0, 1, 0] type:#float align:#left

		label distanceIncrementLabel "Distance Add" pos:[16,368] width:88 height:16 align:#left	
		spinner distanceIncrementSpinner "" pos:[104,368] width:88 height:16 range:[0, 1000, 0] type:#float align:#left

		button generateButton "Generate" pos:[32,392] width:144 height:24 align:#left

		on newLayerButton pressed do layer = undefined
		
		on resetViewportButton pressed do (
			viewport.SetFOV 90
			viewport.SetTM (rotateXMatrix -90)
		)
		
		-- Align object to sphere surface around view at specified radius and screen pixel position
		fn AlignBrush = (
			if isValidNode brush then (
				GetPointOnSphere distanceSpinner.value mouse.pos &brush.pos &brush.dir
				if randomRotationCheckbox.checked then in coordsys local rotate brush (eulerAngles 0 0 brushAngle)				
			)
		)
		
		-- Generate next random Z axis rotation angle
		fn RollAngle = brushAngle = random 0 360

		-- Generate next random color
		fn RollColor = brushColor = (
			local result = black

			result.v = random colorPrimaryPicker.color.v colorSecondaryPicker.color.v
			result.s = random colorPrimaryPicker.color.s colorSecondaryPicker.color.s
			result.h = random colorPrimaryPicker.color.h colorSecondaryPicker.color.h

			result -- Return Color
		)
		
		-- Generate next random UV offset
		fn RollOffset = (
			local offsets = GetAtlasOffsets atlasGridSizeButtons.state
			
			brushGridOffset  = offsets[random 1 offsets.count]
			brushGridDivisor = atlasGridSizeButtons.state
		)
		
		-- Remove brush node
		fn ClearBrush = if isValidNode brush then delete brush
			
		-- Apply texture coords
		fn ApplyBrushOffset divisor:brushGridDivisor offset:brushGridOffset = (
			if isValidNode brush then (
				for v = 1 to meshOp.getNumMapVerts brush 1 do meshOp.setMapVert brush 1 v (meshOp.getMapVert brush 2 v / divisor + offset)
			)
		)
		
		-- Apply vertex colors and alpha
		fn ApplyBrushColor vColor:brushColor = (
			if isValidNode brush then (
				meshop.setMapSupport brush -2 true
				meshop.setMapSupport brush 0 true
				
				local alphaNumVerts = meshOp.getNumMapVerts brush -2
				local colorNumVerts = meshOp.getNumMapVerts brush 0
				
				meshOp.setVertColor brush 0 #{1..colorNumVerts} vColor
				meshOp.setVertAlpha brush -2 #{1..alphaNumVerts} (vColor.a / 255)
			)
		)
		
		fn MakeBrush size:sizeSlider.value multiplier:distanceSpinner.value = (
			size *= 2
			
			local prefab = (createInstance Plane length:size width:size lengthSegs:segmentsSpinner.value widthSegs:segmentsSpinner.value).mesh
			
			-- Apply curvature
			if curveCheckbox.checked and segmentsSpinner.value > 1 then
				for v = 1 to prefab.verts.count do prefab.verts[v].pos = SpherifyVector (prefab.verts[v].pos + [0, 0, 1]) + [0, 0, -1]
			
			scale prefab ([1, 1, 1] * multiplier)
			
			if brushAngle == undefined then RollAngle()
			
			brush = mesh mesh:prefab material:(medit.GetCurMtl())
				
			if flipNormals.checked do meshOp.flipNormals brush #all
			
			-- UV2 stores original UV
			meshop.setNumMaps brush 4 keep:true
			meshop.setMapSupport brush 2 true
			meshop.setNumMapVerts brush 2 (meshop.getNumMapVerts brush 1)
			for v = 1 to meshOp.getNumMapVerts brush 1 do meshOp.setMapVert brush 2 v (meshOp.getMapVert brush 1 v)

			if brushColor == undefined then RollColor()
			if brushGridOffset == undefined or brushGridDivisor == undefined then RollOffset()
			
			ApplyBrushOffset()
			if vertexColorCheckbox.checked then ApplyBrushColor()
			
			OK
		)
		
		on distanceSpinner buttonup do ClearBrush()
		on sizeSlider buttonup do ClearBrush()
		on segmentsSpinner buttonup do ClearBrush()
		on flipNormals changed state do ClearBrush()
		on atlasGridSizeButtons changed state do (
			RollOffset()
			ClearBrush()
		)
		
		on colorPrimaryPicker changed colorA do (
			RollColor()
			ApplyBrushColor()
		)
		
		on colorPrimarySecondary changed colorB do (
			RollColor()
			ApplyBrushColor()
		)
		
		tool PlanePainter (
			on start do (
				-- Not used but necessary to prevent tool from cancelling at mousePoint when isCPEdgeOnInView() evaluates to true
				activeGrid = grid displayPlane:0 transform:(transMatrix [0, 0, -distanceSpinner.value] * inverse (getViewTM())) isHidden:true
			)
			
			on freeMove do (
				if not isValidNode brush then MakeBrush()
				AlignBrush() -- AlignToSphere brush distanceSpinner.value viewPoint
			)
			
			-- clickNum is number of click
			on mousePoint clickNum do (
				if ctrlKey then (
					RollOffset()
					ApplyBrushOffset()
					update brush
				)
				
				if shiftKey then (
					RollColor()
					ApplyBrushColor()
					update brush
				)
				
				if altKey then (
					RollAngle()
					AlignBrush()
				) 
				
				if not (ctrlKey or shiftKey or altKey) then (
					if isValidNode brush then (
						if not isValidNode layer then layer = brush else meshOp.attach layer brush attachMat:#MatToID
							
						RollAngle()
						RollOffset()
						RollColor()
					)

					brush = undefined
				)
			)
			
			on mouseMove clickNum do (
				if not isValidNode brush then MakeBrush()
				AlignBrush() -- AlignToSphere brush distanceSpinner.value viewPoint
				
				-- if lButton then 
			)
			
			on stop do (
				if isValidNode activeGrid then delete activeGrid
				if isValidNode layer then layer.pivot = (inverse (getViewTM())).translation	
				
				ClearBrush()
			)
		)
		
		on paintButton pressed do if viewport.IsPerspView() then startTool PlanePainter else messageBox "Paint tool requires perspective projection viewport selected."
			
		on generateButton pressed do (
			layer = undefined -- Draw on new layer
			
			local sizeMin = sizeSlider.value - sizeVarianceSpinner.value
			local sizeMax = sizeSlider.value + sizeVarianceSpinner.value
			local dist = distanceSpinner.value

			if sizeMin < sizeSlider.range.x then sizeMin = sizeSlider.range.x
			if sizeMax > sizeSlider.range.y then sizeMax = sizeSlider.range.y
			
			for i = 1 to countSpinner.value do (
				RollAngle()
				RollOffset()
				RollColor()
				MakeBrush size:(random sizeMin sizeMax) multiplier:dist
				
				-- Set random rotation
				rotate brush (random (eulerAngles 0 0 0) (eulerAngles 360 360 360))
					
				-- Push away by radius
				in coordsys local move brush [0, 0, dist]
				
				-- Assign to layer or attach to existing layer
				if not isValidNode layer then layer = brush else meshOp.attach layer brush attachMat:#MatToID

				dist += distanceIncrementSpinner.value
			)
			
			OK
		)

		on StarscapePainterRollout open do (
			enabled = true
			updateToolbarButtons()
			if MAXLancer != undefined then MAXLancer.config.LoadRollout StarscapePainterRollout
		)

		on StarscapePainterRollout close do (
			enabled = false
			updateToolbarButtons()
			if MAXLancer != undefined then MAXLancer.config.SaveRollout StarscapePainterRollout
		)
	)

	on execute do CreateDialog StarscapePainterRollout

	on isChecked do enabled

	on closeDialogs do DestroyDialog StarscapePainterRollout	
)