/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Attachment points used both by rigid and deformable models.
 */
plugin Helper HardpointHelper classID:#(0x4C58414D, 0x64726168) name:"Hardpoint" category:"MAXLancer" extends:dummy replaceUI:true (
	local displayMesh    = TriMesh()
	local hullMesh       = TriMesh()

	local displayUpdated = false
	local hullUpdated    = false
	local IsOpenRollout  = false

	fn GenerateHullMesh hullShape hullSize = (
		if hullShape == 2 or hullShape == 3 then (
			setMesh hullMesh (createInstance box length:hullSize width:hullSize height:hullSize lengthsegs:1 widthsegs:1 heightsegs:1).mesh

			hullMesh.verts[3].pos = [-0.25, 2.5, 0.25] * hullSize
			hullMesh.verts[4].pos = [ 0.25, 2.5, 0.25] * hullSize
			hullMesh.verts[7].pos = [-0.25, 2.5, 0.75] * hullSize
			hullMesh.verts[8].pos = [ 0.25, 2.5, 0.75] * hullSize
			
			if hullShape == 3 then move hullMesh [0, 0, hullSize * -0.5]
		) else if hullShape == 4 then setMesh hullMesh (createInstance sphere radius:hullSize segs:8 hemisphere:0.5 chop:1).mesh
		else if hullShape == 5 then setMesh hullMesh (createInstance cylinder radius:(hullSize * 0.5) height:(hullSize * 0.5) sides:6 heightsegs:1 capsegs:1 slice:false).mesh
		
		update hullMesh
		hullUpdated = true
		OK
	)

	fn GenerateDisplayMesh baseSize arrowSize limitFrom limitTo upAxis = (

		-- If base is zero size shift arrow center to zero as well
		local arrowOffset = if baseSize > 0 then baseSize + arrowSize else 0
		local arrowLength = arrowSize * 3

		local vertices = #([0.0, 0.0, baseSize], [-baseSize, -baseSize, 0.0], [baseSize, -baseSize, 0.0], [baseSize, baseSize, 0.0], [-baseSize, baseSize, 0.0], [0.0, 0.0, 0.0], [0.0, arrowLength, arrowOffset], [-arrowSize, 0.0, arrowOffset], [0.0, 0.0, arrowOffset + arrowSize], [arrowSize, 0.0, arrowOffset], [0.0, 0.0, arrowOffset - arrowSize], [0.0, -arrowSize, arrowOffset])
		local faces    = #([1,2,3], [1,3,4], [1,4,5], [1,5,2], [2,6,3], [3,6,4], [4,6,5], [5,6,2], [7,8,9], [7,9,10], [7,10,11], [7,11,8], [8,12,9], [9,12,10], [10,12,11], [11,12,8])

		-- Limit boundaries to -360, 360 range
		if limitFrom > 0 then limitFrom = 0
		if limitFrom < -360 then limitFrom = -360.0
		if limitTo < 0 then limitTo = 0
		if limitTo > 360 then limitTo = 360.0

		-- Band width and circle radiuses
		local width  = arrowLength * 0.125
		local radius = arrowLength + width * 2
		local innerRadius = radius - width * 0.5
		local outerRadius = radius + width * 0.5
		
		-- Vertex and face setup
		local limitRange  = limitTo - limitFrom
		local startFace   = faces.count
		local startVertex = vertices.count
		local vertexCount = ceil (limitRange / 11.25) * 2 -- 45, 22.5, 11.25
		local faceCount   = 0
		local theta       = limitFrom
		local thetaStep   = limitRange / (vertexCount * 0.5)

		local arcLift     = [0, 0, arrowOffset]
		local sideAxis    = normalize (cross y_axis upAxis)
		local forwardAxis = normalize (cross upAxis sideAxis)
		local axisTM      = Matrix3 sideAxis forwardAxis upAxis [0, 0, 0]

		-- Adds vertices
		for v = 0 to vertexCount by 2 do (
			local x = sin theta
			local y = cos theta

			append vertices ([innerRadius * x, innerRadius * y, 0] * axisTM + arcLift)
			append vertices ([outerRadius * x, outerRadius * y, 0] * axisTM + arcLift)

			-- local r = quat theta axis
			-- append vertices (([0, innerRadius, 0] * r) + [0, 0, arrowOffset])
			-- append vertices (([0, outerRadius, 0] * r) + [0, 0, arrowOffset])

			if v < vertexCount then (
				append faces [startVertex + v + 1, startVertex + v + 3, startVertex + v + 2]
				append faces [startVertex + v + 4, startVertex + v + 2, startVertex + v + 3]
				faceCount += 2
			)
			
			theta += thetaStep
		)

		-- Add notches at ends
		if faceCount > 2 then (
			local notchRadius = outerRadius + width

			append vertices ([notchRadius * sin limitFrom, notchRadius * cos limitFrom, 0] * axisTM + arcLift)
			append vertices ([notchRadius * sin limitTo, notchRadius * cos limitTo, 0] * axisTM + arcLift)

			-- append vertices (([0, notchRadius, 0] * quat limitFrom axis) + [0, 0, arrowOffset])
			-- append vertices (([0, notchRadius, 0] * quat limitTo axis) + [0, 0, arrowOffset])

			append faces [startVertex + 2, startVertex + 2, startVertex + vertexCount + 3]
			append faces [startVertex + vertexCount + 2, startVertex + vertexCount + 4, startVertex + vertexCount + 2]
		)

		setMesh displayMesh vertices:vertices faces:faces

		if faceCount > 0 then for f = 1 to faceCount do setEdgeVis displayMesh (startFace + f) 2 false

		update displayMesh
		displayUpdated = true
		OK
	)
	
	parameters HardpointParameters rollout:HardpointRollout (
		type        type:#integer    animatable:false default:1 ui:typeList
		axis        type:#point3     animatable:false default:[0, 0, 1]
		limitMin    type:#float      animatable:false default:0 ui:limitMinSpinner
		limitMax    type:#float      animatable:false default:0 ui:limitMaxSpinner
		baseSize    type:#worldUnits animatable:false default:1 ui:baseSizeSpinner
		arrowSize   type:#worldUnits animatable:false default:1 ui:arrowSizeSpinner
		hullShape   type:#integer    animatable:false default:1 ui:hullShapeList
		hullSize    type:#float      animatable:false default:1 ui:hullSizeSpinner

		on axis set result do if IsOpenRollout then (
			this.HardpointRollout.axis_XSpinner.value = result.x
			this.HardpointRollout.axis_YSpinner.value = result.y
			this.HardpointRollout.axis_ZSpinner.value = result.z 
		)

		on type       set result do displayUpdated = false
		on limitMin   set result do displayUpdated = false
		on limitMax   set result do displayUpdated = false
		on baseSize   set result do displayUpdated = false
		on arrowSize  set result do displayUpdated = false
		on hullShape  set result do displayUpdated = hullUpdated = false
		on hullSize   set result do hullUpdated = false
	)

	rollout HardpointRollout "Parameters" (
		dropdownlist typeList "Constraint Type" items:#("Fixed", "Revolute", "Prismatic")
		
		group "Axis" (
			spinner axis_XSpinner "X:" type:#float range:[-1, 1, 0]
			spinner axis_YSpinner "Y:" type:#float range:[-1, 1, 0]
			spinner axis_ZSpinner "Z:" type:#float range:[-1, 1, 0]
			button axisNormalizeButton "Normalize" tooltip:"Normalizes axis vector to unit length"
		)

		group "Limits" (
			spinner limitMinSpinner "Min:" type:#float range:[-3.4e38, 3.4e38, 0] scale:0.5
			spinner limitMaxSpinner "Max:" type:#float range:[-3.4e38, 3.4e38, 0] scale:0.5
		)

		group "Helper Display" (
			spinner baseSizeSpinner "Base:" type:#float range:[0, 100, 1]
			spinner arrowSizeSpinner "Arrow:" type:#float range:[0, 100, 1]
		)

		group "Collision Hull" (
			dropdownlist hullShapeList "Shape Type" items:#("None", "Box (Gun)", "Box (Gun Centered)", "Hemisphere (Turret)", "Cylinder (Equipment)")
			spinner hullSizeSpinner "Hull Size:" type:#float range:[0, 100, 1]
		)

		on axis_XSpinner changed result do axis.x = result
		on axis_YSpinner changed result do axis.y = result
		on axis_ZSpinner changed result do axis.z = result

		on axisNormalizeButton pressed do (
			axis = normalize axis
			displayUpdated = false
		)

		on HardpointRollout open do (
			IsOpenRollout = true

			axis_XSpinner.value = axis.x
			axis_YSpinner.value = axis.y
			axis_ZSpinner.value = axis.z
		)

		on HardpointRollout close do IsOpenRollout = false
	)

	on getDisplayMesh do (
		if not hullUpdated then GenerateHullMesh hullShape hullSize
		if not displayUpdated then GenerateDisplayMesh baseSize arrowSize limitMin limitMax axis

		if hullShape == 1 then displayMesh else hullMesh
	)

	tool create (
		on mousePoint click do (
			nodeTM.translation = gridPoint
			#stop 
		)
	) 	
)

