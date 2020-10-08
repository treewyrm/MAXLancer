/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Attachment joints used both by compound rigid and deformable models.
 */

-- Compound model part constraint (used both by RigidCompound and DeformableCompound)
struct PartConstraint (
	parent, -- RigidPart/DeformablePart
	child,  -- RigidPart/DeformablePart
	joint   -- JointFixed/JointRevolute/JointPrismatic/JointCylindric/JointSpheric/JointLoose
)

-- Fixed joint (no animation)
struct JointFixed (
	transform = Matrix3 1,

	fn ReadStream stream = (
		ReadTranslationPart stream transform
		ReadRotationPart    stream transform
		OK
	),

	fn WriteStream stream = (
		WriteTranslationPart stream transform
		WriteRotationPart    stream transform
		OK
	)
)

-- Revolute (rotating) joint by axis modifier between min/max (animation key: float)
struct JointRevolute (
	transform = Matrix3 1,
	offset    = [0, 0, 0],
	axis      = [0, 0, 0],
	turn      = [0, 0],

	fn ReadStream stream = (
		ReadTranslationPart stream transform
		ReadPosition        stream offset
		ReadRotationPart    stream transform
		ReadPosition        stream axis

		turn.x = radToDeg (ReadFloat stream)
		turn.y = radToDeg (ReadFloat stream)
		OK
	),

	fn WriteStream stream = (
		WriteTranslationPart stream transform
		WritePosition        stream offset
		WriteRotationPart    stream transform
		WritePosition        stream axis

		WriteFloat stream (degToRad turn.x)
		WriteFloat stream (degToRad turn.y)
		OK
	)
)

-- Prismatic (sliding) joint by axis modifier between min/max (animation key: float)
struct JointPrismatic (
	transform = Matrix3 1,
	offset    = [0, 0, 0],
	axis      = [0, 0, 0],
	slide     = [0, 0],

	fn ReadStream stream = (
		ReadTranslationPart stream transform
		ReadPosition        stream offset
		ReadRotationPart    stream transform
		ReadPosition        stream axis

		slide.x = ReadFloat stream
		slide.y = ReadFloat stream
		OK
	),

	fn WriteStream stream = (
		WriteTranslationPart stream transform
		WritePosition        stream offset
		WriteRotationPart    stream transform
		WritePosition        stream axis

		WriteFloat stream slide.x
		WriteFloat stream slide.y
		OK
	)
)

-- Cylindric (rotating and sliding) joint (shared axis modifier, but separate min/max for prismatic/revolute) (animation key: two floats?)
struct JointCylindric (
	transform = Matrix3 1,
	offset    = [0, 0, 0],
	axis      = [0, 0, 0],
	turn      = [0, 0],
	slide     = [0, 0],

	fn ReadStream stream = (
		ReadTranslationPart stream transform
		ReadPosition        stream offset
		ReadRotationPart    stream transform
		ReadPosition        stream axis

		turn.x  = radToDeg (ReadFloat stream)
		turn.y  = radToDeg (ReadFloat stream)
		slide.x = ReadFloat stream
		slide.y = ReadFloat stream
		OK
	),

	fn WriteStream stream = (
		WriteTranslationPart stream transform
		WritePosition        stream offset
		WriteRotationPart    stream transform
		WritePosition        stream axis

		WriteFloat stream (degToRad turn.x)
		WriteFloat stream (degToRad turn.y)
		WriteFloat stream slide.x
		WriteFloat stream slide.y
		OK
	)
)

