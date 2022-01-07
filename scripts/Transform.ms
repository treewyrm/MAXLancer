/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 * 
 * Transform controller for compound parts
 *
 * Cyl (cylindric) exists in code but doesn't seem to work, potentially requires undetermined flags
 * in animation header.
 */

plugin TransformController HardpointLinkController name:"Hardpoint Link" classID:#(0x4C58414D, 0x6B6C7968) (
	
	parameters HardpointLinkParameters rollout:HardpointLinkRollout (
		origin  type:#matrix3 animatable:false
		offset  type:#matrix3 animatable:false
		target  type:#node    animatable:false ui:targetPicker
		preview type:#boolean animatable:false ui:previewButton
	)

	rollout HardpointLinkRollout "Hardpoint Link Parameters" (

		fn FilterHardpoint target = classOf target == HardpointHelper

		label sourceLabel "Source Hardpoint:"
		button offsetPickButton "Pick" message:"Select source hardpoint." width:72 height:24 across:2
		button offsetResetButton "Reset" width:72 height:24

		label targetLabel "Target Hardpoint:"
		pickbutton targetPicker "Pick Hardpoint" message:"Select target hardpoint." width:128 height:24 filter:FilterHardpoint autoDisplay:true

		checkbutton previewButton "Preview" width:88 height:24

		on offsetPickButton pressed do (
			local previewPrevious = preview
			preview = false

			local hardpoint = pickObject message:"Select source hardpoint." filter:FilterHardpoint
			if hardpoint != undefined then offset = hardpoint.transform * inverse origin
			preview = previewPrevious
		)

		on offsetResetButton pressed do offset = matrix3 1
	)

	on getValue do if preview and isValidNode target then inverse offset * target.transform else origin

	on setValue absolute relative commit do if not preview then origin = absolute

	on create do (
		isLeaf = false
		isKeyable = false
	)
)

-- Fixed joint transform is just that, has no animation support (Fix).
plugin TransformController FixedJointController name:"Fixed Joint" classID:#(0x4C58414D, 0x64786966) (

	parameters FixedJointParameters (
		origin type:#matrix3
	)

	on getValue do origin
	on setValue absolute relative commit do origin = absolute

	on create do (
		isLeaf = true
		isKeyable = false
	)
)

