/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 */

-- Round float to digit
fn RoundFloat f d = floor (f * (10 ^ d)) / (10 ^ d)

-- Format miliseconds to seconds as string
fn FormatSeconds ms = formattedPrint (0.001 * ms) format:".2f"

-- Format integer into 0x hex string
fn FormatID id = if classOf id == integer then "0x" + formattedPrint id format:"08X" else id as string

-- Unpack integer into Color
fn UnpackColor i = Color (bit.and (bit.shift i -16) 0xFF) (bit.and (bit.shift i -8) 0xFF) (bit.and i 0xFF) (bit.and (bit.shift i -24) 0xFF)

-- Pack Color into integer
fn PackColor c = c.b + (bit.shift c.g 8) + (bit.shift c.r 16) + (bit.shift c.a 24)

-- Rebuilds W component of quaternion given only XYZ
fn RebuidQuat v = quat v.x v.y v.z (sqrt (1.0 - v.x * v.x - v.y * v.y - v.z * v.z))

-- Read Point2 from stream
fn ReadPoint2 stream p = (
	p.x = ReadFloat stream
	p.y = ReadFloat stream
	OK
)

-- Write Point2 into stream
fn WritePoint2 stream p = (
	WriteFloat stream p.x
	WriteFloat stream p.y
	OK
)

-- Read Point3 from stream
fn ReadPoint3 stream p = (
	p.x = ReadFloat stream
	p.y = ReadFloat stream
	p.z = ReadFloat stream
	OK
)

-- Write Point3 into stream
fn WritePoint3 stream p = (
	WriteFloat stream p.x
	WriteFloat stream p.y
	WriteFloat stream p.z
	OK
)

-- Read normalized Point3 from stream
fn ReadNormalShort stream p = (
	p.x = ReadShort stream / 32767.0
	p.y = ReadShort stream / 32767.0
	p.z = ReadShort stream / 32767.0
	OK
)

-- Write normalized Point3 into stream
fn WriteNormalShort stream p = (
	WriteShort stream (p.x * 32767)
	WriteShort stream (p.y * 32767)
	WriteShort stream (p.z * 32767)
	OK
)

-- Read color from stream as BGRA integer (converted to 3ds Max, VMesh vertex attribute)
fn ReadColorInteger stream c = (
	c.b = ReadByte stream #unsigned
	c.g = ReadByte stream #unsigned
	c.r = ReadByte stream #unsigned
	c.a = ReadByte stream #unsigned
	OK
)

-- Write color into stream as BGRA integer (converted to Freelancer, VMesh vertex attribute)
fn WriteColorInteger stream c = (
	WriteByte stream c.b #unsigned
	WriteByte stream c.g #unsigned
	WriteByte stream c.r #unsigned
	WriteByte stream c.a #unsigned
	OK
)

-- Read color from stream as RGB floats (convert to 3ds Max, material color)
fn ReadColorFloat stream c = (
	c.r = ReadFloat stream * 255
	c.g = ReadFloat stream * 255
	c.b = ReadFloat stream * 255
	OK
)

-- Write color into stream as RGB floats (converted to Freelancer, material color)
fn WriteColorFloat stream c = (
	WriteFloat stream (c.r / 255.0)
	WriteFloat stream (c.g / 255.0)
	WriteFloat stream (c.b / 255.0)
	OK
)

-- Read point3 from stream (converted to 3ds Max, 3D vectors)
fn ReadPosition stream p = (
	p.x =  ReadFloat stream
	p.z =  ReadFloat stream
	p.y = -ReadFloat stream
	OK
)

-- Write point3 into stream (converted to Freelancer, 3D vectors)
fn WritePosition stream p = (
	WriteFloat stream  p.x
	WriteFloat stream  p.z
	WriteFloat stream -p.y
	OK
)

-- Read quat from stream (converted to 3ds Max, animation frames)
fn ReadQuaternion stream q = (
	q.w =  ReadFloat stream
	q.y = -ReadFloat stream
	q.z =  ReadFloat stream
	q.x =  ReadFloat stream
	OK
)

-- Write quat into stream (converted to Freelancer, animation frames)
fn WriteQuaternion stream q = (
	WriteFloat stream  q.w
	WriteFloat stream -q.y
	WriteFloat stream  q.z
	WriteFloat stream  q.x
	OK
)

