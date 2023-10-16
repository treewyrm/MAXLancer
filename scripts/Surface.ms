/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Surfaces (convex hulls) used for Freelancer physics engine.
 */

plugin Helper SurfaceNodeHelper classID:#(0x4C58414D, 0x65646F6E) name:"Node" category:"MAXLancer" extends:dummy invisible:true (
	local displayMesh
	local lastSize
	
	parameters NodeParameters rollout:NodeRollout (
		radius  type:#float default:1 ui:radiusSpinner
		x_scale type:#float default:1 ui:scaleXSpinner
		y_scale type:#float default:1 ui:scaleYSpinner
		z_scale type:#float default:1 ui:scaleZSpinner
	)
	
	rollout NodeRollout "Surface Node" (
		spinner radiusSpinner "Radius" type:#float range:[0, 3.4e38, 100]
		
		group "Scale" (
			spinner scaleXSpinner "X:" type:#float
			spinner scaleYSpinner "Y:" type:#float
			spinner scaleZSpinner "Z:" type:#float
		)
	)
	
	on getDisplayMesh do (
		local size = [x_scale, y_scale, z_scale] * radius * 2
		
		if size != lastSize then (
			displayMesh = (createInstance box length:size.y width:size.x height:size.z).mesh
			move displayMesh [0, 0, -size.z * 0.5]
		)
		
		lastSize = size
		displayMesh
	)
	
	tool create (
		on mousePoint click do (
			nodeTM.translation = gridPoint
			#stop 
		)
	)
)

struct SurfacePoint (
	hullID   = 0,
	position = [0, 0, 0],
	
	-- Read SurfacePoint
	fn ReadStream stream = (
		ReadPosition stream position
		hullID = ReadLong stream
		OK
	),

	-- Write SurfacePoint
	fn WriteStream stream = (
		WritePosition stream position
		WriteLong stream hullID
		OK
	)		
)

struct SurfaceFace (
	flag     = 0,         -- 0x80 for wrap hull, 0x0 for normal hull
	opposite = 0,         -- Opposite face index
	points   = [0, 0, 0], -- Index in points array of SurfacePart 
	shared   = [0, 0, 0], -- Index of shared edge, every edge (A->B, B->C, C->A) has shared edge where order of points is mirrored (B->A, C->B, A->C)
	flags    = [0, 0, 0]  -- 1 for wrap hull, 0 for normal hull
)

struct SurfaceHull (
	hullID  = 0,
	type    = 4,   -- 4 is normal hull, 5 is wrap hull (non-colliding)
	faces   = #(), -- Array of SurfaceFace
	unknown = 0,

	-- Get unique triagnle indices
	fn GetPointIndices = (
		local result = #{}
		for f in faces do result[int f.points.x] = result[int f.points.y] = result[int f.points.z] = true
		result -- Return BitArray
	),

	-- Read SurfaceHull
	fn ReadStream stream = (
		hullID = ReadLong stream #unsigned -- Either name hash (type 4) or offset to node using it (node 5)

		local header = ReadLong stream #unsigned -- Unique refs count (3 bytes), mesh type (1 byte)
		
		type        = bit.and header 0xFF -- Hull type
		faces.count = ReadShort stream #unsigned
		unknown     = ReadShort stream #unsigned -- Unused/padding?

		if type == 5 then hullID = 0 -- Type 5 keeps offset to node there instead

		local face          -- SurfaceFace
		local index     = 0 -- Face index
		local longCount = 0
		local edgeOffset

		for i = 1 to faces.count do (

			header = ReadLong stream #unsigned -- Flag (8 bits), opposite face index (12 bits unsigned), face index (12 bits unsigned)
			index  = 1 + bit.and header 0xFFF -- Face index
			face = faces[index] = SurfaceFace flag:(bit.and (bit.shift header -24) 0xFF) opposite:(1 + bit.and (bit.shift header -12) 0xFFF)

			longCount += 1

			-- Read triangle sides
			for v = 1 to 3 do (
				face.points[v] = 1 + ReadShort stream #unsigned -- Edge point index
				header = ReadShort stream #unsigned -- Flag (1 bit), offset to opposite edge (15 bits signed)

				face.flags[v] = int (bit.get header 16)

				-- Read signed 15-bit integer and calculate edge index
				edgeOffset = longCount + (if bit.get header 15 then bit.or (bit.and header 0x3FFF) (bit.not 0x3FFF) else bit.and header 0x3FFF)
				face.shared[v] = edgeOffset - edgeOffset / 4

				longCount += 1
			)
		)

		OK
	),

	-- Write SurfaceHull
	fn WriteStream stream = (
		local header = bit.or (bit.shift ((12 + faces.count * 6) / 4) 8) (bit.and type 0xFF)

		WriteLong stream hullID #unsigned
		WriteLong stream header #unsigned

		WriteShort stream faces.count #unsigned
		WriteShort stream unknown #unsigned

		local face           -- SurfaceFace
		local edgeCount  = 0
		local edgeOffset = 0

		for i = 1 to faces.count do (
			face = faces[i]

			WriteLong stream (bit.or (bit.or (bit.and (i - 1) 0xFFF) (bit.shift (face.opposite - 1) 12)) (bit.shift (bit.and face.flag 0xFF) 24)) #unsigned

			for v = 1 to 3 do (
				edgeOffset = int face.shared[v] - 1 - edgeCount + (int face.shared[v] - 1) / 3 - edgeCount / 3

				WriteShort stream (face.points[v] - 1) #unsigned -- Edge point index
				WriteShort stream (bit.set (bit.and edgeOffset 0x7FFF) 16 (face.flags[v] != 0)) #unsigned

				edgeCount += 1
			)
		)

		OK
	),

	-- Read Editable_mesh into hull triangles/edge format
	fn Parse target indices epsilon:0.001 = (
		if not isValidNode target then throw "Target is not a valid scene node"
		if classOf target != Editable_mesh then throw "Target is not a mesh"

		local edges = #()
		local face -- Point3 and later SurfaceFace
		
		faces.count = getNumFaces target

		-- Collect indices (A-B, B-C, C-A)
		for f = 1 to faces.count do (
			face = getFace target f

			append edges [face.x, face.y]
			append edges [face.y, face.z]
			append edges [face.z, face.x]
		)

		meshop.flipNormals target #all -- Flip normals for raycasting

		-- Collect indices of reverse edge pairs (B-A, C-B, A-C)
		local reversed  = for edge in edges collect findItem edges [edge.y, edge.x]
		local edgeCount = 0
	
		local normal -- Face normal (Point3)
		local hit    -- Ray

		for f = 1 to faces.count do (
			normal = getFaceNormal target f
			hit    = intersectRayEx target (ray ((meshOp.getFaceCenter target f) - normal * epsilon) normal)
			
			if hit == undefined then MAXLancer.WriteLog ("Face " + formattedPrint f format:"u" + " has no opposite face in " + target.name)

			face = faces[f] = SurfaceFace opposite:(if hit == undefined then 1 else hit[2]) flag:(if type == 5 then 0x80 else 0) flags:(if type == 5 then [1, 1, 1] else [0, 0, 0]) 

			for d = 1 to 3 do (
				edgeCount += 1

				face.points[d] = indices[edges[edgeCount].x]
				face.shared[d] = reversed[edgeCount]
			)
		)

		OK
	),

	fn Build points = mesh name:(formatID hullID) faces:(for f in faces collect f.points) vertices:(for p in points collect p.position)
)

