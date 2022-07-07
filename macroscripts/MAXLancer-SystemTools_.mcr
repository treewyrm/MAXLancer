/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Copy select objects into clipboard as system INI formatted string of entries
 */
macroscript SystemTools category:"MAXLancer" tooltip:"System Tools" buttontext:"System Tools" iconName:"MAXLancer/toolbar" (
	global MAXLancer

	rollout SystemToolsRollout "System Tools" width:220 height:340 (

		checkbox integerValues "Integer Values" tooltip:"Round output values to integer numbers" checked:true

		checkbox positionValues "Object Position" checked:true tooltip:"Copy object position"
		checkbox rotationValues "Object Rotation" checked:true tooltip:"Copy object rotation"
		checkbox userProperties "Copy User Properties" checked:true tooltip:"Copies user-defined object properties"

		button copyButton "Copy to Clipboard" width:120 height:24


		fn exportObject target result = (
			format "[Object]\nnickname = %\n" target.name to:result

			OK
		)

		fn exportLight target result = (
			format "[LightSource]\nnickname = %\n" target.name to:result

			OK
		)

		fn exportZone target result = (
			local scaling = target.transform.scalepart

			format "[Zone]\nnickname = %\n" target.name to:result

			OK
		)

		on copyButton pressed do if selection.count > 0 then (
			local result = StringStream ""
			local position
			local rotation

			in coordsys global for target in selection do (
				position = target.transform.translationpart
				rotation = target.transform as eulerAngles


				if integerValues.checked then (
					position = [position.x as Integer, position.y as Integer, position.z as Integer]
					rotation = eulerAngles (rotation.x as Integer) (rotation.y as Integer) (rotation.z as Integer)
				)

				format "[object]\nnickname = %\n" target.name to:result

				if positionValues.checked then format "pos = %, %, %\n" data.x data.z -data.y to:result
				if rotationValues.checked then format "rot = %, %, %\n" data.x data.y data.z to:result

				append result "\n"
			)

			OK
		) else messageBox "Select objects to parse into INI" beep:false

	)

	on execute do if MAXLancer != undefined then CreateDialog SystemToolsRollout else messageBox "MAXLancer is not initialized."
)