-- Read quantized quat from stream (reconstructing w component)
fn ReadQuaternion0x40 stream q = (
	local v = [0, 0, 0]

	v.x =  ReadShort stream
	v.z =  ReadShort stream
	v.y = -ReadShort stream

	v /= 32767.0

	q.x = v.x
	q.y = v.y
	q.z = v.z

	local s = q.x * q.x + q.y * q.y + q.z * q.z
	q.w = if s < 1.0 then q.w = sqrt(1 - s) else 0

	OK
)

-- Read quantized quat from stream (harmonic mean)
fn ReadQuaternion0x80 stream q = (
	local v = [0, 0, 0]

	v.x =  ReadShort stream
	v.z =  ReadShort stream
	v.y = -ReadShort stream

	v /= 32767.0

	local s = dot v v

	if s > 0 then (
		local l = length v
		local t = sin(radToDeg (pi * l * 0.5))
		local k = t / l

		q.x = v.x * k
		q.y = v.y * k
		q.z = v.z * k
		q.w = sqrt(1.0 - t * t)
	)

	OK
)

local qhmSQ2p1   = sqrt 2 + 1
local qhm3m2xSQ2 = 3 - 2 * sqrt 2
local qhm4xSQ2m1 = 4 * ((sqrt 2) - 1)

-- Read quantized quat from stream (basic harmonic mean, half-angle & cayley composition)
fn ReadQuaternionHarmonicMean stream q = (
	local v = [0, 0, 0]

	v.x =  ReadShort stream
	v.z =  ReadShort stream
	v.y = -ReadShort stream

	v /= 32767.0

	local d = dot v v * qhm3m2xSQ2
	local b = (1.0 - d) * qhm4xSQ2m1
	local c = 1.0 / (1 + 2 * d + d * d)

	q.x = v.x * b * c
	q.y = v.y * b * c
	q.z = v.z * b * c
	q.w = (1.0 + d * (d - 6.0)) * c
	OK
)

-- Write quantized quat into stream
fn WriteQuaternionHarmonicMean stream q = (
	local r = copy q
	if (r.w < 0) then r *= -1

	local v = [r.x, r.y, r.z] * qhmSQ2p1 / (1.0 + r.w + sqrt(2 + 2 * r.w))

	WriteShort stream ( v.x * 32767)
	WriteShort stream ( v.z * 32767)
	WriteShort stream (-v.y * 32767)
	OK
)

-- Read quantized quat from stream (half-angle)
fn ReadQuaternionHalfAngle stream q = (
	local v = [0, 0, 0]

	v.x =  ReadShort stream
	v.z =  ReadShort stream
	v.y = -ReadShort stream
	
	v /= 32767.0

	local d = dot v v
	
	v *= sqrt (2.0 - d)
	
	q.x = v.x
	q.y = v.y
	q.z = v.z
	q.w = 1.0 - d

	OK
)

-- Write quantized half-angle quat into stream
fn WriteQuaternionHalfAngle stream q = (
	local n = [q.x, q.z, -q.y] * 1 / sqrt (1.0 + q.w)

	WriteShort stream ( n.x * 32767)
	WriteShort stream ( n.z * 32767)
	WriteShort stream (-n.y * 32767)

	OK
)

-- Read matrix3 rotation part from stream (converted to 3ds Max)
fn ReadRotationPart stream m = (
	m.row1.x =  ReadFloat stream
	m.row3.x =  ReadFloat stream
	m.row2.x = -ReadFloat stream

	m.row1.z =  ReadFloat stream
	m.row3.z =  ReadFloat stream
	m.row2.z = -ReadFloat stream

	m.row1.y = -ReadFloat stream
	m.row3.y = -ReadFloat stream
	m.row2.y =  ReadFloat stream

	OK
)

-- Write matrix3 rotation part into stream (converted to Freelancer)
fn WriteRotationPart stream m = (
	WriteFloat stream  m.row1.x
	WriteFloat stream  m.row3.x
	WriteFloat stream -m.row2.x

	WriteFloat stream  m.row1.z
	WriteFloat stream  m.row3.z
	WriteFloat stream -m.row2.z

	WriteFloat stream -m.row1.y
	WriteFloat stream -m.row3.y
	WriteFloat stream  m.row2.y

	OK
)

-- Read Matrix3 translation part from stream (converted to 3ds Max)
fn ReadTranslationPart stream m = (
	m.row4.x =  ReadFloat stream
	m.row4.z =  ReadFloat stream
	m.row4.y = -ReadFloat stream
	OK
)