struct SurfaceNode (
	center  = [0, 0, 0], -- Boundary center
	radius  = 0.0,       -- Boundary radius
	scaler  = [0, 0, 0], -- Boundary radius axis scalers
	unknown = 0,         -- Unknown byte (padding?)
	hull,                -- SurfaceHull
	left,                -- Left child SurfaceNode
	right,               -- Right child SurfaceNode

	-- Get node boundary minimum and maximum points
	fn GetBoundary &minimum &maximum = (
		minimum = center - scaler * radius
		maximum = center + scaler * radius
		OK
	),

	-- Set node boundaries from minimum and maximum points
	fn SetBoundary minimum maximum padding:0.1 = (
		if classOf minimum != Point3 then throw "Invalid minimum Point3 object."
		if classOf maximum != Point3 then throw "Invalid maximum Point3 object."

		center = 0.5 * (minimum + maximum)
		radius = 0.5 * distance minimum maximum
		scaler = 0.5 * (maximum - minimum) / radius
		
		OK
	),

	-- SurfaceNode contains target SurfaceNode
	fn ContainsNode target epsilon:0.25 = (
		if classOf target != SurfaceNode then throw "Invalid target SurfaceNode object."
		
		local a = scaler * radius + epsilon
		local b = target.scaler * target.radius
	
		-- Return Boolean
		center.x - a.x <= target.center.x - b.x and
		center.y - a.y <= target.center.y - b.y and
		center.z - a.z <= target.center.z - b.z and
		center.x + a.x >= target.center.x + b.x and
		center.y + a.y >= target.center.y + b.y and
		center.z + a.z >= target.center.z + b.z
	),

	-- SurfaceNode intersects target SurfaceNode
	fn IntersectsNode target epsilon:0.25 = (
		if classOf target != SurfaceNode then throw "Invalid target SurfaceNode object."

		local a = scaler * radius + epsilon
		local b = target.scaler * target.radius

		abs(center.x - target.center.x) <= a.x + b.x and
		abs(center.y - target.center.y) <= a.y + b.y and
		abs(center.z - target.center.z) <= a.z + b.z
	),

	-- SurfaceNode contains points
	fn ContainsPoints points epsilon:0.25 = (
		local a = scaler * radius + epsilon
		local p
		local result = #{}

		for i = 1 to points.count do (
			p = points[i] -- Point3

			result[i] = center.x - a.x <= p.x and
						center.y - a.y <= p.y and
						center.z - a.z <= p.z and
						center.x + a.x >= p.x and
						center.y + a.y >= p.y and
						center.z + a.z >= p.z
		)
		
		result
	),

	-- Create new SurfaceNode from two SurfaceNodes
	fn GroupNodes a b = (
		if classOf a != SurfaceNode then throw "Invalid left child SurfaceNode object."
		if classOf b != SurfaceNode then throw "Invalid right child SurfaceNode object."

		local minA, maxA, minB, maxB

		a.GetBoundary &minA &maxA
		b.GetBoundary &minB &maxB

		local result = SurfaceNode left:a right:b

		result.SetBoundary [amin minA.x minB.x, amin minA.y minB.y, amin minA.z minB.z] [amax maxA.x maxB.x, amax maxA.y maxB.y, amax maxA.z maxB.z]
		result -- Return SurfaceNode
	),

	-- Read SurfaceNode
	fn ReadStream stream = (
		ReadPosition stream center
		radius = ReadFloat stream

		scaler.x = ReadByte stream #unsigned
		scaler.z = ReadByte stream #unsigned
		scaler.y = ReadByte stream #unsigned
		scaler /= 0xFA

		unknown = ReadByte stream
		OK
	),

	-- Write SurfaceNode
	fn WriteStream stream = (
		WritePosition stream center
		WriteFloat stream radius

		WriteByte stream (scaler.x * 0xFA) #unsigned
		WriteByte stream (scaler.z * 0xFA) #unsigned
		WriteByte stream (scaler.y * 0xFA) #unsigned

		WriteByte stream unknown
		OK
	),

	fn Build target = SurfaceNodeHelper name:(target.name + "_Node") parent:target transform:(preTranslate target.transform center) wireColor:target.wireColor radius:radius x_scale:scaler.x y_scale:scaler.y z_scale:scaler.z
)

