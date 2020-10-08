/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Internal QuickHull implementation for convex hull and alternative as wrapper for Nvidia PhysX.
 */

-- Points map calculated for face plane or edge vector
struct PointsMap (
	above    = #{},    -- Points above the plane
	below    = #{},    -- Points below the plane (or considered "on the plane" within threshold)
	farthest = [0, 0], -- Farthest point above and below the vecor [below, above]
	heights  = [0, 0], -- Absolute height for farthest points [below, above]
	
	-- Return flipped map
	fn flip = PointsMap above:below below:above farthest:[farthest.y, farthest.x] heights:[heights.y, heights.x]
)

-- Calculate distance from points to edge (vector)
fn GetEdgePoints edge vertices indices epsilon = (
	local result  = PointsMap()
	local offsets = [3.4e38, -3.4e38]
	local a = vertices[edge.x]
	local b = vertices[edge.y]
	
	for i in indices do (
		local c  = vertices[i]
		local bd = b - a
		local cd = c - a
		local cp = bd.x * cd.y - bd.y * cd.x -- Cross product to determine which side C is at
		local u  = ((c.x - a.x) * bd.x + (c.y - a.y) * bd.y) / (bd.x * bd.x + bd.y * bd.y) -- Projection position: 0.0 at point A, 1.0 at point B
		local d  = distance c (a + bd * u) -- Absolute distance from C to projection point
		
		case of (
			(d <= epsilon): result.below[i] = true
			(cp < 0): (
				result.below[i] = true
				
				if abs (d - result.heights.x) <= epsilon then (
					if u < offsets.x then (result.farthest.x = i; offsets.x = u)
				) else if d > result.heights.x then (result.farthest.x = i; result.heights.x = d; offsets.x = u)
			)
			(cp > 0): (
				result.above[i] = true
				
				if abs (d - result.heights.y) <= epsilon then (
					if u > offsets.y then (result.farthest.y = i; offsets.y = u)
				) else if d > result.heights.y then (result.farthest.y = i; result.heights.y = d; offsets.y = u)
			)
		)
	)

	result
)

fn GetRectangleExtremes vertices epsilon = (
	local minimum = [3.4e38, 3.4e38]
	local maximum = [-3.4e38, -3.4e38]
	local extremes = for s = 1 to 4 collect [0, 0]

	for v = 1 to vertices.count do (
		local position = vertices[v]
	
		-- Left
		if abs (position.x - minimum.x) <= epsilon then (
			if position.y > vertices[extremes[1].y].y then extremes[1].y = v else if position.y < vertices[extremes[1].x].y then extremes[1].x = v
		) else if position.x < minimum.x then (minimum.x = position.x; extremes[1] = [v, v])
		
		-- Right
		if abs (position.x - maximum.x) <= epsilon then (
			if position.y > vertices[extremes[2].y].y then extremes[2].y = v else if position.y < vertices[extremes[2].x].y then extremes[2].x = v
		) else if position.x > maximum.x then (maximum.x = position.x; extremes[2] = [v, v])
		
		-- Bottom
		if abs (position.y - minimum.y) <= epsilon then (
			if position.x > vertices[extremes[3].y].x then extremes[3].y = v else if position.x < vertices[extremes[3].x].x then extremes[3].x = v
		) else if position.y < minimum.y then (minimum.y = position.y; extremes[3] = [v, v])

		-- Top
		if abs (position.y - maximum.y) <= epsilon then (
			if position.x > vertices[extremes[4].y].x then extremes[4].y = v else if position.x < vertices[extremes[4].x].x then extremes[4].x = v
		) else if position.y > maximum.y then (maximum.y = position.y; extremes[4] = [v, v])
	)
	
	local result = #{}
	for s = 1 to 4 do result[extremes[s].x] = result[extremes[s].y] = true

	result
)