-- Write Matrix3 translation part into stream (converted to Freelancer)
fn WriteTranslationPart stream m = (
	WriteFloat stream  m.row4.x
	WriteFloat stream  m.row4.z
	WriteFloat stream -m.row4.y
	OK
)

-- Read Matrix3 (converted to 3ds Max, deformable models)
fn ReadBoneToRoot stream m = (
	local p = [0, 0, 0]

	m.row1.x =  ReadFloat stream
	m.row1.z =  ReadFloat stream
	m.row1.y = -ReadFloat stream

	m.row3.x =  ReadFloat stream
	m.row3.z =  ReadFloat stream
	m.row3.y = -ReadFloat stream

	m.row2.x = -ReadFloat stream
	m.row2.z = -ReadFloat stream
	m.row2.y =  ReadFloat stream

	ReadPosition stream p
	preTranslate m -p
	OK
)	

-- Write Matrix3 (converted to Freelancer, deformable models)
fn WriteBoneToRoot stream m = (
	WriteFloat stream  m.row1.x
	WriteFloat stream  m.row1.z
	WriteFloat stream -m.row1.y

	WriteFloat stream  m.row3.x
	WriteFloat stream  m.row3.z
	WriteFloat stream -m.row3.y

	WriteFloat stream -m.row2.x
	WriteFloat stream -m.row2.z
	WriteFloat stream  m.row2.y

	WritePosition stream (-m.row4 * inverse (translate (copy m) -m.row4))
	OK
)	

-- Read fixed length string from stream (automatically stops at NUL)
fn ReadCharsFixed stream length jump:true = (
	local offset = ftell stream + length, result = "", char = 0
	for i = 1 to length while (char = ReadByte stream #unsigned) != undefined and char > 0 do append result (bit.intAsChar char)
	if jump then fseek stream offset #seek_set
	result
)

-- Write fixed length string to stream (w/o NUL)
fn WriteCharsFixed stream chars length jump:true = (
	local offset = ftell stream + length
	if chars.count < length then length = chars.count
	for i = 1 to length do WriteByte stream (bit.charAsInt chars[i])
	if jump then fseek stream offset #seek_set else true
)

-- Align stream to base number of bytes
fn AlignStream stream base:4 = (
	if classOf stream != BinStream then throw "Invalid source stream type."

	fseek stream 0 #seek_end
	local offset = ftell stream, bytes = base - int (mod offset base)
	if bytes < base and fseek stream (offset + bytes - 1) #seek_set then WriteByte stream 0
	ftell stream -- Return resulting offset
)

-- Is input string a valid hexidecimal of 32-bit number in form of 0x11223344
fn IsHexString input = (
	local code  = 0
	local valid = input.count > 2 and input.count < 11

	for i = 1 to input.count while valid where (code = bit.charAsInt input[i]) > 0 do valid = case i of (
		1: code == 48 -- 0 char
		2: code == 88 or code == 120 -- x or X char
		default: (code >= 48 and code <= 57) or (code >= 65 and code <= 70) or (code >= 97 and code <= 102)
	)

	valid -- Return Boolean
)

-- Copy bytes from source stream to target (in bulk by 4 bytes, remaining less than four by byte)
fn CopyStream source target size = (
	for i = 1 to int (size / 4) do WriteLong target (ReadLong source)
	for i = 1 to int (mod size 4) do WriteByte target (ReadByte source)
)

-- Generate short alpha-numeric ID
fn CreateShortID length:10 chars:"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" = (
	local result = ""

	for i = 1 to length do append result chars[(random 1 (chars.count))]
	result -- Return String
)

-- Generate new GUID (128-bit) from .net and return as uppercase formatted string
fn CreateGUID = toUpper (((dotNetClass "System.Guid").NewGuid()).toString())

-- Get a list of files matching pattern(s) and optionally filtered by a user callback function (<BooleanClass> filter filename: startPath: index: count:)
fn FilterFiles startPath recursive:true directoryMask:"*" fileMasks:#("*") filter: = (
	if not doesFileExist startPath then throw "Path does not exist"
	if not getFileAttribute startPath #directory then throw "Path is not a folder"

	startPath = pathConfig.appendPath startPath "\\"

	local result      = #()          -- Files matching pattern and filter
	local hasFilter   = classOf filter == MAXScriptFunction
	local directories = #(startPath) -- Directory queue to process
	local directory                  -- Current directory from queue
	local files       = #()          -- Files collected from current directory
		
	while directories.count > 0 do (
		directory         = directories[directories.count]
		directories.count = directories.count - 1
		files.count       = 0

		for m in fileMasks do join files (getFiles (directory + m))

		-- TODO: Untangle this mess of code
		join result (if hasFilter then for filename in files where filter filename collect filename else files)
		
		if recursive then join directories (getDirectories (directory + directoryMask))
	)

	result
)

