/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Creates convex hulls from selected sub-elements of Editable_mesh.
 */
macroscript SurfaceBuilder category:"MAXLancer" tooltip:"Surface Builder" buttontext:"Surface Builder" iconName:"MAXLancer/surface_builder" (
	global MAXLancer
	
	global MAXLancerSurfaceBuilderSelectionChange
	global MAXLancerSurfaceBuilderLevelChange
	
	local target -- Target editable_mesh or editable_poly
	local selectHandler -- Sub-elements select handler

	rollout SurfaceBuilderRollout "Surface Builder" width:192 height:212 (
		local previewHull = TriMesh() -- Preview mesh to display in viewport

		colorPicker previewColor "Preview Wire Color:"
		
		checkbox displayPreview "Display Preview" checked:true

		slider maxVerticesSlider "Vertex Limit:" width:184 height:44 enabled:false type:#integer ticks:0 align:#left \
			toolTip:"Adjust number of maximum vertices used for hull generation."

		label vertsSelectedLabel "Vertices Selected:" width:100 height:16 across:2 align:#left
		label vertsSelectedCount "0"                  height:16 align:#right
		label vertsUsedLabel     "Vertices Used:"     width:100 height:16 across:2 align:#left
		label vertsUsedCount     "0"                  height:16 align:#right
		label facesUsedLabel     "Faces Used:"        width:100 height:16 across:2 align:#left
		label facesUsedCount     "0"                  height:15 align:#right
		
		edittext targetName "" width:172 align:#center labelOnTop:true readOnly:true
		
		button createButton "Create Hull" width:96 height:24 enabled:false align:#center \
			toolTip:"Creates hull mesh object for selected subelements."

		-- pickButton pickTargetButton "Pick Target" width:144 height:24

		-- Draw preview in viewport
		fn DisplayHullPreview = (
			gw.setRndLimits #(#illum, #colorVerts, #wireframe)
			
			--gw.setTransform target.objectTransform
			gw.setTransform (matrix3 1)

			if displayPreview.checked and previewHull.numFaces > 0 then (
				gw.startTriangles()

				local face, a, b, c
				-- local viewTM = inverse (getViewTM())
				
				for f = 1 to previewHull.numFaces do (
					face = getFace previewHull f
					a = getVert previewHull face.x
					b = getVert previewHull face.y
					c = getVert previewHull face.z
					
					gw.triangle #(a, b, c) #(previewColor.color, previewColor.color, previewColor.color)
				)

				gw.endTriangles()
			)
			
			gw.enlargeUpdateRect #whole
			gw.updateScreen()
		)

		on displayPreview changed state do (
			gw.enlargeUpdateRect #whole
			gw.updateScreen()
		)
		
		-- Update Vertices Used label
		fn UpdateVerticesUsed numVerts = (
			vertsUsedCount.text = (formattedPrint numVerts format:"u") + " of " + (formattedPrint (int maxVerticesSlider.range.y) format:"u")
			facesUsedCount.text = (formattedPrint previewHull.numFaces format:"u")
		)

		-- Reset controls (except vertsSelectionCount)
		fn ClearControls = (
			facesUsedCount.text = vertsUsedCount.text = "0"
			
			maxVerticesSlider.range   = [0, 0, 0]
			maxVerticesSlider.enabled = false
			createButton.enabled      = false
			OK
		)

		-- Generate convex hull from selected vertices (for some reason pickButton can fail and object will be object's parent)
		fn GenerateHull maxVertices:0 = if target != undefined then (
			local indices = case getSelectionLevel target of ( -- Sub-element selection need to be converted to vertices
				#face: meshOp.getVertsUsingFace target (getFaceSelection target)
				#edge: meshOp.getVertsUsingEdge target (getEdgeSelection target) -- Glitchy for some reason
				#vertex: getVertSelection target
				default: #{}
			)
			
			local vertices = for i in indices collect getVert target i

			vertsSelectedCount.text = vertices.count as string
			if maxVertices == 0 then maxVertices = vertices.count
			
			previewHull.numFaces = 0

			-- Convex mesh requires at least four vertices
			if vertices.count >= 4 then (
				local hull = MAXLancer.GenerateHull vertices maxVertices:maxVertices

				if hull != undefined then (
					setMesh previewHull hull

					if maxVertices == vertices.count then ( -- The initial slider setup before any limits through it are applied
						maxVerticesSlider.range   = [4, previewHull.numVerts, previewHull.numVerts]
						maxVerticesSlider.enabled = true
					)

					UpdateVerticesUsed (getNumVerts previewHull - (meshop.getIsoVerts previewHull).numberSet)
					createButton.enabled = true
				)
			) else (
				-- previewHull.numFaces = 0
				ClearControls()
			)
		)

		on maxVerticesSlider changed maxVertices do UpdateVerticesUsed maxVertices
		on maxVerticesSlider buttonup do GenerateHull maxVertices:maxVerticesSlider.value

		on createButton pressed do if previewHull.numFaces > 0 then (
			local result = mesh name:(uniqueName (target.name + ".Hull")) mesh:previewHull material:MAXLancer.surfaceMaterial

			if target.parent != undefined then result.parent = target.parent

			nodeInvalRect result
			redrawViews()
		)


		on SurfaceBuilderRollout open do (
			MAXLancer.config.LoadRollout SurfaceBuilderRollout controls:#()

			unRegisterRedrawViewsCallback DisplayHullPreview
			registerRedrawViewsCallback DisplayHullPreview

			callbacks.addScript #selectionSetChanged "MAXLancerSurfaceBuilderSelectionChange()" id:#surfaceBuilderSwitch
			callbacks.addScript #ModPanelSubObjectLevelChanged "MAXLancerSurfaceBuilderLevelChange()" id:#surfaceBuilderLevel
			
			MAXLancerSurfaceBuilderSelectionChange()
		)
		
		on SurfaceBuilderRollout close do (
			unRegisterRedrawViewsCallback DisplayHullPreview

			if classOf selectHandler == ChangeHandler then deleteChangeHandler selectHandler
			target = undefined

			callbacks.removeScripts #selectionSetChanged id:#surfaceBuilderSwitch
			callbacks.removeScripts #ModPanelSubObjectLevelChanged id:#surfaceBuilderLevel
			
			updateToolbarButtons()

			MAXLancer.config.SaveRollout SurfaceBuilderRollout controls:#()
		)
	)
	
	fn MAXLancerSurfaceBuilderLevelChange = (
		SurfaceBuilderRollout.GenerateHull()
	)
	
	fn MAXLancerSurfaceBuilderSelectionChange = (
		if classOf selectHandler == ChangeHandler then deleteChangeHandler selectHandler

		selectHandler = target = undefined
		SurfaceBuilderRollout.targetName.text = ""

		if selection.count == 1 and classOf selection[1] == Editable_mesh then (
			target = selection[1]
			SurfaceBuilderRollout.targetName.text = target.name
			
			selectHandler = when select target changes do SurfaceBuilderRollout.GenerateHull()
			SurfaceBuilderRollout.GenerateHull()
		)
	)
	
	on isChecked do SurfaceBuilderRollout.inDialog
	
	on execute do if MAXLancer != undefined then CreateDialog SurfaceBuilderRollout style:#(#style_titlebar, #style_border, #style_minimizebox) else messageBox "MAXLancer is not initialized."
	
	on closeDialogs do (
		DestroyDialog SurfaceBuilderRollout
		updateToolbarButtons()
		target = undefined
	)
)