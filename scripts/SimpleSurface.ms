/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Surfaces (convex hulls) used for Aftermath mod. A much simplified format compared to vanilla .sur.
 * Only export is supported.
 */

struct SimpleSurfaceHull (
	hullID        = 0,
	startTriangle = 0,
	triangleCount = 0,

	minimum = [0, 0, 0],
	maximum = [0, 0, 0],
	center  = [0, 0, 0],
	radius  = 0,

	fn WriteStream stream = (
		MAXLancer.WriteLog ("\tHull (" + formatID hullID + "): start: " + formattedPrint startTriangle format:"d" + ", count: " + formattedPrint triangleCount format:"d")

		WriteLong stream hullID #unsigned
		WriteShort stream startTriangle #unsigned
		WriteShort stream triangleCount #unsigned

		MAXLancer.WriteLog ("\t\tBounding box minimum: " + minimum as string)
		MAXLancer.WriteLog ("\t\tBounding box maximum: " + maximum as string)

		-- Bounding box
		WriteFloat stream  minimum.x
		WriteFloat stream  minimum.z
		WriteFloat stream -maximum.y
		WriteFloat stream  maximum.x
		WriteFloat stream  maximum.z
		WriteFloat stream -minimum.y

		MAXLancer.WriteLog ("\t\tBounding sphere center: " + center as string)
		MAXLancer.WriteLog ("\t\tBounding sphere radius: " + formattedPrint radius format:".4f")

		-- Bounding sphere
		WritePosition stream center
		WriteFloat stream radius

		OK
	)
)