-- Get array of faces bitArrays for each independent element in mesh
fn GetMeshElements target = (
	if classOf target != Editable_mesh then throw "Invalid target mesh"

	local result   = #()
	local faceList = #{1..getNumFaces target}
	local elementList

	while not faceList.isEmpty do (
		append result (elementList = meshOp.getElementsUsingFace target (faceList as array)[1])
		faceList -= elementList -- Reduce bitArray by faces used in element
	) 

	result -- Return Array of BitArray
)

-- Get array of face bitArrays for each polygon and face normals
fn GetMeshPolygons target threshhold:0.1 = (
	if classOf target != Editable_mesh then throw "Invalid target mesh"

	local result   = #()
	local faceList = #{1..getNumFaces target}
	local polyList
	
	while not faceList.isEmpty do (
		append result (polyList = meshop.getPolysUsingFace target (faceList as array)[1] ignoreVisEdges:true threshhold:threshhold)
		faceList -= polyList -- Reduce bitArray by faces used in poly
	)

	result -- Return Array of BitArray
)

-- Collect submaterials and faces from mesh
fn GetMeshMaterials target &materials &faces = (
	if classOf target != Editable_mesh then throw "Invalid target mesh"

	materials = #()
	faces     = #()

	case classOf target.material of (
		MultiMaterial: (

			-- Create empty bitArrays for all submaterial IDs
			local subfaces = for i = 1 to target.material.materialIDList.count collect #{}

			-- Collect face lists arranged by submaterial ID
			for f = 1 to getNumFaces target do subfaces[getFaceMatID target f][f] = true

			-- Filter through submaterials ignoring empty and invalid types
			for i = 1 to target.material.materialList.count where not subfaces[i].isEmpty do (
				append materials target.material.materialList[i]
				append faces subfaces[i]
			)
		)
		default: (
			append materials target.material
			append faces #{1..getNumFaces target}
		)
	)

	OK
)

-- Get array of nodes matching root class above in hierarchy 
fn GetPartParents root = (
	if not isValidNode root then throw "Invalid node object"

	local result = #() -- Array of nodes
	local child  = root

	while classOf child.parent == classOf root do append result (child = child.parent)

	result -- Return array of nodes
)

-- Get array of nodes matching root class below in hierarchy
fn GetPartChildren root deep:false attached:false = (
	if not isValidNode root then throw "Invalid node object"

	local result = #() -- Array of nodes
	local queue  = #(root)
	local parent

	while queue.count > 0 do (
		parent = queue[queue.count]
		queue.count = queue.count - 1

		for child in parent.children do (
			if attached and classOf child == HardpointHelper then append queue child
			else if classOf child == classOf root then (
				append result child

				if deep and child.children.count > 0 then append queue child
			)
		)
	)

	result -- Return array of nodes
)

-- Get array of HardpointHelper from root (and optionally its children)
fn GetPartHardpoints root deep:false = (
	if not isValidNode root then throw "Invalid node object"

	local result = #()
	local queue  = #(root)
	local parent

	fn SortByName a b = stricmp a.name b.name

	while queue.count > 0 do (
		parent = queue[queue.count]
		queue.count = queue.count - 1

		for child in parent.children do
			if classOf child == HardpointHelper then append result child else
			if deep and classOf child == classOf root and child.children.count > 0 then append queue child
	)

	qsort result SortByName

	result -- Return array of HardpointHelper
)

-- Find hardpoint helper in model (first match by ID)
fn FindHardpoint root id deep:true = (
	if not isValidNode root then throw "Invalid node object"

	id = MAXLancer.Hash id
	
	local queue  = #(root)
	local part   -- RigidPartHelper/DeformableHelper
	local result -- HardpointHelper

	while result == undefined and queue.count > 0 do (
		part = queue[queue.count]
		queue.count = queue.count - 1

		for child in part.children while result == undefined do case of (
			(classOf child == HardpointHelper and id == MAXLancer.Hash child.name): result = child
			(deep and classOf child == classOf root and child.children.count > 0): append queue child
		)
	)

	result -- Return HardpointHelper
)

fn GetModifierType target type = (
	local result
	for i = 1 to target.modifiers.count while result == undefined where isKindOf target.modifiers[i] type do result = target.modifiers[i]
	result -- Return modifier of specified type
)