-- Generate initial 2D simplex from rectangle extremes
fn GenerateTriangle vertices extremes indices epsilon = (
	local maxDistance = epsilon
	local corners     = [0, 0, 0]

	-- Find farthest points to form triangle base
	for a in extremes do for b in extremes where a != b do (
		local d = distance vertices[a] vertices[b]
		if d > maxDistance then (maxDistance = d; corners.x = a; corners.y = b)
	)

	if corners.x > 0 and corners.y > 0 then (
		indices[corners.y] = indices[corners.x] = false

		-- Calculate points projection distance to find triangle height point
		local basePoints = GetEdgePoints corners vertices indices epsilon

		-- Get farthest point from line on either side
		corners.z = if abs basePoints.heights.x > abs basePoints.heights.y then basePoints.farthest.x else basePoints.farthest.y

		if corners.z > 0 then (
			indices[corners.z] = false

			if basePoints.above[corners.z] then corners = [corners.z, corners.y, corners.x]  -- Flip triangle vertex order
		) -- Rest of the points are on line
	)

	corners
)

-- Returns vertices found to be inside convex shape or on line
fn GetConvexShape vertices indices normal epsilon = (
	local inverseTM  = inverse (matrixFromNormal normal)
	local indicesMap = #()
	local positions  = #()

	for i in indices do (
		append indicesMap i
		append positions (vertices[i] * inverseTM * [1, 1, 0])
	)

	local points      = #{1..positions.count}
	local shapePoints = #{} -- Points forming convex shape border
	local result      = #{} -- Vertices inside convex shape to be excluded

	local extremes = GetRectangleExtremes positions epsilon
	local corners  = GenerateTriangle positions extremes points epsilon

	if corners.z > 0 then (
		local edges      = #{1..3}
		local edgePairs  = #([corners.x, corners.y], [corners.y, corners.z], [corners.z, corners.x])
		local edgePoints = for pair in edgePairs collect GetEdgePoints pair positions points epsilon
		local stepCount  = 0
		
		shapePoints[corners.x] = shapePoints[corners.y] = shapePoints[corners.z] = true

		while not points.isEmpty do (
			stepCount += 1
			
			local insidePoints = copy points
			local t = 0
			
			for p in edges do (
				insidePoints *= edgePoints[p].below
				
				if edgePoints[p].above.numberSet == 0 then edges[p] = false else
				if t == 0 and edgePoints[p].farthest.y > 0 and points[edgePoints[p].farthest.y] then t = edgePoints[p].farthest.y
			)
			
			points -= insidePoints
			
			if t > 0 then (
				-- Find active vertices of this position and discard all to avoid duplicate issues
				for p in points where distance positions[t] positions[p] <= epsilon do points[p] = false
				
				shapePoints[t] = true
				
				local visibleEdges = #{}
				local startPoints  = #{}
				local endPoints    = #{}
				local borderPoints = [0, 0]
				local edgeIndex    = edgePairs.count

				for f in edges where visibleEdges[f] = edgePoints[f].above[t] do endPoints[edgePairs[f].y] = startPoints[edgePairs[f].x] = true
				
				edges[edgeIndex + 1] = true
				edges[edgeIndex + 2] = true
				edgePairs[edgeIndex + 1] = [((startPoints - endPoints) as array)[1], t]
				edgePairs[edgeIndex + 2] = [t, ((endPoints - startPoints) as array)[1]]
				edgePoints[edgeIndex + 1] = GetEdgePoints edgePairs[edgeIndex + 1] positions points epsilon
				edgePoints[edgeIndex + 2] = GetEdgePoints edgePairs[edgeIndex + 2] positions points epsilon
				
				edges -= visibleEdges
			) else points = #{}
		)
		
		for i in #{1..positions.count} - shapePoints do result[indicesMap[i]] = true
	) else result = indices - #{indicesMap[corners.x], indicesMap[corners.y]} -- It is a line with point(s) in between

	result
)

