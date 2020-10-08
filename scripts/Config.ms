/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * INI configuration routines.
 */

struct INIConfig (
	filename,

	-- Load value from configuration
	fn LoadProperty section property type: default:undefined = (
		local value = getINISetting filename section property
		
		if value == "" then default else try (
			case type of (
				#boolean: value as BooleanClass
				#number: value as Number
				#strings: FilterString value " "
				#numbers: for v in FilterString value " " collect v as Number
				#point2: (
					values = LoadProperty section property type:#numbers
					if values.count == 2 then Point2 values[1] values[2]
				)
				#rgb: (
					values = LoadProperty section property type:#numbers
					if values.count == 3 then Color values[1] values[2] values[3]
				)
				default: value
			)
		) catch (
			value = default
		)
	),

	-- Save value into configuration
	fn SaveProperty section property value = (
		local valueOutput = StringStream ""

		case classOf value of (
			Point2: format "% %" value.x value.y to:valueOutput
			Point3: format "% % %" value.x value.y value.z to:valueOutput
			Color: format "% % %" (value.r as Integer) (value.g as Integer) (value.b as Integer) to:valueOutput
			default: valueOutput = value as String
		)

		setINISetting filename section property valueOutput
		OK
	),

	-- Load controls values (typically for Rollouts) from config section
	fn LoadControls section controls = (
		for control in controls do (
			type = case classOf control of (
				CheckBoxControl: #boolean
				EditTextControl: #string
				RadioControl: #number
				ColorPickerControl: #rgb
			)

			if type != undefined and (value = LoadProperty section control.name type:type) != undefined then case classOf control of (
				CheckBoxControl:    control.state = value
				EditTextControl:    control.text  = value
				RadioControl:       control.state = value
				ColorPickerControl: control.color = value
			)
		)
		OK
	),

	-- Save certain control values into configuration section
	fn SaveControls section controls = (
		for control in controls do if (value = case classOf control of (
				CheckBoxControl:    control.state
				EditTextControl:    control.text
				RadioControl:       control.state
				ColorPickerControl: control.color
			)
		) != undefined then SaveProperty section control.name value
		OK
	),

	fn SetDialogSize target size = (
		if classOf target != RolloutClass then throw "Invalid rollout class target"
		if classOf size != Point2 then throw "Invalid size point class"

		target.width size.x
		target.height size.y
		OK
	),

	fn LoadRollout target default:[40, 40] position:true size:false controls:#all = (
		if classOf target != RolloutClass then throw "Invalid rollout class target"

		if controls == #all then controls = target.controls
		if position and target.inDialog then SetDialogPos target (LoadProperty target.name "position" type:#point2 default:default)
		if size and target.inDialog then SetDialogSize target (LoadProperty target.name "size" type:#point2)
		if controls.count > 0 then LoadControls target.name controls
		OK

		SetDialog
	),

	fn SaveRollout target position:true size:false controls:#all = (
		if classOf target != RolloutClass then throw "Invalid rollout class target"

		if controls == #all then controls = target.controls
		if position and target.inDialog then SaveProperty target.name "position" (GetDialogPos target)
		if size and target.inDialog then SaveProperty target.name "size" (GetDialogSize target)
		if controls.count > 0 then SaveControls target.name controls
		OK
	)
)