macroScript Toolbox category:"MAXLancer" tooltip:"Toolbox" buttontext:"Toolbox" iconName:"MAXLancer/toolbar" (
	global MAXLancer

	local toolboxFloater      -- RolloutFloater
	local toolboxOpen = false

	rollout SettingsRollout "Settings" width:320 height:392 (

		groupbox sizeBox "Default helper size" pos:[8,8] width:148 height:64
		label partLabel "Model part" pos:[16, 28] width:66
		spinner partSize "" pos:[82, 28] width:66
		
		label hardpointLabel "Hardpoint" pos:[16, 48] width:66
		spinner hardpointSize "" pos:[82, 48] width:66
		
		groupbox generatorBox "Convex hull generator" pos:[164,8] width:148 height:64
		radiobuttons convexGenerator "" pos:[172, 28] labels:#("Nvidia PhysX", "Internal QuickHull") default:1 columns:1

		groupbox exporterBox "Exporter version text" pos:[8,80] width:304 height:48
		edittext exporterVersion "" labelOnTop:true pos:[16,100] width:288

		groupbox freelancerBox "Freelancer" pos:[8,136] width:304 height:48
		edittext freelancerPath "" labelOnTop:true pos:[16,156] width:216
		button freelancerBrowse "Browse" pos:[240, 152] width:64 height:24

		groupbox texturesBox "Textures" pos:[8,192] width:304 height:48
		edittext texturesPath "" labelOnTop:true pos:[16,212] width:216
		button texturesBrowse "Browse" pos:[240,208] width:64 height:24

		groupbox textureToolsBox "Nvidia Texture Tools" pos:[8,248] width:304 height:48
		edittext textureToolsPath "" labelOnTop:true pos:[16,268] width:216
		button textureToolsBrowse "Browse" pos:[240,264] width:64 height:24

		groupbox shadersBox "Shaders" pos:[8,304] width:304 height:48
		edittext shadersPath "" labelOnTop:true pos:[16,324] width:216
		button shadersBrowse "Browse" pos:[240, 320] width:64 height:24

		button OKButton     "OK" pos:[128, 360] width:88 height:24
		button cancelButton "Cancel" pos:[224, 360] width:88 height:24

		fn GetPathTo target caption = (
			local filepath = getSavePath initialDir:target.text caption:caption
			if filepath != undefined then target.text = filepath
			OK
		)

		fn IsValidPath target = doesFileExist target and getFileAttribute target #directory
		fn IsValidFile target = doesFileExist target and getFileAttribute target #normal

		-- Apply property to MAXLancer instance and save into configuration file
		fn ApplyProperty property value = (
			setProperty MAXLancer property value
			MAXLancer.config.SaveProperty "MAXLancer" (property as string) value
			OK
		)

		on OKButton pressed do if not IsValidPath freelancerPath.text then messageBox "Invalid Freelancer path."
			else if not IsValidPath texturesPath.text then messageBox "Invalid textures path."
			else if not IsValidPath textureToolsPath.text then messageBox "Invalid texture tools path."
			else if not IsValidPath shadersPath.text then messageBox "Invalid shaders path."
			else (
				ApplyProperty #exporterVersion  exporterVersion.text
				ApplyProperty #freelancerPath   freelancerPath.text
				ApplyProperty #textureToolsPath textureToolsPath.text
				ApplyProperty #texturesPath     texturesPath.text
				ApplyProperty #shadersPath      shadersPath.text
				ApplyProperty #partSize         partSize.value
				ApplyProperty #hardpointSize    hardpointSize.value
				ApplyProperty #convexGenerator  convexGenerator.state

				messageBox "Settings applied."
				DestroyDialog SettingsRollout
			)

		on cancelButton pressed do DestroyDialog SettingsRollout

		on freelancerBrowse pressed do GetPathTo freelancerPath "Freelancer Folder:"
		on shadersBrowse pressed do GetPathTo shadersPath "Shaders Folder:"
		on texturesBrowse pressed do GetPathTo texturesPath "Texture Folder:"
		on textureToolsBrowse pressed do GetPathTo textureToolsPath "Texture Tools Folder:"
		on shadersBrowse pressed do GetPathTo shadersPath "Shaders Folder:"

		on SettingsRollout open do (
			partSize.value        = MAXLancer.partSize
			hardpointSize.value   = MAXLancer.hardpointSize
			convexGenerator.state = MAXLancer.convexGenerator
			exporterVersion.text  = MAXLancer.exporterVersion
			freelancerPath.text   = MAXLancer.freelancerPath
			textureToolsPath.text = MAXLancer.textureToolsPath
			texturesPath.text     = MAXLancer.texturesPath
			shadersPath.text      = MAXLancer.shadersPath
		)
	)

	rollout ToolboxRollout "MAXLancer Tools" (
		button settingsButton "Settings"       width:128 height:24 align:#center
		button logButton      "Message Log"    width:128 height:24 align:#center
		button reloadButton   "Reload Scripts" width:128 height:24 align:#center
		label versionLabel    ""               width:128 align:#center

		on settingsButton pressed do CreateDialog SettingsRollout modal:true

		on logButton pressed do MAXLancer.ShowLog()

		on reloadButton pressed do try (
			macros.run "MAXLancer" "ReloadScripts"
			messageBox "MAXLancer scripts reloaded."
		) catch (
			messageBox (getCurrentException())
		)

		on RigidModelsRollout close do (
			toolboxOpen = false
			updateToolbarButtons()
		)
		
		on ToolboxRollout open do (
			versionLabel.text = "Version " + MAXLancer.version as string
		)
	)

	rollout RescaleRollout "Rescale Model" (
		spinner scaleSpinner "Scale" type:#float range:[0.001, 1000, 1]
		button scaleButton "Apply" height:24 width:88

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

		fn ScaleModel root multiplier = (
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

		on scaleButton pressed do if selection.count == 1 then ScaleModel selection[1] scaleSpinner.value
	)

	rollout AlignmentToolRollout "Alignment Tool" (
		local source -- Object to align (INode)
		local target -- Alignment target (INode)
		local origin -- Original source object transformation (Matrix3)
		local result -- Aligned source object transformation (Matrix3)
		local hit    -- Screen camera to target object hit (Ray)
		local dir    -- World "up" vector (Point3)
		local right  -- Local right vector (Point3)
		local up     -- Local up vector (Point3)
		
		spinner offsetSpinner "Offset" type:#float range:[-1000, 1000, 0] tooltip:"Vertical offset from surface"
		radiobuttons directionType "Direction:" labels:#("X", "-X", "Y", "-Y", "Z", "-Z") columns:2 default:4
		button alignButton "Select" height:24 width:88
		
		tool AlignmentTool (
			on start do origin = source.transform
			on mouseAbort i do source.transform = origin
				
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
				
				-- TODO: Fix resulting matrix being flipped

				if hit == undefined then source.transform = origin else (
					right  = normalize (cross hit.dir dir)
					up     = -(normalize (cross right hit.dir))
					result = matrix3 right up hit.dir hit.position

					-- result = MatrixFromNormal hit.dir
					-- result.row4 = hit.position

					preTranslate result [0, 0, offsetSpinner.value]
					
					source.transform = result
					-- source.dir = h.dir
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
			
			local parts   = for item in selection where classOf item == MAXLancer.RigidPartHelper collect item
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

	rollout RigidModelsRollout "Rigid Models" (

		spinner sizeSpinner "Helper Size:" range:[0,100,1] type:#float
		button applyButton "Apply" width:88 height:24 align:#center
		
		label VMeshLabel "Level of Detail:" align:#left
		button setVMeshButton   "Set"   width:76 height:24 across:2 align:#left
		button unsetVMeshButton "Unset" width:76 height:24 align:#right
		
		group "Surfaces" (
			button applySurfaceMaterialButton "Apply Material" width:128 height:24 align:#center
			button convertMeshesToHullsButton "Convert Meshes" width:128 height:24 align:#center
			checkbox deleteMeshesCheckbox "Auto-Delete Meshes"
			checkbox mergeHullsCheckbox "Merge Hulls"
		)

		on applyButton pressed do MAXLancer.SetRigidPartSize selection sizeSpinner.value

		on setVMeshButton pressed do MAXLancer.SetVMesh selection
		on unsetVMeshButton pressed do MAXLancer.UnsetVMesh selection

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

	rollout FlipTexturesRollout "Flip UVs" (

		checkbox flipUCheckbox "Horizontal" across:2
		checkbox flipVCheckbox "Vertical"

		spinner mapSpinner "Map" range:[1, 99, 1] type:#integer

		button flipButton "Flip" width:76 height:24

		on flipButton pressed do (
			for target in (for o in selection where classOf o == Editable_mesh collect o) do (
				local flippedVerts = #{}
				local mapVertices
				local mapCoords

				for f = 1 to getNumFaces target do (
					mapVertices = meshop.getMapFace target mapSpinner.value f

					for i = 1 to 3 where not flippedVerts[mapVertices[i]] do (
						mapCoords = meshOp.getMapVert target mapSpinner.value mapVertices[i]
						
						if flipUCheckbox.checked then mapCoords.x = 1 - mapCoords.x
						if flipVCheckbox.checked then mapCoords.y = 1 - mapCoords.y

						meshOp.setMapVert target mapSpinner.value mapVertices[i] mapCoords
						flippedVerts[mapVertices[i]] = true
					)
				)

				update target
			)
		)
	)

	rollout HardpointsRollout "Hardpoints" (
		local source
		local target
		
		spinner baseSizeSpinner "Base Size:"   range:[0,100,1] type:#float
		spinner arrowSizeSpinner "Arrow Size:" range:[0,100,1] type:#float
		button applyButton "Apply" width:88 height:24 align:#center
		
		group "Connect Hardpoints" (
			button alignButton "Align"   width:76 height:24 across:2 align:#left tooltip:"Aligns source object hierarchy of source hardpoint to target hardpoint" across:2
			button attachButton "Attach" width:76 height:24 align:#right tooltip:"Attaches source object hierarchy to source hardpoint to target hardpoint"
		)

		button replaceButton "Replace Selection" width:128 height:24 align:#center

		on applyButton pressed do MAXLancer.SetHardpointSize selection baseSizeSpinner.value arrowSizeSpinner.value

		fn FilterSource hardpoint = classOf hardpoint == MAXLancer.HardpointHelper
		fn FilterTarget hardpoint = classOf hardpoint == MAXLancer.HardpointHelper and hardpoint != source

		fn PickSource = (source = pickObject message:"Pick source hardpoint" count:1 filter:FilterSource) != undefined
		fn PickTarget = (target = pickObject message:"Pick target hardpoint" count:1 filter:FilterTarget rubberBand:source.pos) != undefined

		on alignButton pressed do if PickSource() and PickTarget() then MAXLancer.AttachHardpoints source target attach:false
		on attachButton pressed do if PickSource() and PickTarget() then MAXLancer.AttachHardpoints source target attach:true

		on replaceButton pressed do (
			local items = selection as array
			local replacement

			if items.count == 0 then messageBox "No objects are selected." else
			if queryBox ("Do you want to replace " + (formattedPrint items.count format:"u") + " objects with hardpoint helpers?") then
				for item in items do (
					replacement = MAXLancer.HardpointHelper name:item.name transform:item.transform baseSize:baseSizeSpinner.value arrowSize:arrowSizeSpinner.value
					if item.parent != undefined then replacement.parent = item.parent
					delete item
				)
		)
	)
	
	rollout ShaderDisplayRollout "Shader Display" (
		local indices = #()
		
		checkbox lightsCheckbox "Vertex Lighting" checked:true toolTip:"Toggle light shading in shaders."
		checkbox vertexColorCheckbox "Vertex Color" checked:true toolTip:"Toggle vertex colors in shaders."
		checkbox vertexAlphaCheckbox "Vertex Alpha" checked:true toolTip:"Toggle vertex transparency in shaders."

		dotNetControl lightsListView "System.Windows.Forms.ListView" width:160 height:120
		
		button refreshButton "Refresh" width:76 height:24 across:2 align:#left toolTip:"Reload light sources list." 
		button applyButton "Apply" width:76 height:24 align:#right toolTip:"Apply settings to all MAXLancer shaders."
		
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

	fn OpenToolbox = (
		if toolboxOpen then CloseToolbox()
		
		toolboxFloater = newRolloutFloater "MAXLancer Tools" 200 200
		
		addRollout ToolboxRollout toolboxFloater
		addRollout AlignmentToolRollout toolboxFloater
		addRollout RescaleRollout toolboxFloater
		addRollout RigidModelsRollout toolboxFloater
		addRollout HardpointsRollout toolboxFloater
		addRollout ShaderDisplayRollout toolboxFloater
		addRollout FlipTexturesRollout toolboxFloater
		addRollout HashCalculatorRollout toolboxFloater
		
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