struct HardpointFixed (
	name,
	transform = Matrix3 1,

	fn ReadUTF reader = (
		reader.ReadFileTranslationPart "Position"    transform
		reader.ReadFileRotationPart    "Orientation" transform
		OK
	),

	fn WriteUTF writer = (
		writer.WriteFileTranslationPart "Position"    transform
		writer.WriteFileRotationPart    "Orientation" transform
		OK
	)
)

struct HardpointRevolute (
	name,
	transform = Matrix3 1,
	axis      = [0, 0, 0],
	limit     = [0, 0],

	fn ReadUTF reader = (
		reader.ReadFileTranslationPart "Position"    transform
		reader.ReadFileRotationPart    "Orientation" transform
		reader.ReadFilePosition        "Axis"        axis

		local minimum = reader.ReadFileFloat "Min"
		local maximum = reader.ReadFileFloat "Max"

		if minimum == undefined then minimum = 0
		if maximum == undefined then maximum = 0

		limit = -[maximum, minimum]
		OK
	),

	fn WriteUTF writer = (
		writer.WriteFileTranslationPart "Position"    transform
		writer.WriteFileRotationPart    "Orientation" transform
		writer.WriteFilePosition        "Axis"        axis

		writer.WriteFileFloat "Min" -limit.y
		writer.WriteFileFloat "Max" -limit.x
		OK
	)
)

