/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Copy select objects into clipboard as THN formatted string of entries
 */
macroscript ThornTools category:"MAXLancer" tooltip:"Thorn Tools" buttontext:"Thorn Tools" iconName:"MAXLancer/toolbar" (
	global MAXLancer
	
	rollout ThornToolsRollout "Thorn Tools" width:220 height:340 (
		
		local writer -- ThornWriter
		
		group "Indentation Settings" (
			checkbox indentTab "Use tab" tooltip:"Indent with tabs" checked:true across:2
			spinner indentSpace "Spaces:" tooltip:"Indent with spaces" type:#integer range:[0, 8, 4] enabled:(not indentTab.checked)
		)
		
		group "Spatial Properties" (
			button entitiesButton "Entities" width:80 height:24 align:#right across:2 \
				tooltip:"Copies position and orientation (as matrix) of selected objects as entities list into Windows clipboard buffer."
			
			button spatialPropAnimButton "Keyframe" width:80 height:24 align:#left \
				tooltip:"Copies position and orientation (as quaternion) of selected objects as spatialprops animation into Windows clipboard (for START_SPATIAL_PROP_ANIM)."
			
		)

		group "Capture Motion Path" (
			pickbutton pathCaptureTarget "Pick object" width:120 height:24 autoDisplay:true
			
			spinner pathTimeStart "Start:" range:[-3.4e38, 3.4e38, animationRange.start] tooltip:"Capture range start time." fieldWidth:56 align:#right across:2
			button pathTimeStartCurrentButton "Current" tooltip:"Set capture start time to animation track current position." height:16 width:80 align:#center
			
			spinner pathTimeEnd "End:" range:[-3.4e38, 3.4e38, animationRange.end] tooltip:"Capture range end time." fieldWidth:56 align:#right across:2
			button pathTimeEndCurrentButton "Current" tooltip:"Set capture end time to animation track current position." height:16 width:80 align:#center
			
			spinner pathRate "Rate:" range:[1, 200, frameRate] tooltip:"Sample period. The larger the value the less keyframes are samples." fieldWidth:56 align:#right across:2
			button pathRateFramesButton "Frame rate" tooltip:"Set sample period to current frame rate." height:16 width:80 align:#center
			
			button pathsCopyButton "Copy to Clipboard" width:120 height:24 enabled:(pathCaptureTarget.object != undefined)
			label pathsStatus "" width:180 align:#center
		)

		label copyText "" width:120 align:#left
		
		on pathCaptureTarget rightclick do (
			pathCaptureTarget.object = undefined
			pathsCopyButton.enabled = false
		)
		
		on pathCaptureTarget picked target do (
			pathsCopyButton.enabled = true
		)
		
		on pathTimeStartCurrentButton pressed do pathTimeStart.value = currentTime
		on pathTimeEndCurrentButton pressed do pathTimeEnd.value = currentTime
		on pathRateFramesButton pressed do pathRate.value = frameRate
		
		fn WriteTargetNameType name type = (
			writer.WriteProperty "entity_name" name
			writer.WriteProperty "type" type
			OK
		)
		
		-- Write spatial properties
		fn WriteSpatialProps tm qOrient:false = (
			writer.StartArray key:"spatialprops" -- Start spatialprops
			
			writer.WriteProperty "pos" tm.row4
			if qOrient then writer.WriteProperty "q_orient" (inverse tm.rotationpart) else writer.WriteProperty "orient" tm
				
			writer.EndArray() -- End spatialprops
			OK
		)
		
		-- Write motion path from target node at given time interval and stepping frequency
		fn WriteMotionPath target range frequency closed:false = (

			local offset = at time range.start target.transform.translationpart
			
			writer.StartArray() -- Start entity for motion_path
			
			WriteTargetNameType (target.name + "_path") #motion_path
			WriteSpatialProps (transMatrix offset)
			
			writer.StartArray key:"pathprops" -- Start pathprops
			
				writer.WriteProperty "path_type" "CV_CROrientationSplinePath" -- "CV_CRSplinePath"
			
				local pathStream = StringStream ""
				local cameraRotate = quat 90 [1, 0, 0]
			
				append pathStream (if closed then "CLOSED" else "OPEN")
			
				local count = 0
				local previous = quat 1
				local multiplier = 1
			
				for t = range.start to range.end by frequency do at time t (
					local position = target.transform.translationpart - offset
					local orientation = if superClassOf target == Camera then inverse (cameraRotate * target.transform.rotationpart) else inverse target.transform.rotationpart
					
					-- Quaternion fix for exporting
					if (orientation - previous).w < 0 then multiplier *= -1
					previous = orientation
					orientation *= multiplier
					
					format ", {%, %, %}, {%, %, %, %}" position.x position.z -position.y orientation.w orientation.x orientation.z -orientation.y to:pathStream
					count += 1
				)
			
				writer.WriteProperty "path_data" (pathStream as String)
			
			writer.EndArray() -- End pathprops
			writer.EndArray() -- End entity for motion_path
			OK
		)	
		
		on indentTab changed status do indentSpace.enabled = not status
			
		on spatialPropAnimButton pressed do if selection.count > 0 then (
			writer = MAXLancer.CreateThornWriter()
			writer.padding = if indentTab.checked then "\t" else formattedPrint "" format:(" " + (indentSpace.value as String) + "s")
				
			WriteSpatialProps selection[1].transform qOrient:true
			writer.CopyToClipboard()				
		)
			
		on entitiesButton pressed do if selection.count > 0 then (
			writer = MAXLancer.CreateThornWriter()
			writer.padding = if indentTab.checked then "\t" else formattedPrint "" format:(" " + (indentSpace.value as String) + "s")
				
			if selection.count > 1 then writer.StartArray key:"entities" -- Start entities
			
			for target in selection do (
				writer.StartArray() -- Start entity
				
				WriteTargetNameType target.name #marker
				WriteSpatialProps target.transform qOrient:false
				
				writer.EndArray() -- End entity
			)
			
			if selection.count > 1 then writer.EndArray() -- End entities
			
			writer.CopyToClipboard()
			OK
		) else messageBox "Select objects to parse into THN" beep:false
		
		on pathsCopyButton pressed do if pathTimeEnd.value < pathTimeStart.value then messageBox "Invalid time range selected" beep:false
		else (
			writer = MAXLancer.CreateThornWriter()
			writer.padding = if indentTab.checked then "\t" else formattedPrint "" format:(" " + (indentSpace.value as String) + "s")
			WriteMotionPath pathCaptureTarget.object (interval pathTimeStart.value pathTimeEnd.value) pathRate.value
			writer.CopyToClipboard()
		)
	)

	on execute do if MAXLancer != undefined then CreateDialog ThornToolsRollout else messageBox "MAXLancer is not initialized."
)