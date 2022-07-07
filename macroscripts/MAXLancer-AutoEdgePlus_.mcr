/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Improved auto-edge options for editable mesh
 */
macroscript AutoEdgePlus category:"MAXLancer" tooltip:"AutoEdge Plus" buttontext:"AutoEdge Plus" iconName:"MAXLancer/import_models" (
	global MAXLancer

	rollout AutoEdgePlusRollout "AutoEdge Plus" width:136 height:184 (

		checkbox splitMaterialsCheckbox "Split by materials" checked:true
		checkbox splitGroupsCheckbox "Split by smoothing groups"

		spinner angleSpinner "Angle Threshold" range:[0,180,45] type:#float

		button autoEdgeButton "Auto Edge" width:120 height:24

		on autoEdgeButton pressed do (
			for item in selection where classOf item == Editable_mesh do (
				if splitMaterialsCheckbox.checked then (
					local materials
					local faces

					MAXLancer.GetMeshMaterials item &materials &faces

					for i = 1 to faces.count do (
						local edges = meshop.getEdgesUsingFace target faces[i]
						
						meshop.autoEdge target edges angleSpinner.value type:#SetClear
						meshop.autoEdge target (edges + meshop.getEdgesReverseEdge target edges) * (-edges + meshop.getEdgesReverseEdge target -edges) 0 type:#Set
					)
	
					update target
				)
			)
		)
	)

	on execute do if MAXLancer != undefined then CreateDialog AutoEdgePlusRollout else messageBox "MAXLancer is not initialized."
)