-- Generate timestamp string for embedded .3db filename suffix from current local time
fn CreateFragmentTimeStamp time:(getLocalTime()) = substring (time[1] as string) 3 2 + formattedPrint time[2] format:"02d" + formattedPrint time[4] format:"02d" + formattedPrint time[5] format:"02d" + formattedPrint time[6] format:"02d" + formattedPrint time[7] format:"02d"

-- Generate DOS timestamp integer from current local time
fn CreateDOSTimestamp time:(getLocalTime()) = (bit.and (time[7] / 2) 0x1F) + (bit.shift (bit.and time[6] 0x3F) 5) + (bit.shift (bit.and time[5] 0x1F) 11) + (bit.shift (bit.and time[4] 0x1F) 16) + (bit.shift (bit.and time[2] 0xF) 21) + (bit.shift (bit.and (time[1] - 1980) 0x7F) 25)

-- Load DOS timestamp from integer into getLocalTime array
fn ParseDOSTimestamp time = #(bit.and (bit.shift time -25) 0x7F + 1980, bit.and (bit.shift time -21) 0xF, 0, bit.and (bit.shift time -16) 0x1F, bit.and (bit.shift time -11) 0x1F, bit.and (bit.shift time -5) 0x3F, bit.and time 0x1F * 2)

-- Get .net Forms.OpenFileDialog for multiple filenames
fn GetNetOpenFilenames caption:"Open Files" multiple:true restoreDirectory:true types:"All Files (*.*)|*.*" = (
	local dialog = dotNetObject "System.Windows.Forms.OpenFileDialog"

	dialog.Title            = caption
	dialog.Multiselect      = multiple
	dialog.Filter           = types
	dialog.RestoreDirectory = restoreDirectory

	local response = dialog.showDialog()
	if response.Equals response.OK then dialog.FileNames -- Return array of filenames
)