-- Fixed axis joint (Rev/Pris/Cyl)
plugin TransformController AxisJointController name:"Axis Joint" classID:#(0x4C58414D, 0x73697861) (
	
	local IsOpenRollout = false
	local result = matrix3 1

	parameters AxisJointParameters rollout:AxisJointRollout (
		origin type:#matrix3

		type type:#integer animatable:false ui:typeList default:1

		axis  type:#point3 animatable:false default:[1, 0, 0]
		slide type:#float animatable:true ui:slideSpinner
		turn  type:#float animatable:true ui:turnSpinner

		slideMin type:#float animatable:false ui:slideMinSpinner
		slideMax type:#float animatable:false ui:slideMaxSpinner

		turnMin type:#float animatable:false ui:turnMinSpinner
		turnMax type:#float animatable:false ui:turnMaxSpinner

		-- Offset is applicable only to Rev and Cyl (?)
		offset type:#point3 animatable:false default:[0, 0, 0]

		on axis set result do (
			if IsOpenRollout then (
				this.AxisJointRollout.axis_XSpinner.value = result.x
				this.AxisJointRollout.axis_YSpinner.value = result.y
				this.AxisJointRollout.axis_ZSpinner.value = result.z 
			)
		)

		on offset set result do (
			if IsOpenRollout then (
				this.AxisJointRollout.offset_XSpinner.value = result.x
				this.AxisJointRollout.offset_YSpinner.value = result.y
				this.AxisJointRollout.offset_ZSpinner.value = result.z
			)
		)
	)

	rollout AxisJointRollout "Axis Joint Parameters" (
		dropdownlist typeList "Type" items:#("Revolute", "Prismatic", "Cylindric")

		group "Revolute" (
			spinner turnSpinner    "Turn" type:#float range:[-3.4e38, 3.4e38, 0] fieldwidth:80
			spinner turnMinSpinner "Min"  type:#float range:[-3.4e38, 3.4e38, 0] fieldwidth:80
			spinner turnMaxSpinner "Max"  type:#float range:[-3.4e38, 3.4e38, 0] fieldwidth:80
		)

		group "Prismatic" (
			spinner slideSpinner    "Slide" type:#float range:[-3.4e38, 3.4e38, 0] fieldwidth:80
			spinner slideMinSpinner "Min"   type:#float range:[-3.4e38, 3.4e38, 0] fieldwidth:80
			spinner slideMaxSpinner "Max"   type:#float range:[-3.4e38, 3.4e38, 0] fieldwidth:80
		)

		group "Axis" (
			spinner axis_XSpinner "X" type:#float range:[-1, 1, 0] fieldwidth:80
			spinner axis_YSpinner "Y" type:#float range:[-1, 1, 0] fieldwidth:80
			spinner axis_ZSpinner "Z" type:#float range:[-1, 1, 0] fieldwidth:80

			button axisNormalizeButton "Normalize"

			radiobuttons directionType "Local axis:" labels:#("X", "-X", "Y", "-Y", "Z", "-Z") columns:2 default:5
			button alignToTargetButton "Set Local Axis"
		)

		group "Offset" (
			spinner offset_XSpinner "X" type:#float range:[-3.4e38, 3.4e38, 0] fieldwidth:80
			spinner offset_YSpinner "Y" type:#float range:[-3.4e38, 3.4e38, 0] fieldwidth:80
			spinner offset_ZSpinner "Z" type:#float range:[-3.4e38, 3.4e38, 0] fieldwidth:80
		)

		on axis_XSpinner changed result do axis.x = result
		on axis_YSpinner changed result do axis.y = result
		on axis_ZSpinner changed result do axis.z = result

		on offset_XSpinner changed result do offset.x = result
		on offset_YSpinner changed result do offset.y = result
		on offset_ZSpinner changed result do offset.z = result

		on AxisJointRollout open do (
			IsOpenRollout = true

			axis_XSpinner.value = axis.x
			axis_YSpinner.value = axis.y
			axis_ZSpinner.value = axis.z

			offset_XSpinner.value = offset.x
			offset_YSpinner.value = offset.y
			offset_ZSpinner.value = offset.z
		)

		on AxisJointRollout close do IsOpenRollout = false

		on axisNormalizeButton pressed do axis = normalize axis

		fn FilterSource part = classOf part == MAXLancer.RigidPartHelper

		on alignToTargetButton pressed do (
			local dir = case directionType.state of (
				1:  x_axis
				2: -x_axis
				3:  y_axis
				4: -y_axis
				5:  z_axis
				6: -z_axis
			)
			
			local target = selection[1]
			if classOf target.parent == classOf target then axis = dir * target.transform.rotationpart * inverse target.parent.transform.rotationpart

			/*
			local source = pickObject message:"Pick source part" count:1 filter:FilterSource

			if source != undefined then (
				local target = pickObject message:"Pick target part" count:1 filter:FilterSource rubberBand:source.transform.translationpart
				if target != undefined then axis = dir * source.transform.rotationpart * inverse target.transform.rotationpart
			)
			*/
		)
	)

	-- Get turn value constrained to min/max values
	fn getTurn = amin (amax turn turnMin) turnMax

	-- Get slide value constrained to min/max values
	fn getSlide = amin (amax slide slideMin) slideMax

	on getValue do (
		result = case type of (
			1: preTranslate (translate ((origin.rotationpart * (quat (getTurn()) -axis)) as matrix3) (origin.translationpart)) -offset
			2: translate (origin.rotationpart as matrix3) (origin.translationpart + (getSlide()) * axis)
			3: preTranslate (translate ((origin.rotationpart * (quat (getTurn()) -axis)) as matrix3) (origin.translationpart + (getSlide()) * axis)) -offset
		)
	)

	on setValue absolute relative commit do origin = inverse (result * inverse origin) * absolute
 
	on create do (
		isLeaf = false
		isKeyable = false
		usesParentTransform = true
		
		slide.controller = linear_float()
		turn.controller  = linear_float()
	)
)