struct SurfacePart (
	partID     = 0,         -- Rigid object name hash
	dynamic    = false,     -- !fxd flag
	minimum    = [0, 0, 0], -- Bounding box minimum
	maximum    = [0, 0, 0], -- Bounding box maximum
	center     = [0, 0, 0], -- Center of mass, used for aiming reticle
	radius     = 0.0,       -- Radius of sphere encompassing all hulls
	scaler     = 1.0,       -- Down-scale factor of sphere radius encompassing only non-hardpoint hulls
	drag       = [0, 0, 0], -- Linear drag
	unknown    = [0, 0, 0], -- Unused vector
	hardpoints = #(),       -- Array of Integer
	points     = #(),       -- Array of SurfacePoint
	root,                   -- Root SurfaceNode

	fn GetPointIndex position hullID = (
		local index = 0

		for p = 1 to points.count while index == 0 where points[p].hullID == hullID and points[p].position == position do index = p
		if index == 0 then index = (append points (SurfacePoint hullID:hullID position:position)).count

		index -- Return integer
	),

	-- Get array of SurfaceHull from BSP tree
	fn GetHulls wrap:false = (
		local result = #()
		local queue  = #(root)
		local target -- SurfaceNode
		
		while queue.count > 0 do (
			target = queue[queue.count]
			queue.count = queue.count - 1

			if target.right != undefined then append queue target.right
			if target.left != undefined then append queue target.left
			if target.hull != undefined and target.hull.type == 4 then append result target.hull
		)

		if wrap and root.hull.type == 5 then append result root.hull

		result -- Array of SurfaceHull
	),

	-- Parse RigidPartHelper into SurfacePart
	fn Parse target compound forceConvex:false epsilon:0.05 progress: = (
		if classOf target != RigidPartHelper then throw "Invalid Rigid part helper object."

		-- Surface part for non-compound model will have 0x0 for ID
		partID     = if compound then MAXLancer.Hash target.name else 0
		dynamic    = classOf target.transform.controller != FixedJointController

		local hardpoints = #()
		local center     = [0, 0, 0]

		-- Phase 1: Collect Editable_mesh objects for hulls from target

		local nodes = #() -- Array of SurfaceNode
		local positions   -- Array of Point3
		local currentNode -- SurfaceNode
		local element     -- Editable_mesh temporarily created from element faces
		local hullID      -- Hull ID
		local elementConvex
		local position

		-- Kept commented out as a reminder part extents min/max is never set correctly otherwise
		-- local minimum
		-- local maximum

		for item in SurfaceLibrary.GetPartSurfaces target &hardpoints &center do (
			hullID = MAXLancer.Hash item.name

			-- Non-hardpoint hulls in non-compound model have ID of 0x0
			if not compound and findItem hardpoints hullID == 0 then hullID = 0

			if classOf item == HardpointHelper then (
				MAXLancer.WriteLog ("Hull " + item.name + " (" + formatID hullID + "): " + formattedPrint (getNumFaces item.hullMesh) format:"u" + " faces")

				element = mesh name:item.name mesh:item.hullMesh transform:item.transform hidden:true
				indices = #()

				meshop.weldVertsByThreshold element #all epsilon

				currentNode = SurfaceNode hull:(SurfaceHull hullID:hullID)

				-- Push positions into SurfacePoints
				for i = 1 to getNumVerts element do indices[i] = GetPointIndex (in coordsys target GetVert element i) hullID
				
				-- Generate faces with points referenced by indices
				currentNode.hull.Parse element indices

				-- Set node boundary
				in coordsys target currentNode.SetBoundary element.min element.max

				delete element
				append nodes currentNode

				-- Update progress on every hull node
				if classOf progress == MAXScriptFunction then progress (getNumFaces item.hullMesh)

			) else for faces in GetMeshElements item do ( -- Break mesh into elements and process each as individual hull
				MAXLancer.WriteLog ("Hull " + item.name + " (" + formatID hullID + "): " + formattedPrint faces.numberSet format:"u" + " faces")
				
				-- Convex hulls can have only even number of faces
				if mod faces.numberSet 2 != 0 then throw ("Hull subgroup in " + item.name + " has uneven number of faces.")

				-- Create temporary mesh from element faces
				element = mesh name:item.name mesh:(meshOp.detachFaces item faces delete:false asMesh:true) transform:item.transform hidden:true
				indices = #() -- Array of indices for corresponding SurfacePoint in points array

				meshop.weldVertsByThreshold element #all epsilon

				-- Reset extent bounding box
				minimum = [ 3.4e38,  3.4e38,  3.4e38]
				maximum = [-3.4e38, -3.4e38, -3.4e38]

				if forceConvex then (
					elementConvex = nvpx.CreateBoundingShapeConvex element (getNumVerts element) 0.0 1
					delete element
					element = elementConvex
				)
				
				-- Each element will become individual SurfaceHull and put into a SurfaceNode
				currentNode = SurfaceNode hull:(SurfaceHull hullID:hullID)

				-- Push positions into SurfacePoints
				in coordsys target for i = 1 to getNumVerts element do (
					position   = GetVert element i
					indices[i] = GetPointIndex position hullID

					minimum.x = amin minimum.x position.x
					minimum.y = amin minimum.y position.y
					minimum.z = amin minimum.z position.z

					maximum.x = amax maximum.x position.x
					maximum.y = amax maximum.y position.y
					maximum.z = amax maximum.z position.z
				)
				
				-- Generate faces with points referenced by indices
				currentNode.hull.Parse element indices

				-- Set node boundary
				in coordsys target currentNode.SetBoundary minimum maximum --  element.max

				delete element
				append nodes currentNode

				-- Update progress on every hull node
				if classOf progress == MAXScriptFunction then progress faces.numberSet
			)
		)

		this.hardpoints = hardpoints

		-- Phase 2: Condense list of nodes into binary tree by grouping closest 

		local unsorted = #() -- Array of SurfaceNode
		local lengths  = #() -- Array of float
		local pairs    = #() -- Array of DataPair
		local index          -- Index for pairs/lengths arrays

		local leftNode  -- SurfaceNode
		local rightNode -- SurfaceNode

		local iteration = 0

		-- Condense node list by grouping nodes into pairs until only one node remain which becomes root
		while nodes.count > 1 do (

			lengths.count = pairs.count = unsorted.count = 0 -- Reset arrays

			-- Generate map of distances between node centers
			for leftNode in nodes where appendIfUnique unsorted leftNode do for rightNode in unsorted where rightNode != leftNode do (
				append pairs (DataPair leftNode rightNode)
				append lengths (distance leftNode.center rightNode.center)
			)

			nodes.count = 0 -- Reset node array after gathering remaining nodes to populate with paired groups

			-- Group list into pairs until one or none are left
			while unsorted.count > 1 do (
				index = findItem lengths (amin lengths) -- Get pair index of shortest length

				-- Get and remove pair from unsorted list
				deleteItem unsorted (findItem unsorted (leftNode  = pairs[index].v1))
				deleteItem unsorted (findItem unsorted (rightNode = pairs[index].v2))
				
				append nodes (SurfaceNode.GroupNodes leftNode rightNode) -- Create new node by grouping selected pair
				
				-- Remove left and right nodes from pairs and lengths
				for i = lengths.count to 1 by -1 where pairs[i].v1 == leftNode or pairs[i].v1 == rightNode or pairs[i].v2 == leftNode or pairs[i].v2 == rightNode do (
					deleteItem pairs i
					deleteItem lengths i
				)

				if unsorted.count == 1 then join nodes unsorted -- Should one remain add it to next round
			)

			-- Update progress on every time list is condensed
			if classOf progress == MAXScriptFunction then progress 0
		)

		-- Phase 3: Build wrap hull if necessary and calculate extent bounding box and bounding sphere

		local maxRadius = 0 -- Maximum radius for all points
		local minRadius = 0 -- Maximum radius for points of hulls which aren't hardpoints
		local position      -- SurfacePoint position (Point3)

		-- Set resulting node to root
		if nodes.count == 1 then (
			root = nodes[1]

			-- Generate wrap from points if root has no hull
			if root.hull == undefined then (
				positions = for p in points collect p.position
				element = mesh name:("Group_" + target.name) mesh:(MAXLancer.GenerateHull positions) transform:target.transform hidden:true

				root.hull = SurfaceHull type:5
				root.hull.Parse element (#{1..points.count} as Array)

				delete element
			)

			-- Reset extent bounding box
			minimum = [ 3.4e38,  3.4e38,  3.4e38]
			maximum = [-3.4e38, -3.4e38, -3.4e38]

			for p in points do (
				position  = p.position
				radius    = distance center position
				maxRadius = amax maxRadius radius

				if findItem hardpoints p.hullID > 0 then minRadius = amax minRadius radius else (
					minimum.x = amin minimum.x position.x
					minimum.y = amin minimum.y position.y
					minimum.z = amin minimum.z position.z

					maximum.x = amax maximum.x position.x
					maximum.y = amax maximum.y position.y
					maximum.z = amax maximum.z position.z
				)
			)

			if minRadius == 0 then minRadius = maxRadius

			radius = maxRadius
			scaler = minRadius / maxRadius
			drag   = [target.dragX, target.dragY, target.dragZ]

			if target.autoDrag then drag = [0, 0, radius] * rotateYPRMatrix (random 0.0 90) (random -90.0 0) 0

			this.center = center
		)

		OK
	),

	-- Build SurfacePart for RigidPartHelper
	fn Build target compound centers:true extents:false nodes:false wraps:false hulls:true epsilon:0.5 progress: = (
		if classOf target != RigidPartHelper then throw "Invalid Rigid part helper object."

		target.dragX    = drag.x
		target.dragY    = drag.y
		target.dragZ    = drag.z
		target.autoDrag = false

		-- Build bounding box and bounding sphere
		if extents then (
			AddToLayer "Extents" (Dummy name:(target.name + "_Extent") parent:target transform:(preTranslate target.transform (0.5 * (minimum + maximum))) boxSize:(maximum - minimum) wireColor:target.wireColor)
			AddToLayer "Extents" (SphereGizmo name:(target.name + "_Sphere") parent:target transform:(preTranslate target.transform center) radius:radius wireColor:target.wireColor)
		)

		-- Build center offset as Point helper
		if centers then AddToLayer "Centers" (Point name:target.name parent:target transform:(preTranslate target.transform center) centerMarker:true axisTripod:false cross:false box:false drawOnTop:true wireColor:target.wireColor)

		local queue = #(#(target, undefined, root))

		local parent     -- Parent SurfaceNodeHelper
		local parentNode -- Parent SurfaceNode
		local current    -- Current SurfaceNode
		local result     -- SurfaceNodeHelper made from current SurfaceNode
		local hull       -- Editable_mesh made from SurfaceHull

		local nodeCount = 0
		
		local meshIDs = #()
		local meshes  = #()

		local hashes  = #()
		local names   = #()
		local index   = 0

		local nodeColor
		local hullColor
		local hullPoints
		local validPoints

		MAXLancer.GetModelHashes target names hashes

		-- Walk over SurfaceNodes
		if hulls or wraps or nodes then while queue.count > 0 do (
			parent     = queue[queue.count][1]
			parentNode = queue[queue.count][2]
			current    = queue[queue.count][3]
			queue.count = queue.count - 1

			nodeColor = if nodes then color 96 96 96 else target.wireColor
			nodeCount += 1

			-- Test node boundaries
			if parentNode != undefined then (
				if not parentNode.IntersectsNode current epsilon:epsilon then (
					MAXLancer.WriteLog ("WARNING: Node " + formattedPrint nodeCount format:"u" + " is outside parent node!")
					if nodes then nodeColor = color 160 0 0
				) else if not parentNode.ContainsNode current epsilon:epsilon then (
					MAXLancer.WriteLog ("WARNING: Node " + formattedPrint nodeCount format:"u" + " exceeds boundaries of parent node!")
					if nodes then nodeColor = color 160 160 0
				)
			)

			-- Build SurfaceNodeHelper
			if nodes and parent != undefined then (
				result = current.Build target
				
				result.name     += formattedPrint nodeCount format:"04u"
				result.wireColor = nodeColor
				result.parent    = parent
				
				AddToLayer "Nodes" result
			)

			-- Queue up left and right nodes
			if classOf current.left == SurfaceNode then  append queue #(result, current, current.left)
			if classOf current.right == SurfaceNode then append queue #(result, current, current.right)

			-- Build wrap or hull Editable_mesh
			if classOf current.hull == SurfaceHull and ((wraps and current.hull.type == 5) or (hulls and current.hull.type == 4)) then (

				-- Test if any or all hull points are outside node boundaries
				hullPoints  = current.hull.GetPointIndices()
				validPoints = current.ContainsPoints (for p in hullPoints collect points[p].position) epsilon:epsilon
				hullColor   = if nodes then color 192 192 192 else target.wireColor

				if validPoints.numberSet == 0 then (
					MAXLancer.WriteLog ("WARNING: Hull in node " + formattedPrint nodeCount format:"u" + " is outside parent node!");
					if nodes then hullColor = color 255 0 0
				) else if validPoints.numberSet < hullPoints.numberSet then (
					MAXLancer.WriteLog ("WARNING: Hull in node " + formattedPrint nodeCount format:"u" + " exceeds boundaries of parent node!")
					if nodes then hullColor = color 255 255 0
				)

				-- Build hull mesh
				hull = current.hull.Build points
				meshOp.deleteIsoVerts hull

				for f = 1 to getNumFaces hull do setFaceSmoothGroup hull f 1

				if classOf progress == MAXScriptFunction then progress (getNumFaces hull)

				hull.parent    = if isValidNode result then result else target
				hull.transform = target.transform
				hull.wireColor = hullColor

				if not nodes then hull.material = MAXLancer.surfaceMaterial

				-- Restore name from hash dictionary
				if (index = findItem hashes current.hull.hullID) > 0 then hull.name = names[index]

				if current.hull.type == 4 then (
					if not compound and index == 0 then hull.name = target.name

					AddToLayer "Hulls" hull
				) else (
					hull.name = target.name + "_Wrap"
					AddToLayer "Wraps" hull
				)

				-- Merge hulls matching IDs
				if not nodes then (
					index = findItem meshIDs current.hull.hullID

					if index > 0 then meshOp.attach meshes[index] hull else (
						append meshes hull
						append meshIDs current.hull.hullID
					)
				)
			)

			-- Update progress on every node
			if classOf progress == MAXScriptFunction then progress 1
		)
	),

	-- Read SurfacePart surfaces (header, SurfaceHulls, SurfacePoints and SurfaceNodes)
	fn ReadSurfaces stream = (
		local size        = ReadLong stream #unsigned
		local startOffset = ftell stream
		local endOffset   = startOffset + size

		ReadPosition stream center  -- Bounding box center
		ReadPosition stream drag    -- Linear drag vector

		radius = ReadFloat stream -- Bounding box radius

		local header = ReadLong stream #unsigned -- Scale (1 byte); Nodes end offset (3 bytes)
		scaler = ((bit.and header 0xFF) as Float) / 0xFA -- Bounding box radius scaler for sphere that only contains to non-hardpoint hulls
		
		local nodesEndOffset    = startOffset + (bit.shift header -8)
		local nodesStartOffset  = startOffset + (ReadLong stream #unsigned)
		local pointsStartOffset = 0 -- Offset to hull points

		ReadPosition stream unknown -- Unknown/unused vector

		local nodeOffset  = 0 -- Currently read node offset
		local rightOffset = 0 -- Offset to right child
		local leftOffset  = 0 -- Offset to left child (is always next one unless node has hull)
		local hullOffset  = 0 -- Offset to hull

		local parentNode   -- SurfaceNode
		local currentNode  -- SurfaceNode
		local currentPoint -- SurfacePoint

		local queue = #(DataPair undefined nodesStartOffset)

		-- Read nodes in order as they appear in tree
		while queue.count > 0 do (
			parentNode  = queue[queue.count].v1
			nodeOffset  = queue[queue.count].v2
			queue.count = queue.count - 1

			if nodeOffset < nodesStartOffset or nodeOffset > nodesEndOffset then throw ("Node offset is out of bounds " + formatID nodeOffset)
			if not fseek stream nodeOffset #seek_set then throw ("Error seek to node at " + formatID nodeOffset)

			-- Read offsets to right child and hull
			if (rightOffset = ReadLong stream #signed) != 0 then rightOffset += nodeOffset -- Absolute offset to right child
			if (hullOffset  = ReadLong stream #signed) != 0 then hullOffset  += nodeOffset -- Absolute offset to associated hull

			currentNode = SurfaceNode()
			currentNode.ReadStream stream

			leftOffset = ftell stream -- Left child is always next node in sequence unless current node is leaf

			-- Assign to parent node
			if parentNode == undefined then root = currentNode else
				if parentNode.left == undefined then parentNode.left = currentNode else
				if parentNode.right == undefined then parentNode.right = currentNode

			-- Read referenced hull
			if hullOffset > 0 then (
				if not fseek stream hullOffset #seek_set then throw ("Error seek to hull offset at " + formatID hullOffset)

				pointsStartOffset = (ReadLong stream #signed) + hullOffset

				currentNode.hull = SurfaceHull()
				currentNode.hull.ReadStream stream

				fseek stream leftOffset #seek_set -- Return to back to next node
			)

			if currentNode.hull == undefined or currentNode.hull.type == 5 then (
				if rightOffset != 0 then append queue (DataPair currentNode rightOffset)
				if leftOffset != 0  then append queue (DataPair currentNode leftOffset)
			)
		)

		if not fseek stream pointsStartOffset #seek_set then throw ("Error seek to first point offset at " + formatID pointsStartOffset)

		-- Read points used by hulls
		while (ftell stream) < nodesStartOffset do (
			currentPoint = SurfacePoint()
			currentPoint.ReadStream stream
			append points currentPoint
		)

		-- Move to end
		if not fseek stream endOffset #seek_set then throw ("Error seek to end of part section at " + formatID endOffset)
		OK
	),

	-- Write SurfacePart surfaces (header, SurfaceHulls, SurfacePoints and SurfaceNodes)
	fn WriteSurfaces stream = (
		local startOffset = 4 + ftell stream -- Remember start offset for section

		fseek stream 52 #seek_cur -- Skip section size and header

		local hulls   = GetHulls wrap:true -- Array of SurfaceHull
		local offsets = #()                -- Offsets for hulls, Array of Integer

		-- Write SurfaceHulls
		for i = 1 to hulls.count do (
			offsets[i] = ftell stream

			WriteLong stream 0 -- Skip offset to points
			hulls[i].WriteStream stream
		)

		-- Write SurfacePoints
		local pointsStartOffset = ftell stream -- Remember start offset for points

		for p in points do p.WriteStream stream

		local nodesStartOffset = ftell stream -- Remember start offset for nodes

		-- Update offsets in hulls to points start and nodes start for wrap hull
		for i = 1 to hulls.count do (
			offset = offsets[i]

			fseek stream offset #seek_set
			WriteLong stream (pointsStartOffset - offset)

			if hulls[i].type == 5 then WriteLong stream (nodesStartOffset - offset)
		)

		local queue = #(DataPair 0 root)

		local currentNode   -- SurfaceNode
		local currentOffset -- Offset to current SurfaceNode
		local parentOffset  -- Offset to parent SurfaceNode

		fseek stream nodesStartOffset #seek_set

		-- Write SurfaceNodes
		while queue.count > 0 do (
			parentOffset = queue[queue.count].v1
			currentNode  = queue[queue.count].v2
			queue.count  = queue.count - 1

			currentOffset = ftell stream -- Remember current node offset

			-- Current node is right child of its parent node
			if parentOffset > 0 then (
				fseek stream parentOffset #seek_set             -- Seek to parent offset
				WriteLong stream (currentOffset - parentOffset) -- Update its right offset relative to current
				fseek stream currentOffset #seek_set            -- Return back to current node
			)
		
			WriteLong stream 0 -- Relative offset to right child (0 as we don't know ahead of time where right node gonna be)
			WriteLong stream (if classOf currentNode.hull == SurfaceHull then -(currentOffset - offsets[findItem hulls currentNode.hull]) else 0) -- Relative offset to hull

			currentNode.WriteStream stream

			if currentNode.right != undefined then append queue (DataPair currentOffset currentNode.right)
			if currentNode.left  != undefined then append queue (DataPair 0 currentNode.left)
		)

		local endOffset = ftell stream -- Remember end of section offset

		-- Move back to start
		fseek stream (startOffset - 4) #seek_set

		-- Write header
		WriteLong     stream (endOffset - startOffset) #unsigned
		WritePosition stream center
		WritePosition stream drag
		WriteFloat    stream radius
		WriteLong     stream (bit.or (int (scaler * 0xFA)) (bit.shift (endOffset - startOffset) 8)) #unsigned
		WriteLong     stream (nodesStartOffset - startOffset) #unsigned
		WritePoint3   stream unknown

		-- Move to end
		fseek stream endOffset #seek_set
		OK
	),

	-- Read SurfacePart extents
	fn ReadExtents stream = (
		minimum.x =  ReadFloat stream
		minimum.z =  ReadFloat stream
		maximum.y = -ReadFloat stream
		maximum.x =  ReadFloat stream
		maximum.z =  ReadFloat stream
		minimum.y = -ReadFloat stream
		OK
	),

	-- Write SurfacePart extents
	fn WriteExtents stream = (
		WriteFloat stream  minimum.x
		WriteFloat stream  minimum.z
		WriteFloat stream -maximum.y
		WriteFloat stream  maximum.x
		WriteFloat stream  maximum.z
		WriteFloat stream -minimum.y
		OK
	),
		
	-- Read SurfacePart hardpoints
	fn ReadHardpoints stream = (
		hardpoints = for i = 1 to ReadLong stream #unsigned collect ReadLong stream #unsigned
		OK
	),

	-- Write SurfacePart hardpoints
	fn WriteHardpoints stream = (
		WriteLong stream hardpoints.count
		for i = 1 to hardpoints.count do WriteLong stream hardpoints[i] #unsigned
		OK
	),

	-- Read SurfacePart
	fn ReadStream stream = (
		partID = ReadLong stream #unsigned

		MAXLancer.WriteLog ("Reading surface part: " + formatID partID)

		local sectionCount = ReadLong stream #unsigned

		for s = 1 to sectionCount do case ReadLong stream of (
			0x64786621: dynamic = true
			0x73747865: ReadExtents    stream
			0x66727573: ReadSurfaces   stream
			0x64697068: ReadHardpoints stream
			default:    throw "Unknown surface section type"
		)

		OK
	),

	-- Write SurfacePart
	fn WriteStream stream = (
		WriteLong stream partID #unsigned

		MAXLancer.WriteLog ("Writing surface part: " + formatID partID)

		local sectionCount = 2 -- Extents and surfaces
		
		if dynamic then sectionCount += 1
		if hardpoints.count > 0 then sectionCount += 1

		WriteLong stream sectionCount

		if dynamic then WriteLong stream 0x64786621 #unsigned -- !fxd flag
		if WriteLong stream 0x73747865 #unsigned then WriteExtents stream
		if WriteLong stream 0x66727573 #unsigned then WriteSurfaces stream
		if hardpoints.count > 0 and WriteLong stream 0x64697068 #unsigned then WriteHardpoints stream

		OK
	)	
)

struct SurfaceLibrary (
	signature = 0x73726576, -- Surface FourCC ("surf")
	version   = 2.0,        -- Surface version
	parts     = #(),        -- Array of SurfacePart

	-- Get SurfacePart by matching ID
	fn GetPart id = (
		id = MAXLancer.hash id

		local result
		for part in parts while result == undefined where part.partID == id do result = part
		result -- Return SurfacePart
	),

	-- Get array of Editable_mesh for hitbox from RigidPartHelper
	fn GetPartSurfaces root &hardpoints &center recursive:true = (
		if classOf root != RigidPartHelper then throw "Invalid RigidPartHelper object."

		local result = #()     -- Array of Editable_mesh
		local queue  = #(root) -- Array of RigidPartHelper
		local target           -- RigidPartHelper

		local globalIDs = #() -- Array of Integer
		local localIDs  = #() -- Array of Integer 
		local hullID

		center     = [0, 0, 0]
		hardpoints = #()
		
		-- Pulls meshes from descendant RigidPartHelper which have fixed joint controller
		while queue.count > 0 do (
			target = queue[queue.count]
			queue.count = queue.count - 1

			localIDs.count = 0

			for child in target.children do case classOf child of (
				SurfaceNodeHelper: append queue child
				Point:             if target == root and child.name == root.name then center = child.transform.translationpart * inverse root.transform
				HardpointHelper:   if appendIfUnique hardpoints (hullID = MAXLancer.Hash child.name) and child.hullShape > 1 and findItem globalIDs hullID == 0 then (
					append result child
					appendIfUnique localIDs hullID
				)
				RigidPartHelper:   if recursive and classOf child.transform.controller == FixedJointController then append queue child
				Editable_mesh:     if custAttributes.get child VMeshAttributes == undefined and findItem globalIDs (hullID = MAXLancer.Hash child.name) == 0 then (
					append result child
					appendIfUnique localIDs hullID
				)
			)

			if classOf target == RigidPartHelper then makeUniqueArray (join globalIDs localIDs)
		)

		-- Filter hardpoint IDs by existing hulls matching IDs
		hardpoints = for hardpointID in hardpoints where findItem globalIDs hardpointID > 0 collect hardpointID

		result -- Return array of Editable_mesh
	),	

	-- Load library from file
	fn LoadFile filename = (
		MAXLancer.WriteLog ("Loading surfaces file: " + filename)

		local stream = fopen filename "rb"
		local size   = (getFileSize filename)
		local part

		if ReadLong stream != signature then throw "Invalid SUR signature."
		if ReadFloat stream != version then throw "Invalid SUR version."

		while (ftell stream) < size do (
			part = SurfacePart()
			part.ReadStream stream

			append parts part
		)

		fclose stream
		OK
	),

	-- Save library into file
	fn SaveFile filename = (
		MAXLancer.WriteLog ("Saving surfaces file: " + filename)

		local stream = fopen filename "wb"
		
		WriteLong stream signature #unsigned
		WriteFloat stream version

		for part in parts do part.WriteStream stream
		fclose stream
		OK
	),

	-- Parse rigid model into SurfaceParts
	fn Parse root compound forceConvex:false progress: = (
		if classOf root != RigidPartHelper then throw "Invalid RigidPartHelper object."

		local queue = #(root)
		local target -- Current RigidPartHelper
		local part   -- Built SurfacePart

		while queue.count > 0 do (
			target = queue[queue.count]
			queue.count = queue.count - 1

			-- Queue up children ahead
			if compound then for child in target.children where classOf child == classOf root do append queue child

			part = SurfacePart()
			part.Parse target compound forceConvex:forceConvex progress:progress

			if part.root == undefined then continue -- Skip
			if GetPart part.partID != undefined then throw ("Duplicate surface part for " + target.name)
			
			MAXLancer.WriteLog ("Adding part surfaces: " + target.name)
			append parts part
		)

		OK
	),

	-- Build SurfaceParts for rigid model
	fn Build root compound centers:true extents:false nodes:false hulls:true wraps:false dupes:true progress: = (
		if classOf root != RigidPartHelper then throw "Invalid RigidPartHelper object."

		local queue = #(root)
		local target -- Current RigidPartHelper
		local part   -- Matching SurfacePart
		local subparts = #()

		while queue.count > 0 do (
			target = queue[queue.count]
			queue.count = queue.count - 1

			-- Queue up children ahead
			if compound then for child in target.children where classOf child == classOf root do append queue child

			part = GetPart (if compound then target.name else 0)
			if part == undefined then continue -- Skip
			
			MAXLancer.WriteLog ("Building part surfaces: " + target.name)
			part.Build target compound centers:centers extents:extents nodes:nodes hulls:hulls wraps:wraps progress:progress

			if target != root then append subparts target
		)

		if not dupes then (
			local hullIDs

			-- For each part that isn't root
			for part in subparts do (

				-- Get list of hull IDs in it
				hullIDs = makeUniqueArray (for child in part.children where classOf child == Editable_mesh and custAttributes.get child VMeshAttributes == undefined collect MAXLancer.Hash child.name)

				-- Delete hulls in ancestors matching own hulls
				for parent in MAXLancer.GetPartParents part do
					for child in parent.children where classOf child == Editable_mesh and custAttributes.get child VMeshAttributes == undefined and findItem hullIDs (MAXLancer.Hash child.name) do delete child
			)

		)

		OK
	)
)