-- Spherical joint between min/max quaternions (animation key: Quat
struct JointSpheric (
	transform = Matrix3 1,
	offset    = [0, 0, 0],
	pitch     = [0, 0],
	yaw       = [0, 0],
	roll      = [0, 0],

	fn ReadStream stream = (
		ReadTranslationPart stream transform
		ReadPosition        stream offset
		ReadRotationPart    stream transform

		pitch.x = radToDeg (ReadFloat stream)
		pitch.y = radToDeg (ReadFloat stream)
		yaw.x   = radToDeg (ReadFloat stream)
		yaw.y   = radToDeg (ReadFloat stream)
		roll.x  = radToDeg (ReadFloat stream)
		roll.y  = radToDeg (ReadFloat stream)
		OK
	),

	fn WriteStream stream = (
		WriteTranslationPart stream transform
		WritePosition        stream offset
		WriteRotationPart    stream transform

		WriteFloat stream (radToDeg pitch.x)
		WriteFloat stream (radToDeg pitch.y)
		WriteFloat stream (radToDeg yaw.x)
		WriteFloat stream (radToDeg yaw.y)
		WriteFloat stream (radToDeg roll.x)
		WriteFloat stream (radToDeg roll.y)
		OK
	)
)

-- Loose joint (animation key: Point3 and Quat)
struct JointLoose (
	transform = Matrix3 1,

	fn ReadStream stream = (
		ReadTranslationPart stream transform
		ReadRotationPart    stream transform
		OK
	),

	fn WriteStream stream = (
		WriteTranslationPart stream transform
		WriteRotationPart    stream transform
		OK
	)
)

-- Read constraints of specific archetype from UTF entry
fn ReadConstraintsType reader constraints parts archetype filename = (
	local limit  -- File end offset
	local parent -- Parent name
	local child  -- Child name
	local item   -- New PartConstraint

	if reader.OpenFile filename then (
		limit = reader.size + ftell reader.data

		while ftell reader.data < limit do (
			parent = ReadCharsFixed reader.data 64
			child  = ReadCharsFixed reader.data 64
			item   = PartConstraint joint:(archetype())

			MAXLancer.WriteLog ("Reading constraint: " + child + " in " + parent)

			item.joint.ReadStream reader.data

			for part in parts while item.parent == undefined or item.child == undefined do (
				if stricmp part.name parent == 0 then item.parent = part
				if stricmp part.name child  == 0 then item.child  = part
			)

			if item.parent == undefined then throw ("Constraint has no matching parent part: " + parent)
			if item.child  == undefined then throw ("Constraint has no matching child part: " + child)

			append constraints item
		)
	)

	OK
)

-- Read constraints from UTF folder (typically Cmpnd)
fn ReadConstraints reader parts constraints = (
	if classOf reader != UTFReader then throw "Invalid UTFReader object."
	if classOf parts != Array then throw "Invalid parts array."
	if classOf constraints != Array then throw "Invalid constraints array."

	if reader.OpenFolder "Cons" then (
		ReadConstraintsType reader constraints parts JointFixed     "Fix"
		ReadConstraintsType reader constraints parts JointRevolute  "Rev"
		ReadConstraintsType reader constraints parts JointPrismatic "Pris"
		ReadConstraintsType reader constraints parts JointCylindric "Cyl"
		ReadConstraintsType reader constraints parts JointSpheric   "Sphere"
		ReadConstraintsType reader constraints parts JointLoose     "Loose"

		reader.CloseFolder() -- Close "Cons"
	)

	OK
)

-- Write constraints of specific archetype into UTF entry
fn WriteConstraintsType writer constraints archetype filename = (
	local items = for constraint in constraints where classOf constraint.joint == archetype collect constraint

	if items.count > 0 then (
		if not writer.OpenFile filename then throw ("Unable to open file " + filename)

		for item in items do (
			MAXLancer.WriteLog ("Writing constraint: " + item.parent.name + " to " + item.child.name)

			WriteCharsFixed writer.data item.parent.name 64
			WriteCharsFixed writer.data item.child.name  64
			item.joint.WriteStream writer.data

		)

		writer.CloseFile() -- Close filename
	)

	OK
)

-- Write constraints into UTF folder
fn WriteConstraints writer constraints = (
	if classOf writer != UTFWriter then throw "Invalid UTFWriter object."
	if classOf constraints != Array then throw "Invalid constraints array."

	-- Compound model with only a root part will not have any constraints either
	writer.OpenFolder "Cons"
	MAXLancer.WriteLog "Writing constraints"
	
	WriteConstraintsType writer constraints JointFixed     "Fix"
	WriteConstraintsType writer constraints JointRevolute  "Rev"
	WriteConstraintsType writer constraints JointPrismatic "Pris"
	WriteConstraintsType writer constraints JointCylindric "Cyl"
	WriteConstraintsType writer constraints JointSpheric   "Sphere"
	WriteConstraintsType writer constraints JointLoose     "Loose"

	writer.CloseFolder() -- Close Cons
	OK
)

-- Read compound part properties from UTF folder
fn ReadCompoundPart reader archetype = (
	local name     = reader.ReadFileString  "Object name"
	local index    = reader.ReadFileInteger "Index" #unsigned
	local filename = reader.ReadFileString  "File name"

	if name == undefined then throw "Part is missing Object name."
	if index == undefined then throw "Part is missing Index."
	if filename == undefined then throw "Part is missing File name."

	-- Part StructDef is expected to have name, index and filename properties
	/*
	if not isProperty archetype #name     then throw "Part archetype is missing name property."
	if not isProperty archetype #index    then throw "Part archetype is missing index property."
	if not isProperty archetype #filename then throw "Part archetype is missing filename property."
	*/
	
	archetype name:name filename:filename index:index -- Return *Part
)

-- Read compound parts from UTF folders
fn ReadCompoundParts reader parts archetype = (
	local root

	-- Read root part
	if reader.OpenFolder "Root" then (
		MAXLancer.WriteLog "Reading root part"
		append parts (root = ReadCompoundPart reader archetype)
		reader.CloseFolder() -- Close Root
	)

	-- Read other parts
	for filename in reader.GetFolders() where MatchPattern filename pattern:"Part*" ignoreCase:true and reader.OpenFolder filename do (
		MAXLancer.WriteLog ("Reading part: " + filename)
		append parts (ReadCompoundPart reader archetype)
		reader.CloseFolder() -- Close Part*
	)

	-- First part becomes root if root is not explicitly specified
	if root == undefined and parts.count > 0 then root = parts[1]

	root -- Return root part
)

-- Read compound hierarchy from UTF folder (Cmpnd)
fn ReadCompound reader constraints archetype &scaler: = (
	if classOf reader != UTFReader then throw "Invalid UTFReader object."
	if classOf constraints != Array then throw "Invalid constraints array object."
	if classOf archetype != StructDef then throw "Invalid part archetype object."

	local parts = #() -- Array of *Part (includes root)
	local root        -- Root part

	if not reader.OpenFolder "Cmpnd" then throw "Compound model is missing Cmpnd."
	MAXLancer.WriteLog "Reading compound hierarchy"

	if scaler != unsupplied then scaler = reader.ReadFileFloat "Scale"
	if (root = ReadCompoundParts reader parts archetype) == undefined then throw "Compound model has no root part."		
		
	constraints.count = 0 -- Reset constraints

	ReadConstraints reader parts constraints
	if parts.count - 1 != constraints.count then throw "Invalid number of constraints."

	reader.CloseFolder() -- Close Cmpnd

	-- Read part fragments
	for part in parts do (
		if not reader.OpenFolder part.filename then throw ("Compound model part " + part.name + " is missing fragment: " + part.filename)

		part.ReadUTF reader
		reader.CloseFolder() -- Close filename
	)

	root -- Return root part
)

-- Write compound part properties into UTF folder
fn WriteCompoundPart writer part = (
	if not hasProperty part #name     then throw "Part object is missing name property."
	if not hasProperty part #index    then throw "Part object is missing index property."
	if not hasProperty part #filename then throw "Part object is missing filename property."

	if classOf part.name != string then throw "Invalid part name type."
	if classOf part.index != integer then throw "Invalid part index type."
	if classOf part.filename != string then throw "Invalid part filename type."

	writer.WriteFileString  "Object name" part.name
	writer.WriteFileInteger "Index"       part.index #unsigned
	writer.WriteFileString  "File name"   part.filename
	OK
)

-- Write compound parts into UTF folders
fn WriteCompoundParts writer parts = (

	-- Write subparts first
	for p = 2 to parts.count do (
		if not writer.OpenFolder ("Part_" + parts[p].name) then throw ("Unable to create Part_" + parts[p].name + " folder.")
		WriteCompoundPart writer parts[p]
		writer.CloseFolder() -- Close Part_*
	)

	-- Write root last
	if not writer.OpenFolder "Root" then throw "Unable to create Root folder."
	WriteCompoundPart writer parts[1]
	writer.CloseFolder() -- Close Root

	OK
)

-- Write compound hierarchy data into UTF folder (Cmpnd)
fn WriteCompound writer root constraints scaler: timestamps:true = (
	if classOf writer != UTFWriter then throw "Invalid UTFWriter object."
	if classOf constraints != Array then throw "Invalid constraints array object."

	-- Timestamp suffix for embedded .3db filenames
	local suffix = if timestamps then CreateFragmentTimeStamp() else ""

	if not writer.OpenFolder "Cmpnd" then throw "Unable to create Cmpnd folder."
	MAXLancer.WriteLog "Writing compound hierarchy"

	if scaler != unsupplied then reader.WriteFileFloat "Scale" scaler

	if constraints.count > 0 then WriteConstraints writer constraints

	-- Set filename in root
	root.filename = GetFilenameFile writer.filename + suffix + ".3db"

	local parts = #(root) -- Array of *Part (includes root)

	-- Set filename in subparts
	for constraint in constraints do (
		constraint.child.filename = constraint.child.name + suffix + ".3db"
		append parts constraint.child
	)

	-- Write root and subparts
	WriteCompoundParts writer parts

	writer.CloseFolder() -- Close Cmpnd

	-- Write parts
	for part in parts do (
		if not writer.OpenFolder part.filename then throw ("Unable to create part " + part.name + " folder: " + part.filename)

		part.WriteUTF writer
		writer.CloseFolder() -- Close filename
	)

	OK
)

-- Get all valid compound parts by walking through hierarchy
fn GetCompoundParts root constraints = (
	if classOf constraints != Array then throw "Invalid constraints array type."

	local result = #(root)
	local queue  = makeUniqueArray (for constraint in constraints where constraint.parent == root collect constraint.child)
	local child

	while queue.count > 0 do (
		child = queue[queue.count]
		queue.count = queue.count - 1

		if appendIfUnique result child then for constraint in constraints where constraint.parent == child do appendIfUnique queue constraint.child
	)

	result -- Array of parts
)

-- Get children of compound part
fn GetCompoundPartChildren part constraints = (
	if classOf constraints != Array then throw "Invalid constraints array type."
	for constraint in constraints where constraint.parent == part collect constraint.child -- Return array of parts
)

-- Get parent of compound part
fn GetCompoundPartParent part constraints = (
	local result
	for constraint in constraints while result == undefined where constraint.child == part do result = constraint.parent
	result -- Parent part
)

fn GetCompoundPartJoint part constraints = (
	local result
	for constraint in constraints while result == undefined where constraint.child == part do result = constraint.joint
	result -- Part joint
)

-- Find compound part by name/ID
fn GetCompoundPartByID root constraints id = (
	id = MAXLancer.Hash id

	local result
	for part in GetCompoundParts root constraints while result == undefined where MAXLancer.Hash part.name == id do result = part
	result -- Return matching part
)

-- Find compound hardpoint by name/ID
fn GetComoundHardpointByID root constraints id = (
	id = MAXLancer.Hash id

	local result
	for part in GetCompoundParts root constraints while result == undefined do for hardpoint in part.hardpoints while result == undefined where MAXLancer.Hash hardpoint.name == id do result = hardpoint
	result -- Return matching hardpoint
)

-- Applies joint as custom controller to target node
fn SetCompoundJoint target joint = (
	if not isValidNode target then throw "Invalid joint target node object."

	local controller = target.transform.controller = case classOf joint of (
		JointFixed:     FixedJointController()
		JointRevolute:  AxisJointController type:1 axis:joint.axis offset:joint.offset turnMin:joint.turn.x turnMax:joint.turn.y
		JointPrismatic: AxisJointController type:2 axis:joint.axis offset:joint.offset slideMin:joint.slide.x slideMax:joint.slide.y
		JointCylindric: AxisJointController type:3 axis:joint.axis offset:joint.offset turnMin:joint.turn.x turnMax:joint.turn.y slideMin:joint.slide.x slideMax:joint.slide.y
		JointSpheric:   SphericJointController offset:joint.offset pitchMin:joint.pitch.x pitchMax:joint.pitch.y yawMin:joint.yaw.x yawMax:joint.yaw.y rollMin:joint.roll.x rollMax:joint.roll.y
		JointLoose:     LooseJointController()
		default: throw ("Invalid joint controller for object: " + target.name)
	)

	case classOf controller of (
		SphericJointController: (
			controller.position       = joint.transform.translationpart
			controller.rotation.value = joint.transform.rotationpart
		)
		LooseJointController: (
			controller.position.value = joint.transform.translationpart
			controller.rotation.value = joint.transform.rotationpart
		)
		default: controller.origin = joint.transform
	)

	OK
)

-- Reads custom controller from target into joint
fn GetCompoundJoint target approximation:10 root:false = (
	if not isValidNode target then throw "Invalid joint target node object."

	if target.objectOffsetPos != [0, 0, 0] then throw ("Part node \"" + target.name + "\" has invalid object offset position: " + target.objectOffsetPos)
	if target.objectOffsetScale != [1, 1, 1] then throw ("Part node \"" + target.name + "\" has invalid object offset scale: " + target.objectOffsetScale)
	if not isIdentity target.objectOffsetRot then throw ("Part node \"" + target.name + "\" has invalid object offset rotation: " + target.objectOffsetRot)

	-- Create compound joint from controller
	local controller = target.transform.controller
	local joint = case classOf controller of (
		FixedJointController: JointFixed()
		AxisJointController: (
			case controller.type of (
				1: JointRevolute  axis:controller.axis offset:controller.offset turn:[controller.turnMin, controller.turnMax]
				2: JointPrismatic axis:controller.axis offset:controller.offset slide:[controller.slideMin, controller.slideMax]
				3: JointCylindric axis:controller.axis offset:controller.offset turn:[controller.turnMin, controller.turnMax] slide:[controller.slideMin, controller.slideMax]
			)
		)
		SphericJointController: JointSpheric offset:controller.offset pitch:[controller.pitchMin, controller.pitchMax] yaw:[controller.yawMin, controller.yawMax] roll:[controller.rollMin, controller.rollMax]
		LooseJointController: JointLoose()
		default: if root then JointLoose() else JointFixed()
	)

	-- Read position/rotation for joint
	joint.transform = case classOf controller of (
		SphericJointController: translate (controller.rotation.value as matrix3) controller.position
		LooseJointController:   translate (controller.rotation.value as matrix3) controller.position.value
		AxisJointController:    controller.origin
		FixedJointController:   controller.origin
		default:                target.transform
	)
	
	local scalepart = joint.transform.scalepart
	if not (close_enough scalepart.x 1.0 approximation and close_enough scalepart.y 1.0 approximation and close_enough scalepart.z 1.0 approximation) then throw ("Part node \"" + target.name + "\" has invalid transform scaling: " + scalepart)

	joint -- Return *Joint
)

struct CompoundPart (
	transform, -- Matrix3
	parent,    -- Result from previous step
	child,     -- RigidPart/DeformablePart
	joint      -- *joint (undefined for root)
)

struct CompoundIterator (
	root,                    -- Root part of hierarchy (RigidPart/DeformablePart)
	origin      = Matrix3 1, -- Origin transformation for root part
	constraints = #(),       -- Array of PartConstraint containing list of parent/child relation making up compound hierarchy
	queue       = #(),       -- Array of CompoundPart to be pushed into current on next iteration
	current,                 -- Current part from compound hierarchy (CompountPart)
	parent,                  -- Current part processing result (usually a helper object)

	on create do if queue.count == 0 then append queue (CompoundPart child:root transform:origin),

	-- Advance iterator to next part in compound hierarchy
	fn Next = (
		if classOf current == CompoundPart then
			for constraint in constraints where classOf constraint == PartConstraint and constraint.parent == current.child do
				append queue (CompoundPart parent:parent child:constraint.child joint:constraint.joint transform:(constraint.joint.transform * current.transform))

		parent = undefined

		if queue.count == 0 then false else (
			current = queue[queue.count]
			queue.count = queue.count - 1
			true
		)
	)
)

struct ScenePart (
	parent, -- Result from previous step (RigidPart/DeformablePart)
	child   -- RigidPartHelper/etc
)

struct SceneIterator (
	root,        -- Root part of hierarchy (RigidPartHelper/etc)
	queue = #(), -- Array of ScenePart
	current,     -- Current part from scene hierarchy (ScenePart)
	parent,      -- Current part processing result (RigidPart)

	on create do if queue.count == 0 then append queue (ScenePart child:root),

	fn Next = (
		if classOf current == ScenePart then
			for child in current.child.children where classOf child == classOf current.child do
				append queue (ScenePart parent:parent child:child)

		parent = undefined

		if queue.count == 0 then false else (
			current = queue[queue.count]
			queue.count = queue.count - 1
			true
		)
	)
)