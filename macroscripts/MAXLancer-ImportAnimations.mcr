/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Import animation script
 */
macroscript ImportAnimations category:"MAXLancer" tooltip:"Import Animations" buttontext:"Import Animations" iconName:"MAXLancer/import_animations" (
	global MAXLancer

	local filename
	local root

	rollout ImportAnimationRollout "Import Animation" width:440 height:392 (
		local reader  -- UTFReader
		local library -- AnimationLibrary

		edittext filenameText "Filename:" pos:[8,12] width:424 height:17 readOnly:true align:#left
		dotNetControl scriptListView "System.Windows.Forms.ListView" pos:[8,40] width:424 height:312 align:#left

		checkBox autosizeTimeCheckbox "Auto-time" pos:[8,356] height:16 tooltip:"Extends to time track to maximum of used animation time."
		button importButton "Import Animations" pos:[288,360] height:24 width:144 align:#left

		on importButton pressed do (
			local filenames = for i = 1 to scriptListView.CheckedIndices.Count collect (scriptListView.Items.Item (scriptListView.CheckedIndices.Item (i - 1))).Text

			if filenames.count > 0 and isValidNode root then (
				reader.Open filename
				library.ReadUTF reader filter:filenames
				reader.Close()

				library.Build root attached:true deformable:(classOf root == BoneGeometry)

				DestroyDialog ImportAnimationRollout
			)
		)

		on ImportAnimationRollout open do (
			reader  = MAXLancer.CreateUTFReader()
			library = MAXLancer.CreateAnimationLibrary()
			
			scriptListView.BackColor   = MAXLancer.GetNetColorMan #window
			scriptListView.ForeColor   = MAXLancer.GetNetColorMan #windowText
			scriptListView.View        = (dotNetClass "System.Windows.Forms.View").Details
			-- scriptListView.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").None
			scriptListView.CheckBoxes  = true
			scriptListView.GridLines   = false
			
			scriptListView.columns.Add "Name" (scriptListView.width)
			scriptListView.columns.Add "Duration" 80

			try (
				local items = #()

				filenameText.text = filename
				
				reader.Open filename
				if not reader.OpenFolder "Animation" then throw "File does not contain Animation."
				if not reader.OpenFolder "Script" then throw "File does not contain animation scripts."
					
				for filename in reader.GetFolders() do append items (dotNetObject "System.Windows.Forms.ListViewItem" filename)
				
				reader.Close() -- Just close, no need to keep it open

				scriptListView.items.AddRange items
				scriptListView.Update()
			) catch (
				DestroyDialog ImportAnimationRollout
				messageBox (getCurrentException())
				-- throw()
			)
		)
	)

	fn RootFilter target = isValidNode target and classOf target.transform.controller == MAXLancer.LooseJointController

	on execute do if MAXLancer != undefined then (
		root = MAXLancer.PickSceneObject RootFilter

		if root != undefined then (
			filename = getOpenFileName caption:"Import Freelancer Animations:" types:"Animation Library (.anm)|*.anm|Compound Model (.cmp)|*.cmp|"

			if filename != undefined and doesFileExist filename then CreateDialog ImportAnimationRollout
		)
	) else messageBox "MAXLancer is not initialized."
)