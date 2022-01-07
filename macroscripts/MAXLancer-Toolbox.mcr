macroScript Toolbox category:"MAXLancer" tooltip:"MAXLancer Panel" buttontext:"MAXLancer Panel" iconName:"MAXLancer/toolbar" (
	global MAXLancer

	local toolboxFloater      -- RolloutFloater
	local toolboxOpen = false

	-- Apply property to MAXLancer instance and save into configuration file
	fn ApplyProperty property value = (
		if hasProperty MAXLancer property then setProperty MAXLancer property value else throw ("Missing MAXLancer property: " + property as string)
		MAXLancer.config.SaveProperty "MAXLancer" (property as string) value
		OK
	)

	rollout GeneralRollout "General" (
		spinner hashDecimalSpinner "Export vertex precision:" range:[0,8,3] type:#integer

		fn Apply = (
			ApplyProperty #hashDecimal hashDecimalSpinner.value
		)

		on GeneralRollout open do (
			hashDecimalSpinner.value = MAXLancer.hashDecimal
		)
	)

	rollout AnimationRollout "Animation" (
		spinner samplingRateSpinner "Sampling rate (FPS):" range:[5,60,30] type:#integer
		spinner samplingThresholdSpinner "Sampling threshold:" range:[0, 100, 0] type:#float -- MAXLancer.animationSamplingThreshold
		checkbox overwriteCheckbox "Overwrite sampled controller" align:#center

		fn Apply = (
			ApplyProperty #animationSamplingRate      samplingRateSpinner.value
			ApplyProperty #animationSamplingThreshold samplingThresholdSpinner.value
			ApplyProperty #animationSamplingOverwrite overwriteCheckbox.checked
			OK
		)

		on AnimationRollout open do (
			samplingRateSpinner.value      = MAXLancer.animationSamplingRate
			samplingThresholdSpinner.value = MAXLancer.animationSamplingThreshold
			overwriteCheckbox.checked      = MAXLancer.animationSamplingOverwrite
		)
	)
	
	rollout HelpersRollout "Helpers" (
		label description "These sizes are applied to imported helpers."
		
		spinner partSizeSpinner "Model part size:" 
		spinner hardpointSizeSpinner "Hardpoint size size:"

		fn Apply = (
			ApplyProperty #partSize      partSizeSpinner.value
			ApplyProperty #hardpointSize hardpointSizeSpinner.value
			OK
		)

		on HelpersRollout open do (
			partSizeSpinner.value      = MAXLancer.partSize
			hardpointSizeSpinner.value = MAXLancer.hardpointSize
		)
	)
	
	rollout ExternalPathsRollout "External Paths" (
		edittext freelancerPathInput "Freelancer:" fieldWidth:272 labelOnTop:true
		button freelancerPathBrowse "Browse" width:80 height:20 align:#right offset:[0, -24]
		
		edittext texturesPathInput "Textures:" fieldWidth:272 labelOnTop:true
		button texturesPathBrowse "Browse" width:80 height:20 align:#right offset:[0, -24]
		
		edittext textureToolsPathInput "Nvidia Texture Tools:" fieldWidth:272 labelOnTop:true
		button textureToolsPathBrowse "Browse" width:80 height:20 align:#right offset:[0, -24]
		
		edittext shadersPathInput "Shader:" fieldWidth:272 labelOnTop:true
		button shadersPathBrowse "Browse" width:80 height:20 align:#right offset:[0, -24]

		fn GetPathTo target caption = (
			local filepath = getSavePath initialDir:target.text caption:caption
			if filepath != undefined then target.text = filepath
			OK
		)

		fn Apply = (
			ApplyProperty #freelancerPath   freelancerPathInput.text
			ApplyProperty #texturesPath     texturesPathInput.text
			ApplyProperty #textureToolsPath textureToolsPathInput.text
			ApplyProperty #shadersPath      shadersPathInput.text
			OK
		)

		on freelancerPathBrowse pressed do   GetPathTo freelancerPathInput   "Freelancer Folder:"
		on texturesPathBrowse pressed do     GetPathTo texturesPathInput     "Texture Folder:"
		on textureToolsPathBrowse pressed do GetPathTo textureToolsPathInput "Texture Tools Folder:"
		on shadersPathBrowse pressed do      GetPathTo shadersPathInput      "Shaders Folder:"

		on ExternalPathsRollout open do (
			freelancerPathInput.text   = MAXLancer.freelancerPath
			texturesPathInput.text     = MAXLancer.texturesPath
			textureToolsPathInput.text = MAXLancer.textureToolsPath
			shadersPathInput.text      = MAXLancer.shadersPath
		)
	)
	
	rollout MiscRollout "Misc" (
		radiobuttons convexGeneratorType "Convex hull generator" labels:#("Nvidia PhysX", "Internal QuickHull") default:1 columns:1
		edittext exporterVersionInput "Exporter version text:" labelOnTop:true
		
		fn Apply = (
			ApplyProperty #convexGenerator convexGeneratorType.state
			ApplyProperty #exporterVersion exporterVersionInput.text
		)

		on MiscRollout open do (
			convexGeneratorType.state = MAXLancer.convexGenerator
			exporterVersionInput.text = MAXLancer.exporterVersion		
		)
	)
	
	rollout SettingsRollout "Settings" width:416 height:448 (
		subRollout categories width:400 height:400 pos:[8, 8]
		button applyButton "Apply" width:120 height:24 pos:[160, 416]
		button cancelButton "Cancel" width:120 height:24 pos:[288, 416]
		
		on SettingsRollout open do (
			AddSubRollout categories GeneralRollout rolledUp:true
			AddSubRollout categories ExternalPathsRollout rolledUp:true
			AddSubRollout categories HelpersRollout rolledUp:true
			AddSubRollout categories AnimationRollout rolledUp:true
			AddSubRollout categories MiscRollout rolledUp:true
		)

		on applyButton pressed do (
			for roll in categories.rollouts do roll.Apply()

			if MAXLancer.Initialize() then (
				messageBox "Settings applied." beep:false
				DestroyDialog SettingsRollout
			)
		)

		on cancelButton pressed do DestroyDialog SettingsRollout
	)

	rollout ToolboxRollout "MAXLancer Tools" (
		button settingsButton "Settings"       width:128 height:24 align:#center
		button logButton      "Message Log"    width:128 height:24 align:#center
		button reloadButton   "Reload Scripts" width:128 height:24 align:#center

		label versionLabel "" width:128 align:#center

		on settingsButton pressed do (
			DestroyDialog SettingsRollout
			CreateDialog SettingsRollout
		)

		on logButton pressed do MAXLancer.ShowLog()

		on reloadButton pressed do (
			if queryBox "Reloading scripts can break motion controllers in active scene. Do you want to continue?" title:"Reloading MAXLancer scripts" beep:false then (
				macros.run "MAXLancer" "ReloadScripts"
				messageBox "MAXLancer scripts reloaded." beep:false
			)
		)

		on RigidModelsRollout close do (
			toolboxOpen = false
			updateToolbarButtons()
		)
		
		on ToolboxRollout open do (
			versionLabel.text = "Version " + MAXLancer.version as string
		)
	)
	
	rollout ModelToolsRollout "Model Tools" (
		group "Rescale Model" (
			spinner scaleSpinner "Scale Factor" type:#float range:[0.001, 1000, 1]
			button applyScaleButton "Apply" height:24 width:88 tooltip:"Rescale compound model with all sub-parts."
		)
		
		group "Flip UVs" (
			spinner mapSpinner "Map Channel" range:[1, 99, 1] type:#integer
			
			button flipUButton "Flip U" width:76 height:24 align:#left across:2 tooltip:"Flip U texture coordinate for map channel in selected editable meshes."
			button flipVButton "Flip V" width:76 height:24 align:#right tooltip:"Flip V texture coordinate for map channel in selected editable meshes."
		)
		
		fn ScaleMesh target multiplier = (
			in coordsys local for v = 1 to getNumVerts target do setVert target v (getVert target v * multiplier)
			update target

			target.pivot = ((target.pivot * inverse target.parent.transform) * multiplier) * target.parent.transform
			OK
		)

		fn ScaleShape target multiplier = (
			in coordsys local for s = 1 to numSplines target do for k = 1 to numKnots target s do setKnotPoint target s k (getKnotPoint target s k * multiplier)
			updateShape target 
			OK
		)

		mapped fn ScaleModel root multiplier = if MAXLancer.IsRigidPartHelper root and root.parent == undefined then (
			local queue = #(root), target, targetTM, offset
			
			while queue.count > 0 do (
				target = queue[queue.count]
				queue.count = queue.count - 1
				
				if classOf target == Editable_mesh then ScaleMesh target multiplier else 
				if superClassOf target == shape then ScaleShape target multiplier else
				if target != root then (
					targetTM = target.transform * inverse target.parent.transform
					targetTM.translation *= multiplier
					target.transform = targetTM * target.parent.transform
				)
				
				join queue target.children
			)
			
			OK
		)

		on applyScaleButton pressed do ScaleModel selection scaleSpinner.value
		
		mapped fn flipMapCoords target mode: mapChannel:1 = if classOf target == Editable_mesh then (
			local flippedVerts = #{}
			local mapVertices
			local mapCoords

			for f = 1 to getNumFaces target do (
				mapVertices = meshop.getMapFace target mapChannel f

				for i = 1 to 3 where not flippedVerts[mapVertices[i]] do (
					mapCoords = meshOp.getMapVert target mapChannel mapVertices[i]
					
					case mode of (
						1: mapCoords.x = 1 - mapCoords.x
						2: mapCoords.y = 1 - mapCoords.y
						3: mapCoords.z = 1 - mapCoords.z
					)

					meshOp.setMapVert target mapChannel mapVertices[i] mapCoords
					flippedVerts[mapVertices[i]] = true
				)
			)

			update target
			OK
		)
			
		on flipUButton pressed do flipMapCoords selection mode:1 mapChannel:mapSpinner.value
		on flipVButton pressed do flipMapCoords selection mode:2 mapChannel:mapSpinner.value		
	)

	-- Object alignment tool (typically used to align hardpoints but limited to them)
	rollout AlignmentToolRollout "Alignment Tool" (
		local source -- Object to align (INode)
		local target -- Alignment target (INode)
		local origin -- Original source object transformation (Matrix3)
		local result -- Aligned source object transformation (Matrix3)
		local hit    -- Screen camera to target object hit (Ray)
		local dir    -- World "up" vector (Point3)
		local right  -- Local right vector (Point3)
		local up     -- Local up vector (Point3)
		
		spinner offsetSpinner "Offset" type:#float range:[-1000, 1000, 0] tooltip:"Vertical offset from surface."
		radiobuttons directionType "Direction:" labels:#("X", "-X", "Y", "-Y", "Z", "-Z") columns:2 default:4
		button alignButton "Select" height:24 width:88 tooltip:"Align selected object to target object mesh surface."
			
		tool AlignmentTool (

			-- Remember where object was
			on start do origin = source.transform

			-- Reset object transform to origin when cancelling
			on mouseAbort i do source.transform = origin
			
			-- Align object to point of cursor intersection with target mesh
			on freeMove do (
				dir = case directionType.state of (
					1:  x_axis
					2: -x_axis
					3:  y_axis
					4: -y_axis
					5:  z_axis
					6: -z_axis
				)
				
				hit = intersectRay target (mapScreenToWorldRay viewPoint)
				
				if hit == undefined then source.transform = origin else (
					right  = normalize (cross hit.dir dir)
					up     = -(normalize (cross right hit.dir))
					result = matrix3 right up hit.dir hit.position

					preTranslate result [0, 0, offsetSpinner.value]
					
					source.transform = result * scaleMatrix origin.scalepart
				)
			)
			
			on mousePoint i do #stop
		)

		fn FilterSource target = isValidNode target
		
		-- Target must be object to have surface for ray intersection
		fn FilterTarget target = isValidNode target and superClassOf target == GeometryClass
		
		on alignButton pressed do (
			source = if selection.count == 1 then selection[1] else pickObject message:"Select object to align" filter:FilterSource
				
			if FilterSource source then (
				target = pickObject message:"Pick mesh to align to" rubberBand:source.transform.translationpart filter:FilterTarget
				
				-- Initiate tool to align object
				if target != undefined then startTool AlignmentTool snap:#3D
			)
		)
	)
	
	-- Animation control (unused at the moment)
	rollout AnimationListRollout "Animations" (
		dotNetControl animationListView "System.Windows.Forms.ListView" width:160 height:120
		
		on AnimationListRollout open do (
			animationListView.BackColor = MAXLancer.GetNetColorMan #window
			animationListView.ForeColor = MAXLancer.GetNetColorMan #windowText
			
			animationListView.View        = (dotNetClass "System.Windows.Forms.View").Details
			animationListView.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").None
			
			animationListView.CheckBoxes = true
			animationListView.GridLines  = false
			
			animationListView.columns.Add "Script Name" (animationListView.width - 4)
			
			local parts   = for item in selection where MAXLancer.IsRigidPartHelper item collect item
			local layers  = #{}
			local items   = #()
			local indices = #()
			
			for part in parts do layers += (AnimLayerManager.getNodesLayers target) as bitArray
			
			for i in layers do (
				append items (dotNetObject "System.Windows.Forms.ListViewItem" (AnimLayerManager.getLayerName i))
				append indices i
			)
			
			animationListView.items.AddRange items
			animationListView.Update()
		)
	)
	
	rollout TemplatesRollout "INI Templates" (
		button loadoutButton "Loadout List" width:128 height:24 align:#center tooltip:"Generates [Loadout] template for equipment loadout from hardpoints of selected model."
		-- button shipButton "Ship Archetype" width:128 height:24 align:#center tooltip:"Generates [Shiparch] tempalte for ship archetype."
		-- button solarButton "Solar Archetype" width:128 height:24 align:#center tooltip:"Generates [Solararch] template for solar archetype."
		
		on loadoutButton pressed do (
			local target = MAXLancer.PickSceneObject MAXLancer.IsRigidPartHelper message:"Select rigid part" prompt:"Select rigid part object"
			
			if target != undefined then (
				local outputText = StringStream ""
				local hardpoints  = MAXLancer.GetPartHardpoints target deep:true
				local nameLength  = 0
				
				-- Filter out Hp
				hardpoints = for hardpoint in hardpoints where (substring (toLower hardpoint.name) 1 2) == "hp" collect (
					nameLength = amax nameLength hardpoint.name.count
					hardpoint
				)
				
				format "[Loadout]\r\nnickname = \%\r\n" to:outputText
				
				for hardpoint in hardpoints do
					format "equip = \%, % %\r\n" hardpoint.name (formattedPrint ("; " + hardpoint.parent.name) format:(" " + (nameLength - hardpoint.name.count + hardpoint.parent.name.count + 2) as string + "s")) to:outputText

				if setclipboardText (outputText as string) == true then messageBox "Loadout template copied into clipboard." beep:false
				else messageBox "Unable to copy loadout template into clipboard." beep:true
			)
		)
		
		/*
		on shipButton pressed do (
			local target = MAXLancer.PickSceneObject MAXLancer.IsRigidPartHelper message:"Select rigid part" prompt:"Select rigid part object"
			
			if target != undefined then (
				local outputText = StringStream ""
				
				format "[Ship]\r\nnickname = \%\r\n" to:outputText
				
				if setclipboardText (outputText as string) == true then messageBox "Ship archetype template copied into clipboard." beep:false
				else messageBox "Unable to copy ship archetype template into clipboard." beep:true
			)
		)
		*/
	)
	
	-- Rigid models utilities
	rollout RigidModelsRollout "Rigid Models" (

		local targetPart      -- RigidPartHelper (ex: startboard_wing)
		local targetHardpoint -- HardpointHelper (ex: DpStarboardWing)
		local damagePart      -- RigidPartHelper (ex: dmg_starboard_wing)
		local damageHardpoint -- HardpointHelper (ex: DpConnect)

		group "Helper Display" (
			spinner sizeSpinner "Size:" range:[0,100,1] type:#float
			button applySizeButton "Apply" width:88 height:24 align:#center tooltip:"Adjust size for all selected rigid part helpers."
		)

		group "Joint Type" (
			button applyFixedJointButton "Fixed" width:76 height:24 across:2 align:#left
			button applyRevoluteJointButton "Revolute" width:76 height:24 align:#right
			button applyPrismaticJointButton "Prismatic" width:76 height:24 across:2 align:#left
			button applyCylinderJointButton "Cylinder" width:76 height:24 align:#right
			button applySphereJointButton "Sphere" width:76 height:24 across:2 align:#left
			button applyLooseJointButton "Loose" width:76 height:24 align:#right
		)
		
		group "Levels of Detail" (
			spinner levelSpinner "Level:" range:[0,12,0] type:#integer tooltip:"Sets this level to all selected meshes."
			spinner distanceSpinner "View Distance:" range:[0, 3.4e38, 100] type:#float tooltip:"Sets this view distance to all selected meshes."
			
			button applyLevelsButton "Apply" width:76 height:24 align:#left across:2 tooltip:"Applies level of detail attributes to selected editable meshes."
			button clearLevelsButton "Clear" width:76 height:24 align:#right tooltip:"Removes level of detail attributes from selected editable meshes."
		)
		
		group "Vertex Data" (
			checkbox colorsCheckbox "Color and Transparency" tooltip:"Export vertex colors (map channels -2 and 0)."
			dropdownlist normalsList "Normals Acquisition Method:" items:#("None", "Auto/Explicit", "Smoothing Groups", "Per-Vertex")
			spinner mapsSpinner "UV Maps:" type:#integer range:[0, 8, 1] tooltip:"Export texture maps (map channels 1 to 8)."
			
			button applyVertexDataButton "Apply" width:88 height:24 align:#center tooltip:"Apply vertex data settings to all selected LOD meshes."
		)

		group "Collision Surfaces" (
			button applySurfaceMaterialButton "Apply Material" width:128 height:24 align:#center tooltip:"Applies default transparent red material to meshes. Doesn't affect anything."
			button convertMeshesToHullsButton "Generate Surfaces" width:128 height:24 align:#center tooltip:"Creates convex hulls from selected meshes."
			checkbox deleteMeshesCheckbox "Auto-Delete" across:2 tooltip:"Removes original meshes from which convex hulls were generated."
			checkbox mergeHullsCheckbox "Merge Hulls" tooltip:"Merges hulls into single mesh."
		)

		group "Destructible Parts" (
			button assignDestructibleButton "Assign" width:76 height:24 across:2 align:#left
			button removeDestructibleButton "Remove" width:76 height:24 align:#right
		)

		group "Miscellaneous" (
			button createWireframesButton "Create Wireframes" width:128 height:24 align:#center tooltip:"Create wireframe shapes for selected editable meshes from visible edges."
			button resetXFormButton "Reset Transforms" width:128 height:24 align:#center tooltip:"Applies and collapses XForm Reset to selected editable meshes."
			button centerPivotButton "Reset Center Pivots" width:128 height:24 align:#center tooltip:"Resets pivot for selected editable meshes."
		)

		fn filterTargetPart target = MAXLancer.IsRigidPartHelper target and MAXLancer.IsRigidPartHelper target.parent 

		fn filterDamagePart target = MAXLancer.IsRigidPartHelper target and target.parent == undefined

		fn filterTargetHardpoint target = targetPart != undefined and damagePart != undefined and MAXLancer.IsHardpointHelper target and target.parent == targetPart.parent

		on assignDestructibleButton pressed do (
			targetPart = if selection.count == 1 and filterTargetPart selection[1] then selection[1] else pickObject message:"Pick target part" filter:filterTargetPart

			if isValidNode targetPart then (
				damagePart = pickObject message:"Pick damage model" filter:filterDamagePart rubberBand:targetPart.transform.translationpart

				if isValidNode damagePart then (
					damageHardpoint = MAXLancer.FindHardpoint damagePart "DpConnect"
					targetHardpoint = pickObject message:"Pick target hardpoint" filter:filterTargetHardpoint rubberBand:(if damageHardpoint != undefined then damageHardpoint.transform.translationpart else damagePart.transform.translationpart)

					if isValidNode targetHardpoint then (
						if queryBox ("Do you want to assign " + damagePart.name + " as damage model to part " + targetPart.name + " (" + targetHardpoint.name + ")?") beep:false then (
							if damageHardpoint == undefined then (
								damageHardpoint = copy targetHardpoint

								damageHardpoint.name = "DpConnect"
								damageHardpoint.parent = damagePart
							)
							
							local controller = damagePart.transform.controller

							if classOf controller != MAXLancer.HardpointLinkController then controller = damagePart.transform.controller = MAXLancer.HardpointLinkController()

							controller.offset  = damageHardpoint.transform * inverse damagePart.transform
							controller.target  = targetHardpoint
							controller.preview = true
							
							targetPart.damageModel = damagePart
						)
					) else messageBox "No target hardpoint selected" beep:false
				) else messageBox "No damage part selected" beep:false
			) else messageBox "No target part selected" beep:false

			OK
		)

		on removeDestructibleButton pressed do (
			local targetPart = if selection.count == 1 and MAXLancer.IsRigidPartHelper selection[1] then selection[1] else pickObject message:"Pick target part" filter:MAXLancer.IsRigidPartHelper

			if isValidNode targetPart and isValidNode targetPart.damageModel then (
				targetPart.damageModel.transform.controller = NewDefaultMatrix3Controller()
				targetPart.damageModel = undefined
			)

			OK
		)

		on applyFixedJointButton pressed do for target in selection where MAXLancer.IsRigidPartHelper target do target.controller = MAXLancer.FixedJointController()
		on applyRevoluteJointButton pressed do for target in selection where MAXLancer.IsRigidPartHelper target do target.controller = MAXLancer.AxisJointController type:1
		on applyPrismaticJointButton pressed do for target in selection where MAXLancer.IsRigidPartHelper target do target.controller = MAXLancer.AxisJointController type:2
		on applyCylinderJointButton pressed do for target in selection where MAXLancer.IsRigidPartHelper target do target.controller = MAXLancer.AxisJointController type:3
		on applySphereJointButton pressed do for target in selection where MAXLancer.IsRigidPartHelper target do target.controller = MAXLancer.SphericJointController() 
		on applyLooseJointButton pressed do for target in selection where MAXLancer.IsRigidPartHelper target do target.controller = MAXLancer.LooseJointController()
		
		mapped fn createWireframe target = if classOf target == Editable_mesh then (
			local wireframe = MAXLancer.GenerateWireframe target

			if numSplines wireframe == 0 then delete wireframe else (
				wireframe.wireColor = target.wireColor
				wireframe.parent = target
				wireframe.name = target.name + "_Wire"
			)
			
			OK
		)
		
		mapped fn applyLevels target level range = if classOf target == Editable_mesh then (
			MAXLancer.SetVMesh target
			
			local a = custAttributes.get target MAXLancer.VMeshAttributes
			
			a.level = level
			a.range = range
			OK
		)
		
		mapped fn applyVertexData target colors normals mapCount = if MAXLancer.IsRigidLevel target then (
			local a = custAttributes.get target MAXLancer.VMeshAttributes
			
			a.colors = colors
			a.normals = normals
			a.maps = mapCount
			OK
		)
		
		on createWireframesButton pressed do createWireframe selection

		on applySizeButton pressed do MAXLancer.SetRigidPartSize selection sizeSpinner.value

		on applyLevelsButton pressed do applyLevels selection levelSpinner.value distanceSpinner.value
			
		on applyVertexDataButton pressed do applyVertexData selection colorsCheckbox.checked normalsList.selection mapsSpinner.value
		
		on clearLevelsButton pressed do MAXLancer.UnsetVMesh selection

		on resetXFormButton pressed do (
			local targets = for target in selection where classOf target == Editable_mesh collect target

			for target in targets where not MAXLancer.IsRigidPartHelper target.parent do target.parent = undefined

			ResetXForm targets
			collapseStack targets
		)

		on centerPivotButton pressed do CenterPivot selection

		on applySurfaceMaterialButton pressed do for target in selection where classOf target == Editable_mesh do target.material = MAXLancer.surfaceMaterial

		on convertMeshesToHullsButton pressed do (
			local vertices
			local hull
			local result = #()

			for target in selection where classOf target == Editable_mesh do (
				vertices = for v = 1 to getNumVerts target collect getVert target v

				hull = mesh mesh:(MAXLancer.GenerateHull vertices maxVertices:vertices.count)
				hull.material = MAXLancer.surfaceMaterial
				
				if deleteMeshesCheckbox.checked then delete target
				if mergeHullsCheckbox.checked and result.count > 0 then meshOp.attach result[1] hull else append result hull
			)
			
			if result.count > 0 then select result
		)
	)

	-- Hardpoint tools and management
	rollout HardpointsRollout "Hardpoints" (
		local source
		local target
		
		group "Helper Display" (
			spinner baseSizeSpinner "Base:"   range:[0,100,1] type:#float across:2
			spinner arrowSizeSpinner "Arrow:" range:[0,100,1] type:#float
			button applyButton "Apply" width:88 height:24 align:#center tooltip:"Apply helper display sizes to selected hardpoints."
		)

		group "Type && Limits" (
			dropdownlist typeList "Constraint Type" items:#("Fixed", "Revolute", "Prismatic")
			spinner limitMinSpinner "Min:" type:#float range:[-3.4e38, 3.4e38, 0] scale:0.5 across:2
			spinner limitMaxSpinner "Max:" type:#float range:[-3.4e38, 3.4e38, 0] scale:0.5
			button limitApplyButton "Apply" width:88 height:24 align:#center tooltip:"Apply constraint type and limit min/max values to selected hardpoints."
		)

		group "Collision Hull" (
			dropdownlist hullShapeList "Shape Type" items:#("None", "Box (Gun)", "Box (Gun Centered)", "Hemisphere (Turret)", "Cylinder (Equipment)")
			spinner hullSizeSpinner "Hull Size:" type:#float range:[0, 100, 1]
			button hullApplyButton "Apply" width:88 height:24 align:#center tooltip:"Apply collision hull type and size to selected hardpoints."
		)

		group "Mirror Hardpoints" (
			checkbox mirrorFlipLimits "Flip revolute min/max limits" checked:true tooltip:"Flips min/max limits for revolute hardpoints."
			button mirrorXButton "X" width:48 height:24 across:3 tooltip:"Mirrors hardpoints around root of model (or scene) by local X axis."
			button mirrorYButton "Y" width:48 height:24 tooltip:"Mirrors hardpoints around root of model (or scene) by local Y axis."
			button mirrorZButton "Z" width:48 height:24 tooltip:"Mirrors hardpoints around root of model (or scene) by local Z axis."
		)
		
		group "Miscellaneous" (
			button alignButton "Align by Hardpoints" width:128 height:24 align:#center tooltip:"Aligns source object hierarchy of source hardpoint to target hardpoint."
			button replaceButton "Convert to Hardpoints" width:128 height:24 align:#center tooltip:"Replaces selected objects with hardpoint helpers while retaining original transform and parent node"
		)
		
		mapped fn mirrorHardpoint source axis flipLimits = if MAXLancer.IsHardpointHelper source then (
			local root   = MAXLancer.GetRootFromHardpoint source
			local target = copy source -- Create a copy of helper node
			local matrix = if isValidNode root then root.transform else Matrix3 1
				
			target.name = uniqueName source.name numDigits:2
			source.layer.addNode target
			
			local scaler = case axis of (
				1: [-1, 1, 1]
				2: [1, -1, 1]
				3: [1, 1, -1]
			)
			
			target.transform = target.transform * inverse matrix * scaleMatrix scaler * matrix
			
			in coordsys local (
				scale target [-1, -1, -1]
				rotate target (quat 180 x_axis)
			)

			if flipLimits and target.type == 2 then (
				target.limitMin = -source.limitMax
				target.limitMax = -source.limitMin
			)
			
			OK
		)
		
		on applyButton pressed do MAXLancer.SetHardpointSize selection baseSizeSpinner.value arrowSizeSpinner.value

		on limitApplyButton pressed do for source in selection where MAXLancer.IsHardpointHelper source do (
			source.type = typeList.selection
			source.limitMin = limitMinSpinner.value
			source.limitMax = limitMaxSpinner.value
		)

		on hullApplyButton pressed do for source in selection where MAXLancer.IsHardpointHelper source do (
			source.hullShape = hullShapeList.selection
			source.hullSize = hullSizeSpinner.value
		)
		
		on mirrorXButton pressed do mirrorHardpoints selection 1 mirrorFlipLimits.checked
		on mirrorYButton pressed do mirrorHardpoints selection 2 mirrorFlipLimits.checked
		on mirrorZButton pressed do mirrorHardpoints selection 3 mirrorFlipLimits.checked

		fn FilterSource hardpoint = MAXLancer.IsHardpointHelper hardpoint
		fn FilterTarget hardpoint = MAXLancer.IsHardpointHelper hardpoint and hardpoint != source

		fn PickSource = (source = pickObject message:"Pick source hardpoint" count:1 filter:FilterSource) != undefined
		fn PickTarget = (target = pickObject message:"Pick target hardpoint" count:1 filter:FilterTarget rubberBand:source.pos) != undefined

		on alignButton pressed do if PickSource() and PickTarget() then MAXLancer.AttachHardpoints source target attach:false

		on replaceButton pressed do (
			local items = selection as array
			local replacement

			if items.count == 0 then messageBox "No objects are selected." else
			if queryBox ("Do you want to replace " + (formattedPrint items.count format:"u") + " objects with hardpoint helpers?") then
				for item in items do (
					replacement = MAXLancer.CreateHardpointHelper item.name

					replacement.transform = item.transform
					replacement.baseSize  = baseSizeSpinner.value
					replacement.arrowSize = arrowSizeSpinner.value

					if item.parent != undefined then replacement.parent = item.parent
					delete item
				)
		)
	)

	-- MAXLancer shader control
	rollout ShaderDisplayRollout "Shader Display" (
		local indices = #()
		
		checkbox lightsCheckbox "Vertex Lighting" checked:true toolTip:"Toggle light shading in shaders."
		checkbox vertexColorCheckbox "Vertex Color" checked:true toolTip:"Toggle vertex colors in shaders."
		checkbox vertexAlphaCheckbox "Vertex Alpha" checked:true toolTip:"Toggle vertex transparency in shaders."

		dotNetControl lightsListView "System.Windows.Forms.ListView" width:160 height:120
		
		button refreshButton "Refresh" width:76 height:24 across:2 align:#left toolTip:"Reload light sources list." 
		button applyButton "Apply" width:76 height:24 align:#right toolTip:"Apply settings to all MAXLancer shaders in scene."
		
		on lightsCheckbox changed state do MAXLancer.displayVertexLighting = state
		on vertexColorCheckbox changed state do MAXLancer.displayVertexColors = state
		on vertexAlphaCheckbox changed state do MAXLancer.displayVertexAlpha = state
		
		fn FilterMaterial target = classOf target == DxMaterial
		
		-- Lights are assigned to shader by their ID in lights collection, not as nodes or names
		fn RefreshList = (
			local index = indices.count = 0
			local items = #()
			
			lightsListView.items.Clear()
			
			for item in lights do (
				index += 1
				
				if classOf item == Omnilight then (
					append items (dotNetObject "System.Windows.Forms.ListViewItem" item.name)
					append indices index
				)	
			)
			
			lightsListView.items.AddRange items
			lightsListView.Update()
			OK
		)
		
		-- Get DxMaterials and subs in MultiMaterials
		fn CollectMaterials = (
			local materials = #()
			
			for target in sceneMaterials do
				if filterMaterial target then appendIfUnique materials target else
				if classOf target == MultiMaterial then
					for submaterial in target.materialList where FilterMaterial submaterial do appendIfUnique materials submaterial
			
			materials
		)
		
		on applyButton pressed do (
			local materials = CollectMaterials()
			local items = #()

			-- Collect indices of selected lights
			local items = for i = 1 to lightsListView.CheckedIndices.Count collect indices[(lightsListView.CheckedIndices.Item (i - 1)) + 1]
			
			-- Clamp to max four lights
			if items.count > 4 then items.count = 4
			
			for mat in materials do (
				if hasProperty mat #EnableLights then setProperty mat #EnableLights lightsCheckbox.checked
				if hasProperty mat #EnableVertexColor then setProperty mat #EnableVertexColor vertexColorCheckbox.checked
				if hasProperty mat #EnableVertexAlpha then setProperty mat #EnableVertexAlpha vertexAlphaCheckbox.checked
				if hasProperty mat #LightCount then setProperty mat #LightCount items.count
					
				if hasProperty mat #Light1Position then setProperty mat #Light1Position (if items[1] != undefined then items[1] else 0)
				if hasProperty mat #Light2Position then setProperty mat #Light2Position (if items[2] != undefined then items[2] else 0)
				if hasProperty mat #Light3Position then setProperty mat #Light3Position (if items[3] != undefined then items[3] else 0)
				if hasProperty mat #Light4Position then setProperty mat #Light4Position (if items[4] != undefined then items[4] else 0)
			)
		)

		on refreshButton pressed do RefreshList()
		
		fn InitView = (
			lightsListView.BackColor = MAXLancer.GetNetColorMan #window
			lightsListView.ForeColor = MAXLancer.GetNetColorMan #windowText
			
			lightsListView.View        = (dotNetClass "System.Windows.Forms.View").Details
			lightsListView.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").None
			
			lightsListView.CheckBoxes = true
			lightsListView.GridLines  = false
			
			lightsListView.columns.Add "Name" (lightsListView.width - 4)
			
			lightsCheckbox.checked      = MAXLancer.displayVertexLighting
			vertexColorCheckbox.checked = MAXLancer.displayVertexColors
			vertexAlphaCheckbox.checked = MAXLancer.displayVertexAlpha
		)
	)

	-- FLCRC32 simple calculator
	rollout HashCalculatorRollout "FLCRC32" (
		checkbox caseSensitiveCheckbox "Case Sensitive"
		checkbox hexCheckbox "Hexadecimal Output" checked:true
		edittext inputText "Input" labelOnTop:true 
		edittext outputText "Output" labelOnTop:true readOnly:true

		on inputText changed input do (
			if input.count == 0 then outputText.text = "" else (
				local crc = MAXLancer.Hash input caseSensitive:caseSensitiveCheckbox.checked
				outputText.text = if hexCheckbox.checked then formattedPrint crc format:"08X" else crc as string
			)
		)
	)

	-- Assisstance tools for system editing (copying coordinates and rotation angles)
	rollout SystemToolsRollout "System Tools" (



	)

	fn OpenToolbox = (
		if toolboxOpen then CloseToolbox()
		
		toolboxFloater = newRolloutFloater "MAXLancer Tools" 200 200
		
		addRollout ToolboxRollout toolboxFloater
		addRollout AlignmentToolRollout toolboxFloater rolledUp:true
		addRollout ModelToolsRollout toolboxFloater rolledUp:true
		addRollout RigidModelsRollout toolboxFloater rolledUp:true
		addRollout HardpointsRollout toolboxFloater rolledUp:true
		addRollout TemplatesRollout toolboxFloater rolledUp:true
		addRollout ShaderDisplayRollout toolboxFloater rolledUp:true
		addRollout HashCalculatorRollout toolboxFloater rolledUp:true
		
		ShaderDisplayRollout.InitView()
		ShaderDisplayRollout.RefreshList()
		
		cui.RegisterDialogBar toolboxFloater style:#(#cui_dock_vert, #cui_floatable)
		cui.DockDialogBar toolboxFloater #cui_dock_left
		
		toolboxOpen = true
		updateToolbarButtons()
	)
	
	fn CloseToolbox = (
		if classOf toolboxFloater == RolloutFloater then (
			if toolboxFloater.dialogBar then cui.UnRegisterDialogBar toolboxFloater
			closeRolloutFloater toolboxFloater
		)
		
		toolboxOpen = false
		updateToolbarButtons()
	)

	on execute do (
		if MAXLancer == undefined then macros.run "MAXLancer" "ReloadScripts"
		if MAXLancer != undefined then OpenToolbox()
	) 

	on isChecked do toolboxOpen

	on closeDialogs do CloseToolbox()
)