-- Rotation joint (Sphere). Typically used in deformable models.
plugin TransformController SphericJointController name:"Spheric Joint" classID:#(0x4C58414D, 0x72687073) (

	local IsOpenRollout = false

	parameters SphericalJointParameters rollout:SphericalJointRollout (
		position type:#point3 animatable:false default:[0, 0, 0]
		offset type:#point3 animatable:false default:[0, 0, 0]

		rotation type:#maxObject subAnim:true

		pitchMin type:#float animatable:false ui:pitchMinSpinner
		pitchMax type:#float animatable:false ui:pitchMaxSpinner

		yawMin type:#float animatable:false ui:yawMinSpinner
		yawMax type:#float animatable:false ui:yawMaxSpinner

		rollMin type:#float animatable:false ui:rollMinSpinner
		rollMax type:#float animatable:false ui:rollMaxSpinner

		on offset set result do (
			if IsOpenRollout then (
				this.SphericalJointRollout.offset_XSpinner.value = result.x
				this.SphericalJointRollout.offset_YSpinner.value = result.y
				this.SphericalJointRollout.offset_ZSpinner.value = result.z
			)
		)
	)

	rollout SphericalJointRollout "Spherical Parameters" (
		group "Offset" (
			spinner offset_XSpinner "X" type:#float range:[-3.4e38, 3.4e38, 0]
			spinner offset_YSpinner "Y" type:#float range:[-3.4e38, 3.4e38, 0]
			spinner offset_ZSpinner "Z" type:#float range:[-3.4e38, 3.4e38, 0]
		)

		group "Pitch" (
			spinner pitchMinSpinner "Min" type:#float range:[-3.4e38, 3.4e38, 0]
			spinner pitchMaxSpinner "Max" type:#float range:[-3.4e38, 3.4e38, 0]
		)

		group "Yaw" (
			spinner yawMinSpinner "Min" type:#float range:[-3.4e38, 3.4e38, 0]
			spinner yawMaxSpinner "Max" type:#float range:[-3.4e38, 3.4e38, 0]
		)

		group "Roll" (
			spinner rollMinSpinner "Min" type:#float range:[-3.4e38, 3.4e38, 0]
			spinner rollMaxSpinner "Max" type:#float range:[-3.4e38, 3.4e38, 0]
		)

		on offset_XSpinner changed result do offset.x = result
		on offset_YSpinner changed result do offset.y = result
		on offset_ZSpinner changed result do offset.z = result

		on SphericalJointRollout open do (
			IsOpenRollout = true

			offset_XSpinner.value = offset.x
			offset_YSpinner.value = offset.y
			offset_ZSpinner.value = offset.z
		)

		on SphericalJointRollout close do IsOpenRollout = false
	)

	-- Figure out if offset is preTranslate
	on getValue do translate (rotation.value as matrix3) position

	on setValue absolute relative commit do (
		position = absolute.translationpart
		rotation.value = absolute.rotationpart
	)

	on create do (
		isLeaf = false
		rotation = linear_rotation()
	)
)

-- Position/Rotation joint (Loose). Nearly same as regular PRS controller but lacks scaling. Typically used in deformable models.
plugin TransformController LooseJointController name:"Loose Joint" classID:#(0x4C58414D, 0x65657266) (

	parameters LooseJointParameters (
		position type:#maxObject subAnim:true
		rotation type:#maxObject subAnim:true
	)

	on getValue do translate (rotation.value as matrix3) position.value

	on setValue absolute relative commit do (
		position.value = absolute.translationpart
		rotation.value = absolute.rotationpart
	)

	on create do (
		isLeaf = false

		position = linear_position()
		rotation = linear_rotation()
	)
)