struct HardpointPrismatic (
	name,
	transform = Matrix3 1,
	axis      = [0, 0, 0],
	limit     = [0, 0],

	fn ReadUTF reader = (
		reader.ReadFileTranslationPart "Position"    transform
		reader.ReadFileRotationPart    "Orientation" transform
		reader.ReadFilePosition        "Axis"        axis

		local minimum = reader.ReadFileFloat "Min"
		local maximum = reader.ReadFileFloat "Max"

		if minimum == undefined then minimum = 0
		if maximum == undefined then maximum = 0

		limit = -[maximum, minimum]
		OK
	),

	fn WriteUTF writer = (
		writer.WriteFileTranslationPart "Position"    transform
		writer.WriteFileRotationPart    "Orientation" transform
		writer.WriteFilePosition        "Axis"        axis
		
		writer.WriteFileFloat "Min" -limit.y
		writer.WriteFileFloat "Max" -limit.x
		OK
	)
)

-- Build HardpointHelpers from array attached to target node
fn BuildHardpoints target hardpoints size:(MAXLancer.hardpointSize) = (
	if not isValidNode target then throw "Invalid target node."
	if classOf hardpoints != Array then throw "Invalid hardpoints array."

	local item

	for hardpoint in hardpoints do (
		MAXLancer.WriteLog ("Hardpoint: " + hardpoint.name)

		item = HardpointHelper name:hardpoint.name baseSize:size arrowSize:size parent:target transform:(hardpoint.transform * target.transform)
		AddToLayer "Hardpoints" item

		item.type = case classOf hardpoint of (
			HardpointFixed:     1
			HardpointRevolute:  2
			HardpointPrismatic: 3
			default: "Unknown hardpoint type."
		)	

		if item.type != 1 then item.axis = hardpoint.axis

		case item.type of (
			2: (
				item.limitMin = radToDeg hardpoint.limit.x
				item.limitMax = radToDeg hardpoint.limit.y
			)
			3: (
				item.limitMin = hardpoint.limit.x
				item.limitMax = hardpoint.limit.y
			)
		)

		item.wireColor = target.wireColor
	)

	OK
)

