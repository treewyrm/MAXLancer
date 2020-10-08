/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Import animation script
 */
macroscript ExportAnimations category:"MAXLancer" tooltip:"Export Animations" buttontext:"Export Animations" iconName:"MAXLancer/export_animations" (
	global MAXLancer

	local target

	rollout ExportAnimationsRollout "Export Animations" width:352 height:476 (

		dotNetControl treeBox "System.Windows.Forms.TreeView" pos:[8, 8] width:336 height:416 align:#left

		checkbox quantizeQuatsCheckbox "Quaternion Basic-HA Quantization" pos:[8,432] width:184 height:16 tooltip:"Animations for deformable models use quaternion quantization."
		button exportButton "Export Animations" pos:[200,444] width:144 height:24

		on exportButton pressed do (


		)

		on ExportAnimationsRollout open do (


		)
	)

	on execute do if MAXLancer != undefined then (

	) else messageBox "MAXLancer is not initialized."
)