-- Get .net Drawing.Color from colorMan of type (#background, #text, etc)
fn GetNetColorMan type = (
	local result = (colorMan.getColor type) * 255
	(dotNetClass "System.Drawing.Color").fromARGB (int result.x) (int result.y) (int result.z)
)

-- Get random color between from derived HSL components for a more natural shift 
fn GetRandomColorHSL a b = (
	local result = black

	result.v = random a.v b.v
	result.s = random a.s b.s
	result.h = random a.h b.h

	result -- Return Color
)

-- Create new or get existing scene layer by name
fn GetLayer target hidden:false = (
	local result = LayerManager.getLayerFromName target

	if result == undefined then (result = LayerManager.newLayerFromName target).isHidden = hidden
	result -- Return LayerProperties mixin
)

-- Add target scene node to layer (auto-create layer if absent)
fn AddToLayer name target hidden:false = (
	if not isValidNode target then throw "Invalid node target object."

	local layer = LayerManager.getLayerFromName name
	if layer == undefined then (layer = LayerManager.newLayerFromName name).isHidden = hidden
	
	layer.addNode target
	OK
)

-- Get array of Point2 for texture grid atlas offsets excluding specified positions 
fn GetAtlasOffsets size exclusions:#{} = for i = 0 to size * size - 1 where findItem exclusions (i + 1) == 0 collect [mod i size, i / size, 0] / size

-- Calculate bounding box from array of Point3
fn CalculateBoundingBox points &minimum &maximum = (

	-- Reset reference boundaries
	minimum =  [3.4e38, 3.4e38, 3.4e38]
	maximum = -[3.4e38, 3.4e38, 3.4e38]

	local position -- Point3

	-- Extend bounding box boundaries and collect extremes at each box side
	for p = 1 to points.count do (
		position = points[p]

		minimum.x = amin minimum.x position.x
		minimum.y = amin minimum.y position.y
		minimum.z = amin minimum.z position.z

		maximum.x = amax maximum.x position.x
		maximum.y = amax maximum.y position.y
		maximum.z = amax maximum.z position.z
	)

	OK
)

-- Calculates sphere from array of Point3
fn CalculateBoundingSphere points &center &radius = (
	local maxDiameter = 0 -- Max accumulated diameter (Float)
	local diameter    = 0 -- Distance/diameter (Float)
	local range       = 0 -- Distance/radius (Float)

	local pointA, pointB -- Point3
	
	-- Find initial sphere from farthest extents
	for a = 1 to points.count do for b = 1 to points.count do (
		pointA = points[a]
		pointB = points[b]

		diameter = distance pointA pointB

		if diameter > maxDiameter then (
			maxDiameter = diameter

			center = pointA + ((pointB - pointA) * 0.25)
			radius = diameter * 0.5
		)
	)

	-- Expand sphere to capture any points left outside
	for p = 1 to points.count where (range = distance center points[p]) > radius do (
		radius = (radius + range) * 0.5
		center += (range - radius) / range * (points[p] - center)
	)

	OK
)

-- Merge two spheres into third
fn MergeSpheres centerA radiusA centerB radiusB &center &radius = (
	local v = centerA - centerB
	local l = length v

	if centerA == centerB and radiusA == radiusB then (radius = radiusA; center = centerA) else
	if l + radiusA < radiusB then (radius = radiusB; center = centerB) else
	if l + radiusB < radiusA then (radius = radiusA; center = centerA) else (
		radius = (radiusA + radiusB + l) * 0.5
		center = centerA + (centerB - centerA) * (radius - radiusA) / l
	)

	OK
)

-- Get random point on sphere (uniform distribution)
fn GetSphereRandomPoint = (
	local t = radToDeg (2 * pi * random 0.0 1.0)
	local p = radToDeg (acos (random -1.0 1.0))
		
	[sin(p) * cos(t), sin(p) * sin(t), cos(p)] -- Return Point3
)
	
-- Collapse vectors to points on unit sphere. Input vector components have to be in [-1, 1] range!
fn SpherifyVector v = (
	local dv = v * v
			
	local x = v.x * sqrt (1 - dv.y * 0.5 - dv.z * 0.5 + dv.y * dv.z / 3)
	local y = v.y * sqrt (1 - dv.z * 0.5 - dv.x * 0.5 + dv.z * dv.x / 3)
	local z = v.z * sqrt (1 - dv.x * 0.5 - dv.y * 0.5 + dv.x * dv.y / 3)
			
	[x, y, z] -- Return Point3
)

-- Generate balls within unit sphere with basic fractional collision detection for better spread. Result is not guaranteed to have requested number of balls
fn GetSphereBalls count sizeMin:0.1 sizeMax:1.0 fraction:1.0 tryLimit:100 = (
		
	local result   = #()   -- Array of Point4 (xyz position, w radius)
	local failed   = false -- Generator was unable to find a spot to put another point in due to boundary checks
	local collided = false -- Point sphere collided with another
	local tries    = 0     -- Try counter
	local position         -- Current position
	local radius           -- Current radius
	
	-- Generate request number of points unless try limit exceeded
	for i = 1 to count while not failed do (
		tries = 0 -- Reset counter for next ball
	
		do (
			collided = false
			position = GetSphereRandomPoint()
			radius   = random sizeMin sizeMax
			
			-- Find collision
			for b in result while not collided do collided = distance position (b as Point3) < (radius + b.w) * fraction
		) while not (failed = (tries += 1) >= tryLimit) and collided -- Keep trying until no collision occurs or attempt limit exceeded
		
		-- Append Point4 to array
		if not failed and not collided then append result [position.x, position.y, position.z, radius]
	)
	
	result -- Return array of Point4
)

-- Generate wireframe Line object from visible edges of Editable mesh
fn GenerateWireframe target = if classOf target == Editable_mesh then in coordsys target (
	local result = Line steps:0 transform:target.transform
		
	local faceVertices  -- Point3 of face indices
	local startPosition -- Point3 line start
	local stopPosition  -- Point3 line end
	local hashes = #()  -- Array of Number (hash from dual points)
	local startHash     -- Number (hash of start to end)
	local stopHash      -- Number (hash of end to start)
	local splineIndex   -- Number

	for f = 1 to getNumFaces target do (
		faceVertices = getFace target f

		for i = 1 to 3 where getEdgeVis target f i do (
			startPosition = getVert target faceVertices[i]
			stopPosition  = getVert target faceVertices[(if i < 3 then i + 1 else 1)]
			
			startHash = MAXLancer.Hash stopPosition crc:(MAXLancer.Hash startPosition)
			stopHash  = MAXLancer.Hash startPosition crc:(MAXLancer.Hash stopPosition)
				
			if appendIfUnique hashes startHash and appendIfUnique hashes stopHash then (
				splineIndex = addNewSpline result
				
				addKnot result splineIndex #corner #line startPosition
				addKnot result splineIndex #corner #line stopPosition
			)
		)
	)
	
	updateShape result
	AddToLayer "Wireframes" result
	result -- Return Line
)