-- Parse target node children of HardpointHelper type into HardpointFixed/HardpointRevolute/HardpointPrismatic 
fn ParseHardpoints target &hardpoints = (
	if not isValidNode target then throw "Invalid target node."

	hardpoints = #()

	local hardpoint

	for child in target.children where classOf child == HardpointHelper do (
		hardpoint = case child.type of (
			1: HardpointFixed name:child.name
			2: HardpointRevolute name:child.name limit:[DegToRad child.limitMin, DegToRad child.limitMax] axis:child.axis
			3: HardpointPrismatic name:child.name limit:[child.limitMin, child.limitMax] axis:child.axis
			default: "Unknown hardpoint type."
		)

		hardpoint.transform = child.transform * inverse target.transform
		append hardpoints hardpoint
	)

	OK
)

-- Read hardpoint types into array
fn ReadHardpointType reader type archetype hardpoints = (
	if classOf reader != UTFReader then throw "Invalid UTFReader object."
	if classOf hardpoints != Array then throw "Invalid hardpoints array."

	local hardpoint

	if reader.OpenFolder type then (
		for filename in reader.GetFolders() where reader.OpenFolder filename do (
			(hardpoint = archetype name:filename).ReadUTF reader
			reader.CloseFolder()
			append hardpoints hardpoint
		)

		reader.CloseFolder() -- Close Fixed/Revolute/Prismatic
	)

	OK
)

-- Read hardpoints from UTF (Hardpoints)
fn ReadHardpoints reader &hardpoints = (
	if classOf reader != UTFReader then throw "Invalid UTFReader object."

	hardpoints = #()

	if reader.OpenFolder "Hardpoints" then (
		ReadHardpointType reader "Fixed"     HardpointFixed     hardpoints
		ReadHardpointType reader "Revolute"  HardpointRevolute  hardpoints
		ReadHardpointType reader "Prismatic" HardpointPrismatic hardpoints
		reader.CloseFolder() -- Close Hardpoints
	)

	OK
)

-- Write array of hardpoints into UTF
fn WriteHardpointType writer type hardpoints = (
	if classOf writer != UTFWriter then throw "Invalid UTFWriter object."
	if classOf hardpoints != Array then throw "Invalid hardpoints array."	

	if hardpoints.count > 0 then (
		if not writer.OpenFolder type then throw ("Error writing " + type)

		for hardpoint in hardpoints do (
			if hardpoint.transform.determinantsign < 0 then throw ("Hardpoint " + hardpoint.name + " transform has negative determinant")

			writer.OpenFolder hardpoint.name
			hardpoint.WriteUTF writer
			writer.CloseFolder()
		)
		
		writer.CloseFolder() -- Close Fixed/Revolute/Prismatic 
	)

	OK
)

-- Write hardpoints into UTF (Hardpoints)
fn WriteHardpoints writer hardpoints = (
	if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

	local fixed     = #() -- Array of HardpointFixed
	local revolute  = #() -- Array of HardpointRevolute
	local prismatic = #() -- Array of HardpointPrismatic

	-- Sort hardpoints into category arrays
	if classOf hardpoints == Array then for hardpoint in hardpoints do case classOf hardpoint of (
		HardpointFixed:     append fixed hardpoint
		HardpointRevolute:  append revolute hardpoint
		HardpointPrismatic: append prismatic hardpoint
	)

	if fixed.count > 0 or revolute.count > 0 or prismatic.count > 0 then (
		if not writer.OpenFolder "Hardpoints" then throw "Error writing Hardpoint"

		WriteHardpointType writer "Fixed"     fixed
		WriteHardpointType writer "Revolute"  revolute
		WriteHardpointType writer "Prismatic" prismatic

		writer.CloseFolder() -- Close Hardpoints
	)

	OK
)