-- Calculate distances of points referenced in indices bitarray to face plane and put them into bitarrays
fn GetFacePoints face vertices indices epsilon = (
	local normal = normalize (cross (vertices[face.y] - vertices[face.x]) (vertices[face.z] - vertices[face.x]))
	local dist   = dot -normal vertices[face.x]
	local result = PointsMap()
		
	local top    = #{}
	local bottom = #{}

	for i in indices do (
		local d = dot normal vertices[i] + dist -- Distance calculation is prone to errors
		
		case of (
			(abs d <= epsilon): result.below[i] = true -- Point is on plane
			(d < 0): (
				result.below[i] = true
				
				if abs (d - result.heights.x) <= epsilon then bottom[i] = true else
				if d < result.heights.x then (result.heights.x = abs d; bottom = #{i})
				
			)
			(d > 0): (
				result.above[i] = true
				
				if abs (d - result.heights.y) <= epsilon then top[i] = true else
				if d > result.heights.y then (result.heights.y = d; top = #{i})
			)
		)
	)

	if bottom.numberSet > 0 and bottom.numberSet < 3 then result.farthest.x = (bottom as array)[1]
	if bottom.numberSet >= 3 then (indices -= GetConvexShape vertices bottom -normal epsilon; result.farthest.x = ((bottom * indices) as array)[1])

	if top.numberSet > 0 and top.numberSet < 3 then result.farthest.y = (top as array)[1]
	if top.numberSet >= 3 then (indices -= GetConvexShape vertices top normal epsilon; result.farthest.y = ((top * indices) as array)[1])
	
	result
)

-- Collect points on bounding box sides and adjust epsilon by box limits
fn GetCubeExtremes vertices indices &epsilon = (

	local minimum   = [3.4e38, 3.4e38, 3.4e38]
	local maximum   = [-3.4e38, -3.4e38, -3.4e38]
	local limits    = [0, 0, 0]
	local extremes  = for s = 1 to 6 collect #{}
	local discarded = #{} -- Indices discarded
	local result    = #{}
	local position
	
	for i = 1 to vertices.count do (
		position = vertices[i]

		if abs (position.x - minimum.x) <= epsilon then extremes[1][i] = true else if position.x < minimum.x then (minimum.x = position.x; extremes[1] = #{i})
		if abs (position.y - minimum.y) <= epsilon then extremes[2][i] = true else if position.y < minimum.y then (minimum.y = position.y; extremes[2] = #{i})
		if abs (position.z - minimum.z) <= epsilon then extremes[3][i] = true else if position.z < minimum.z then (minimum.z = position.z; extremes[3] = #{i})

		if abs (position.x - maximum.x) <= epsilon then extremes[4][i] = true else if position.x > maximum.x then (maximum.x = position.x; extremes[4] = #{i})
		if abs (position.y - maximum.y) <= epsilon then extremes[5][i] = true else if position.y > maximum.y then (maximum.y = position.y; extremes[5] = #{i})
		if abs (position.z - maximum.z) <= epsilon then extremes[6][i] = true else if position.z > maximum.z then (maximum.z = position.z; extremes[6] = #{i})
		
		limits.x = amax limits.x (abs position.x)
		limits.y = amax limits.y (abs position.y)
		limits.z = amax limits.z (abs position.z)
	)
	
	-- epsilon *= limits.x + limits.y + limits.z
	epsilon = 2.^(int(log (amax limits.x limits.y limits.z) / log 2) - 23)

	local size  = maximum - minimum
	local sides = #([-1, 0, 0], [0, -1, 0], [0, 0, -1], [1, 0, 0], [0, 1, 0], [0, 0, 1])
	
	if size.x > epsilon and size.y > epsilon and size.z > epsilon then (
		for s = 1 to 6 do (
			if extremes[s].numberSet > 2 then (
				local discarded = GetConvexShape vertices extremes[s] sides[s] epsilon
				result += extremes[s] * (indices - discarded)
				indices -= discarded
			) else result += extremes[s]
		)
	)

	result
)

fn GenerateTetrahedron vertices extremes indices epsilon = (
	local result
	local corners = [0, 0, 0, 0] -- Four points forming tetrahedron
	local maxDistance = epsilon

	-- Find first and second points of tetrahedron
	for a in extremes do for b in extremes where a != b do (
		local d = distance vertices[a] vertices[b]			
		if d > maxDistance then (maxDistance = d; corners.x = a; corners.y = b)
	)

	-- First two points found
	if corners.x > 0 and corners.y > 0 then (
		indices[corners.x] = indices[corners.y] = false -- Exclude first two points
		
		-- Find third point of tetrahedron
		maxDistance = epsilon
		
		for i in indices do (
			local ab = vertices[corners.y] - vertices[corners.x]
			local ac = vertices[i] - vertices[corners.x]
			local d = length (cross ab ac) / length ab
			
			if d > maxDistance then (maxDistance = d; corners.z = i)
		)

		-- Third point found
		if corners.z > 0 then (
			indices[corners.z] = false -- Exclude third point

			local facePoints = GetFacePoints corners vertices indices epsilon
			corners.w = if abs facePoints.heights.x > abs facePoints.heights.y then facePoints.farthest.x else facePoints.farthest.y
			
			-- Fourth point found
			if corners.w > 0 then (
				indices[corners.w] = false -- Exclude fourth point

				result = TriMesh()
				
				setNumVerts result vertices.count false
				for v = 1 to vertices.count do in coordsys local setVert result v vertices[v]	

				setNumFaces result 4 false

				if facePoints.above[corners.w] then (
					setFace result 1 corners.z corners.y corners.x
					setFace result 2 corners.w corners.x corners.y
					setFace result 3 corners.w corners.y corners.z
					setFace result 4 corners.w corners.z corners.x
				) else (
					setFace result 1 corners.x corners.y corners.z
					setFace result 2 corners.y corners.x corners.w
					setFace result 3 corners.z corners.y corners.w
					setFace result 4 corners.x corners.z corners.w
				)
				
				-- if facePoints.above[corners.w] then meshOp.flipNormals result #all
			) -- Fourth point not found
		) -- Third point not found
	) -- First two points not found

	result
)

-- Generate convex hull using my adaptation of QuickHull
fn GenerateConvexHullQH vertices maxVertices: epsilon:0.00001 delIsoVerts:false fixEdges:true = (
	
	-- Clamp maxVertices
	if maxVertices == unsupplied or maxVertices > vertices.count then maxVertices = vertices.count
	if maxVertices < 4 then maxVertices = 4

	local start = timestamp()

	if vertices.count > 3 then (
		local indices  = #{1..vertices.count} -- Active indices (vertices to check for plane distane)

		-- TODO: Walk through vertices and throw away duplicates from indices bitarray

		local extremes = GetCubeExtremes vertices indices &epsilon
		local result   = GenerateTetrahedron vertices extremes indices epsilon
	) else throw "Too few vertices."

	-- In some cases tetrahedron cannot be made, for example all points are on plane, or all points are on line or even all points being in one place
	if result == undefined then throw "Unable to generate convex hull. Check if all points are on same plane."

	local facePoints     = for f = 1 to getNumFaces result collect GetFacePoints (getFace result f) vertices indices epsilon -- Calculate initial points to face plane set
	local activeFaces    = #{1..getNumFaces result} -- Faces to test for points above
	local hullIndices    = #{1..vertices.count} - indices -- Vertices which form outer shell
	local discardedFaces = #{} -- Faces marked null are to be removed at the end
	local stepCount      = 0   -- Iteration step counter
	
	local visibleFaces -- Faces visible to farthest point
	local visibleEdges -- Edge pairs of visible faces
	local t, height    -- Extrusion point index and height
	
	while not indices.isEmpty and hullIndices.numberSet < maxVertices do (
		stepCount += 1
		t = height = 0
		
		local insideIndices = copy indices -- Assume all points are inside hull until distance to any face plane is positive
		
		-- Discard points inside mesh and find farthest point for extrusion
		for f in activeFaces do (
			insideIndices *= facePoints[f].below -- Reduce set to points below all tested faces
			
			if facePoints[f].above.numberSet == 0 then activeFaces[f] = false else -- Nothing above, skip on next iterations
			if facePoints[f].farthest.y > 0 and facePoints[f].heights.y > height and indices[facePoints[f].farthest.y] then (t = facePoints[f].farthest.y; height = facePoints[f].heights.y) -- Pick extrusion point
		)
		
		indices -= insideIndices -- Discard indices found to be inside mesh to calculate less in GetFacePoints
	
		if t > 0 then (

			-- Find active vertices of this position and discard ones too close to avoid duplicate issues
			for i in indices where distance vertices[t] vertices[i] <= epsilon do indices[i] = false

			hullIndices[t] = true
			
			visibleFaces = #{}
			visibleEdges = #()

			-- Collect faces visible to farthest point
			for f in activeFaces do visibleFaces[f] = facePoints[f].above[t]
				
			-- Collect pairs of vertices of each visible face edge
			for f in visibleFaces do (
				local face = getFace result f
				join visibleEdges #([face.x, face.y], [face.y, face.z], [face.z, face.x])
			)
			
			-- Any edge pair without matching reverse pair in the list is border edge
			local borderPairs = for visibleEdge in visibleEdges where findItem visibleEdges [visibleEdge.y, visibleEdge.x] == 0 collect [visibleEdge.x, visibleEdge.y]
			
			-- Add new faces to hull
			local f = getNumFaces result
			setNumFaces result (borderPairs.count + f) true
			
			-- Build faces from border edges to farthest point
			for pair in borderPairs do (
				local face = [pair.x, pair.y, t]
				setFace result (f += 1) face
				
				-- Add new face and calculate distance to active points
				facePoints[f]  = GetFacePoints face vertices indices epsilon
				activeFaces[f] = true
			)
			
			activeFaces    -= visibleFaces -- Discard faces visible by farthest point
			discardedFaces += visibleFaces -- Put visible faces into delete list
			
			meshop.setHiddenFaces result discardedFaces
		) else indices = #{} -- Remaining points are inconsequential
	)
	
	free facePoints
	
	meshOp.deleteFaces result discardedFaces delIsoVerts:delIsoVerts
	
	-- Vertify that there are no open edges and each edge has reverse
	local edgeList = meshop.getEdgesReverseEdge result #all

	if edgeList.numberSet == edgeList.count then (
		if fixEdges then for f = 1 to getNumFaces result do (
			setEdgeVis result f 1 true
			setEdgeVis result f 2 true
			setEdgeVis result f 3 true
			setFaceSmoothGroup result f 0
		)

		update result
		result
	)
)

-- Generate convex hull using Nvidia PhysX API
fn GenerateConvexHullNVPX vertices maxVertices: epsilon:0.025 delIsoVerts:false = (
	if maxVertices == unsupplied or maxVertices > vertices.count then maxVertices = vertices.count

	local result       -- Resulting TriMesh with correct vertices
	local hull         -- TriMesh produced by nvpx
	local points = #() -- Array of floats
	local map    = #() -- Array of integers mapping vertex index in nvpx TriMesh to vertices array
	local faces  = #() -- Array of point3 for result TriMesh
	local position
	local face
	
	-- Collect vertices into array of floats the way nvpx needs it
	for v = 1 to vertices.count do join points #(vertices[v].x, vertices[v].y, vertices[v].z)

	-- Generate convex hull from points
	hull = nvpx.CreateConvexFromPoints &points maxVertices 0.0

	/**
	 * Because nvpx deletes isolated vertices the mesh have vertices not matching order of original vertices passed into it, not only that but
	 * coordinates are not bit-exact match to originals (probably because of even zero inflation it still causes error drift)
	 */

	if hull != undefined then (
		result = TriMesh()
		
		for p = 1 to getNumVerts hull while result != undefined do (
			position = getVert hull p

			-- Find vertex in original array matching vertex in nvpx mesh
			for v = 1 to vertices.count while map[p] == undefined where abs (position.x - vertices[v].x) <= epsilon and abs (position.y - vertices[v].y) <= epsilon and abs (position.z - vertices[v].z) <= epsilon do map[p] = v
			
			if map[p] == undefined then result = undefined
		)

		if result != undefined then (
			
			-- Make result faces from hull faces with hull vertices remapped to original vertices
			for f = 1 to (faces.count = getNumFaces hull) do (face = getFace hull f; faces[f] = [map[face.x], map[face.y], map[face.z]])

			setMesh result vertices:vertices faces:faces

			if delIsoVerts then meshop.deleteIsoVerts result
			
			for f = 1 to getNumFaces result do setFaceSmoothGroup result f 0

			update result
		)
	)

	result
)