struct SimpleSurfacePart (
	partID    = 0,
	vertices  = #(), -- Array of Point3 (vertex buffer)
	triangles = #(), -- Array of Point3 (face indices to vertices)
	hulls     = #(), -- Array of SimpleSurfaceHull
	minimum   = [3.4e38, 3.4e38, 3.4e38],
	maximum   = [-3.4e38, -3.4e38, -3.4e38],
	center    = [0, 0, 0],
	radius    = 0,

	fn WriteStream stream = (
		MAXLancer.WriteLog ("Writing simple surface part: " + formatID partID)

		WriteLong stream partID #unsigned

		MAXLancer.WriteLog ("\tVertex count: " + formattedPrint vertices.count format:"d")

		WriteShort stream vertices.count #unsigned
		for v in vertices do WritePosition stream v

		MAXLancer.WriteLog ("\tTriangles count: " + formattedPrint triangles.count format:"d")

		WriteShort stream triangles.count #unsigned
		for t in triangles do (
			WriteShort stream t.x #unsigned
			WriteShort stream t.y #unsigned
			WriteShort stream t.z #unsigned
		)

		MAXLancer.WriteLog ("\tHulls count: " + formattedPrint hulls.count format:"d")

		WriteShort stream hulls.count #unsigned
		for hull in hulls do hull.WriteStream stream

		MAXLancer.WriteLog ("\tBounding box minimum: " + minimum as string)
		MAXLancer.WriteLog ("\tBounding box maximum: " + maximum as string)

		-- Bounding box
		WriteFloat stream  minimum.x
		WriteFloat stream  minimum.z
		WriteFloat stream -maximum.y
		WriteFloat stream  maximum.x
		WriteFloat stream  maximum.z
		WriteFloat stream -minimum.y

		MAXLancer.WriteLog ("\tBounding sphere center: " + center as string)
		MAXLancer.WriteLog ("\tBounding sphere radius: " + formattedPrint radius format:".4f")

		-- Bounding sphere
		WritePosition stream center
		WriteFloat stream radius

		OK
	),

	fn Parse target compound epsilon:0.05 progress: = (
		if classOf target != RigidPartHelper then throw "Invalid Rigid part helper object."

		-- Surface part for non-compound model will have 0x0 for ID
		partID = if compound then MAXLancer.Hash target.name else 0

		local hullID     = 0
		local hardpoints = #()
		local center     = [0, 0, 0]

		local startTriangle = 0
		local vertexIndex   = 0

		local hull     -- SimpleSurfaceHull
		local element  -- Separated mesh
		local face     -- Point3 (element face)
		local position -- Point3 (face corner vertex)

		minimum = [ 3.4e38,  3.4e38,  3.4e38]
		maximum = [-3.4e38, -3.4e38, -3.4e38]
		radius  = 0

		for item in SurfaceLibrary.GetPartSurfaces target &hardpoints &center recursive:false do (
			hullID = MAXLancer.Hash item.name

			-- Non-hardpoint hulls in non-compound model have ID of 0x0
			if not compound and findItem hardpoints hullID == 0 then hullID = 0

			for faces in GetMeshElements item do (
				MAXLancer.WriteLog ("Hull " + item.name + " (" + formatID hullID + "): " + formattedPrint faces.numberSet format:"u" + " faces")
				
				-- Convex hulls can have only even number of faces
				if mod faces.numberSet 2 != 0 then throw ("Hull subgroup in " + item.name + " has uneven number of faces.")

				element = mesh name:item.name mesh:(meshOp.detachFaces item faces delete:false asMesh:true) transform:item.transform hidden:true

				hull = SimpleSurfaceHull hullID:hullID startTriangle:startTriangle

				local hullVertices = #() -- Array of Point3

				in coordsys target for f = 1 to getNumFaces element do (
					face = GetFace element f

					for c = 1 to 3 do (
						position = GetVert element face[c]
						vertexIndex = findItem vertices position
						
						-- Adding new vertex
						if (vertexIndex == 0) then (

							-- Hull bounding box
							hull.minimum.x = amin hull.minimum.x position.x
							hull.minimum.y = amin hull.minimum.y position.y
							hull.minimum.z = amin hull.minimum.z position.z

							hull.maximum.x = amax hull.maximum.x position.x
							hull.maximum.y = amax hull.maximum.y position.y
							hull.maximum.z = amax hull.maximum.z position.z

							radius = amax radius (distance center position)

							vertexIndex = (append vertices position).count
						)

						-- Set new index (zero-based)
						face[c] = vertexIndex - 1

						append hullVertices position
					)

					append triangles face
					hull.triangleCount += 1
				)

				-- CalculateBoundingSphere points &center &radius
				CalculateBoundingSphere hullVertices &hull.center &hull.radius

				-- Part bounding box
				minimum.x = amin minimum.x hull.minimum.x
				minimum.y = amin minimum.y hull.minimum.y
				minimum.z = amin minimum.z hull.minimum.z

				maximum.x = amax maximum.x hull.maximum.x
				maximum.y = amax maximum.y hull.maximum.y
				maximum.z = amax maximum.z hull.maximum.z
				
				delete element
				append hulls hull
				startTriangle += hull.triangleCount
			)
		)

		this.center = center

		OK
	)
)

struct SimpleSurfaceLibrary (
	version = 1,
	parts   = #(),

	-- Save library into file
	fn SaveFile filename = (
		MAXLancer.WriteLog ("Saving simple surfaces file: " + filename)

		local stream = fopen filename "wb"
		
		WriteByte stream version #unsigned

		MAXLancer.WriteLog ("Part count: " + formattedPrint parts.count format:"d")

		WriteShort stream parts.count #unsigned
		for part in parts do part.WriteStream stream

		fclose stream
		OK
	),

	-- Parse rigid model into SimpleSurfaceParts
	fn Parse root compound progress: = (
		if classOf root != RigidPartHelper then throw "Invalid RigidPartHelper object."

		local queue = #(root)
		local target -- Current RigidPartHelper
		local part   -- Built SimpleSurfacePart

		while queue.count > 0 do (
			target = queue[queue.count]
			queue.count = queue.count - 1

			-- Queue up children ahead
			if compound then for child in target.children where classOf child == classOf root do append queue child

			part = SimpleSurfacePart()
			part.Parse target compound progress:progress

			if (part.vertices.count > 0 and part.triangles.count > 0 and part.hulls.count > 0) then (
				MAXLancer.WriteLog ("Adding part surfaces: " + target.name)
				append parts part
			)
		)

		OK
	)
)