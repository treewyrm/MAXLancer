/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * In Freelancer animation "scripts" are collection of joint maps (optionally
 * object map too). Collections are expected to contain only one map per part.
 * All interpolations are linear.
 *
 * Keyframes can contain one or more values: single float, 3D vector,
 * quaternion.
 *
 * Float value is used for fixed axis joints: prismatic, revolute and cylindric.
 * Vector value is used for object maps and loose joints. Quaternion value is
 * used for object maps and joints: spherical and loose.
 *
 * If channel interval is negative each keyframe should contain time marker
 * measured in seconds, otherwise all keyframes occur at a fixed interval and
 * time marker is ignored.
 *
 * Only a root part can have a Object map, while subparts can only have a Joint
 * map. Applying Object map to a subpart and Joint map to root does nothing.
 */

/*

0x01 - Keyframe contains single value (1x float)
0x02 - Keyframe contains position vector (3x float)
0x04 - Keyframe contains rotation quaternion (4x float, components in reverse order: WZYX)
0x08 - Unknown

0x10 - Implicit identity position vector
0x20 - Implicit identity rotation quaternion
0x40 - Compressed quaternion (restore w component)
0x80 - Compressed quaternion (harmonic mean)

0x4, 0x40 and 0x80 cannot be mixed together

*/

-- (Animations/Scripts/*/* Map #/Channel)
struct AnimationChannel (
	type      = 0,   -- What data animation channel contains
	interval  = -1,  -- Time interval
	count     = 0,   -- Number of keyframes
	keys      = #(), -- Array of Float (seconds)
	floats    = #(), -- Array of Float (fixed axis joints)
	positions = #(), -- Array of Point3 (position)
	rotations = #(), -- Array of Quat (rotation)
	pairs     = #(), -- Array of Point2

	-- Clear channel of all keys and values
	fn Clear = keys.count = floats.count = position.count = rotations.count = pairs.count = count = 0,

	-- Key is MAX's Time and value depends on type
	fn AddKey keyTime floatValue: positionValue: rotationValue: pairValue: = (

		-- Automatically add zero keyframe if keyTime is positive
		if count == 0 and keyTime.frame > 0 then AddKey 0 floatValue:floatValue positionValue:positionValue rotationValue:rotationValue pairValue:pairValue

		count += 1
	
		if interval < 0 then keys[count] = (keyTime.frame / frameRate)

		if bit.get type 1 then if classOf floatValue == float then floats[count] = floatValue else throw "Missing keyframe float value."
		if bit.get type 2 then if classOf positionValue == Point3 then positions[count] = positionValue else throw "Missing keyframe point3 value."
		if bit.get type 3 then if classOf rotationValue == Quat then rotations[count] = rotationValue else throw "Missing keyframe quat value."
		if bit.get type 4 then if classOf pairValue == Point2 then pairs[count] = pairValue else throw "Missing keyframe point2 value."

		count -- Return number of keyframes
	),

	-- Get key as Time value
	fn GetKeyTime i = (if i > 0 and i <= count then (frameRate * (if interval < 0 then keys[i] else (i - 1) * interval))) as time,

	fn GetFloat i = if i > 0 and i <= floats.count then floats[i],

	fn GetPosition i = if i > 0 and i <= positions.count then positions[i],

	fn GetRotation i = if i > 0 and i <= rotations.count then rotations[i],
	
	fn GetPair i = if i > 0 and i <= pairs.count then pairs[i],

	-- Read channel header
	fn ReadHeaderUTF reader = (
		if not reader.OpenFile "Header" then throw "Animation channel is missing Header entry."

		count    = ReadLong  reader.data #unsigned
		interval = ReadFloat reader.data
		type     = ReadLong  reader.data #unsigned

		OK
	),

	-- Read channel frames
	fn ReadFramesUTF reader child: = (
		if not reader.OpenFile "Frames" then throw "Animation channel is missing Frames entry."

		local previous   = quat 1
		local multiplier = 1

		local mode = 0

		if classOf child == string then (
			mode = case substring (toUpper child) 1 3 of (
				"BLP": 1
				"TLP": 1
				default: 0
			)
		)

		for i = 1 to count do (
			local info = StringStream ""

			if interval < 0 then keys[i] = ReadFloat reader.data -- Timestamp

			if bit.get type 1 then floats[i] = ReadFloat reader.data -- Simple float value

			if bit.get type 2 then ReadPosition   reader.data (positions[i] = [0, 0, 0]) -- Position
			if bit.get type 3 then ReadQuaternion reader.data (rotations[i] = quat 1)    -- Quaternion
			if bit.get type 4 then ReadPoint2     reader.data (pairs[i] = [0, 0])        -- Pair

			-- Cayley quantization?
			if bit.get type 7 then ReadQuaternion0x40 reader.data (rotations[i] = quat 1) mode:mode

			-- Harmonic mean (half angle and cayley) quantization
			if bit.get type 8 then ReadQuaternion0x80 reader.data (rotations[i] = quat 1)

			-- Flip quaternions to correct for 3ds Max
			if rotations.count > 0 then (
				if (rotations[i] - previous).w < 0 then multiplier *= -1
				previous = copy rotations[i]

				rotations[i] *= multiplier
				local r = rotations[i]
			)
		)

		OK
	),

	-- Read animation channel
	fn ReadUTF reader child: = (
		if not reader.OpenFolder "Channel" then throw "Map is missing Channel."

		ReadHeaderUTF reader
		ReadFramesUTF reader child:child

		reader.CloseFolder() -- Close Channel
		OK
	),

	-- Write channel header
	fn WriteHeaderUTF writer = (
		if not writer.OpenFile "Header" then throw "Unable to create Header file."

		WriteLong  writer.data count    #unsigned
		WriteFloat writer.data interval
		WriteLong  writer.data type     #unsigned

		writer.CloseFile() -- Close Header
		OK
	),

	-- Write channel frames
	fn WriteFramesUTF writer = (
		if not writer.OpenFile "Frames" then throw "Unable to create Frames file."

		for i = 1 to count do (
			if interval < 0 then WriteFloat writer.data keys[i]   -- Timestmap

			if bit.get type 1 then WriteFloat writer.data floats[i] -- Simple float value

			if bit.get type 2 then WritePosition   writer.data positions[i] -- Position
			if bit.get type 3 then WriteQuaternion writer.data rotations[i] -- Quaternion
			if bit.get type 4 then WritePoint2     writer.data pairs[i]     -- Pair

			if bit.get type 8 then WriteQuaternionHarmonicMean writer.data rotations[i] -- Quantized half-angle quaternion
		)

		writer.CloseFile() -- Close Frames
		OK
	),

	-- Write animation channel
	fn WriteUTF writer = (
		if not writer.OpenFolder "Channel" then throw "Unable to open Channel folder."

		WriteHeaderUTF writer
		WriteFramesUTF writer

		writer.CloseFolder() -- Close channel
		OK
	)
)

-- Joint maps provide simple animations (prismatic, revolute, cylindric, spheric), cannot be used on Root as they require parent name
-- (Animations/Scripts/*/Joint Map #)
struct AnimationJointMap (
	parent,  -- Parent object name (string)
	child,   -- Child object name, animation target (string)
	channel = AnimationChannel(), -- Keyframes (AnimationChannel)

	fn ReadUTF reader = (
		parent = reader.ReadFileString "Parent name"
		if parent == undefined then throw "Joint map is missing parent name entry."

		child = reader.ReadFileString "Child name"
		if child == undefined then throw "Joint map is missing child name entry."

		channel.ReadUTF reader child:child

		OK
	),

	fn WriteUTF writer = (
		writer.WriteFileString "Parent name" parent
		writer.WriteFileString "Child name"  child

		channel.WriteUTF writer
		OK
	)
)

-- Object maps provide both translation and rotation
-- (Animations/Scripts/*/Object Map #)
struct AnimationObjectMap (
	parent,  -- Target object name (string)
	channel = AnimationChannel(), -- Keyframes (AnimationChannel)

	fn ReadUTF reader = (
		parent = reader.ReadFileString "Parent name"
		if parent == undefined then throw "Object map is missing parent name."

		channel.ReadUTF reader
		OK
	),

	fn WriteUTF writer = (
		writer.WriteFileString "Parent name" parent
		channel.WriteUTF writer
		OK
	)
)

/**
 * Each script contains one or more animation maps.
 *
 * Numbers following those maps are irrelevant, in fact there can be arbitrary
 * text or nothing at all since Freelancer only looks for folders starting with
 * "Object map" and "Joint map".
 */
struct AnimationScript (
	name,       -- Script filename
	height,     -- Root height (used by deformable models)
	maps = #(), -- Array of AnimationJointMap and AnimationObjectMap

	-- Get script duration
	fn GetDuration = (
		local result = 0
		for map in maps do result = amax result (map.GetKeyTime map.count)
		result -- Return Number
	),

	-- Get object map for root part
	fn GetObjectMap parent autoCreate:false = (
		local result
		for map in maps while result == undefined where classOf map == AnimationObjectMap and stricmp map.parent parent == 0 do result = map
		if result == undefined and autoCreate then append maps (result = AnimationObjectMap parent:parent)

		result -- Return AnimationObjectMap
	),

	-- Get joint map for subpart (parent + child)
	fn GetJointMap parent child autoCreate:false = (
		local result
		for map in maps while result == undefined where classOf map == AnimationJointMap and stricmp map.parent parent == 0 and stricmp map.child child == 0 do result = map
		if result == undefined and autoCreate then append maps (result = AnimationJointMap parent:parent child:child)

		result -- Return AnimationJointMap
	),

	fn ReadUTF reader = (
		height = reader.ReadFileFloat "Root height"

		local map
		for filename in reader.GetFolders() do (
			if not reader.OpenFolder filename then throw ("Unable to open map folder " + filename + " in script " + name)

			map = case of (
				(MatchPattern filename pattern:"Object map*" ignoreCase:true): AnimationObjectMap()
				(MatchPattern filename pattern:"Joint map*"  ignoreCase:true): AnimationJointMap()
			)

			map.ReadUTF reader
			append maps map

			reader.CloseFolder() -- Close filename
		)

		OK
	),

	fn WriteUTF writer = (
		if classOf height == float then writer.WriteFileFloat "Root height" height

		local filename
		for i = 1 to maps.count do (
			filename = case classOf maps[i] of (
				AnimationObjectMap: "Object map " + formattedPrint (i - 1) format:"u"
				AnimationJointMap:  "Joint map " + formattedPrint (i - 1) format:"u"
			)
			
			if not writer.OpenFolder filename then throw ("Unable to open map folder " + filename + " in script " + name)
			maps[i].WriteUTF writer

			writer.CloseFolder() -- Close filename
		)

		OK
	)
)

struct AnimationLibrary (
	scripts = #(), -- Array of AnimationScript

	-- Get all scripts duration
	fn GetDuration = (
		local result = 0
		for item in scripts do result = amax result (item.GetDuration())
		result -- Return Number
	),

	-- Get AnimationScript from library by name
	fn GetScript name = (
		local result
		for item in scripts while result == undefined where stricmp item.name name == 0 do result = item
		result -- Return AnimationScript
	),

	fn ReadScriptsUTF reader filter: = (
		local item

		if reader.OpenFolder "Script" then (
			MAXLancer.WriteLog "Reading animation scripts"

			for filename in reader.GetFolders() do (
				if classOf filter == Array and findItem filter filename == 0 then continue
				if not reader.OpenFolder filename then throw ("Unable to read animation script: " + filename)

				MAXLancer.WriteLog ("Reading script: " + filename)

				item = AnimationScript name:filename
				item.ReadUTF reader
				append scripts item

				reader.CloseFolder() -- Close filename
			)

			reader.CloseFolder() -- Close Script
		)

		OK
	),

	-- Read from UTF (/Animation)
	fn ReadUTF reader filter: = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		if reader.OpenFolder "Animation" then (
			MAXLancer.WriteLog "Reading animation"

			ReadScriptsUTF reader filter:filter
			reader.CloseFolder() -- Close Animation
		)

		OK
	),

	fn WriteScriptsUTF writer filter: = (
		if scripts.count > 0 then (
			if not writer.OpenFolder "Script" then throw "Unable to open folder: Scripts"
			MAXLancer.WriteLog "Writing animation scripts"

			for item in scripts do (
				if classOf filter == Array and findItem filter item.name == 0 then continue
				if not writer.OpenFolder item.name then throw ("Unable to open folder: " + item.name)

				MAXLancer.WriteLog ("Writing script: " + item.name)

				item.WriteUTF writer
				writer.CloseFolder()
			)

			writer.CloseFolder() -- Close Script
		)

		OK
	),

	-- Write into UTF (/Animation)
	fn WriteUTF writer filter: = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		if scripts.count > 0 then (
			if not writer.OpenFolder "Animation" then throw "Unable to open folder: Animation"
			MAXLancer.WriteLog "Writing animation"

			WriteScriptsUTF writer filter:filter

			writer.CloseFolder() -- Close Animation
		)

		OK
	),

	fn GetLayerNames controller = for i = 2 to controller.getCount() where controller[i].controller.supportsKeys and controller[i].controller.keys.count > 0 collect controller.getLayerName i,

	-- Query subcontroller layers for animations
	fn GetAnimations target = (
		if not isValidNode target then throw "Invalid target node."

		local result     = #()
		local controller = target.transform.controller
		local getLayers  = AnimationLibrary.GetLayerNames

		case classOf controller of (
			AxisJointController: (
				if (controller.type == 1 or controller.type == 3) and classOf controller.turn.controller == Float_Layer then join result (getLayers controller.turn.controller)
				if (controller.type == 2 or controller.type == 3) and classOf controller.slide.controller == Float_Layer then join result (getLayers controller.slide.controller)
			)
			SphericJointController: (
				if classOf controller.rotation == Rotation_Layer then join result (getLayers controller.rotation) 
			)
			LooseJointController: (
				if classOf controller.position == Position_Layer then join result (getLayers controller.position)
				if classOf controller.rotation == Rotation_Layer then join result (getLayers controller.rotation)
			)
		)

		makeUniqueArray result -- Return array of string
	),

	fn IsLayerController controller = (
		case classOf controller of (
			Float_Layer:    true
			Point3_Layer:   true
			Point4_Layer:   true
			Position_Layer: true
			Rotation_Layer: true
			Scale_Layer:    true
			default:        false
		)
	),

	-- Get subcontroller from layer controller by layer name
	fn GetLayerController controller name = (
		local result
		if IsLayerController controller then for i = 2 to controller.getCount() while result == undefined where controller.getLayerName i == name do result = controller[i].controller
		result -- Return controller
	),

	fn BuildJointRevolute target scripts = (
		local map, turn

		for item in scripts where (map = item.GetJointMap target.parent.name target.name) != undefined do (
			turn = GetLayerController target.transform.controller.turn.controller item.name
			if turn == undefined then throw ("Missing turn controller in " + target.name + " for script " + item.name)

			MAXLancer.WriteLog ("Applying revolute joint (" + target.name + ") animation: " + item.name)

			for k = 1 to map.channel.count do (addNewKey turn (map.channel.GetKeyTime k)).value = radToDeg (map.channel.GetFloat k)
		)

		target.transform.controller.turn.controller.setLayerActive 1		
	),

	fn BuildJointPrismatic target scripts = (
		local map, slide

		for item in scripts where (map = item.GetJointMap target.parent.name target.name) != undefined do (
			slide = GetLayerController target.transform.controller.slide.controller item.name
			if slide == undefined then throw ("Missing slide controller in " + target.name + " for script " + item.name)

			MAXLancer.WriteLog ("Applying prismatic joint (" + target.name + ") animation: " + item.name)

			for k = 1 to map.channel.count do (addNewKey slide (map.channel.GetKeyTime k)).value = map.channel.GetFloat k
		)

		target.transform.controller.slide.controller.setLayerActive 1
	),

	fn BuildJointCylindric target scripts = (
		local map, turn, slide, keyTime

		for item in scripts where (map = item.GetJointMap target.parent.name target.name) != undefined do (
			turn  = GetLayerController target.transform.controller.turn.controller  item.name
			slide = GetLayerController target.transform.controller.slide.controller item.name

			if turn == undefined then throw ("Missing turn controller in " + target.name + " for script " + item.name)
			if slide == undefined then throw ("Missing slide controller in " + target.name + " for script " + item.name)

			MAXLancer.WriteLog ("Applying cylindric joint (" + target.name + ") animation: " + item.name)

			for k = 1 to map.channel.count do (
				keyTime = map.channel.GetKeyTime k

				(addNewKey turn keyTime).value  = radToDeg (map.channel.GetPosition k).x
				(addNewKey slide keyTime).value = (map.channel.GetPosition k).y
			)

			
		)

		target.transform.controller.turn.controller.setLayerActive 1
		target.transform.controller.slide.controller.setLayerActive 1
	),

	fn BuildJointAxis target scripts = (
		case target.transform.controller.type of (
			1: BuildJointRevolute  target scripts
			2: BuildJointPrismatic target scripts
			3: BuildJointCylindric target scripts
		)
	),

	fn BuildJointSpheric target scripts = (
		local map, rotation

		for item in scripts where (map = item.GetJointMap target.parent.name target.name) != undefined do (
			rotation = GetLayerController target.transform.controller.rotation item.name
			if rotation == undefined then throw ("Missing rotation controller in " + target.name + " for script " + item.name)

			MAXLancer.WriteLog ("Applying spheric joint (" + target.name + ") animation: " + item.name)

			for k = 1 to map.channel.count do (addNewKey rotation (map.channel.GetKeyTime k)).value = map.channel.GetRotation k
		)

		target.transform.controller.rotation.setLayerActive 1
	),

	fn BuildJointLoose target scripts = (
		local map, position, rotation

		for item in scripts where (map = item.GetJointMap target.parent.name target.name) != undefined do (
			position = GetLayerController target.transform.controller.position item.name
			rotation = GetLayerController target.transform.controller.rotation item.name

			if position == undefined then throw ("Missing position controller in " + target.name + " for script " + item.name)
			if rotation == undefined then throw ("Missing rotation controller in " + target.name + " for script " + item.name)

			MAXLancer.WriteLog ("Applying loose joint (" + target.name + ") animation: " + item.name)

			for k = 1 to map.channel.positions.count do (addNewKey position (map.channel.GetKeyTime k)).value = map.channel.GetPosition k -- * RotateXMatrix 90
			for k = 1 to map.channel.rotations.count do (addNewKey rotation (map.channel.GetKeyTime k)).value = map.channel.GetRotation k
		)

		target.transform.controller.position.setLayerActive 1
		target.transform.controller.rotation.setLayerActive 1
	),

	fn BuildObject target scripts = (
		local map, position, rotation, key

		for item in scripts where (map = item.GetObjectMap target.name) != undefined do (
			position = GetLayerController target.transform.controller.position item.name
			rotation = GetLayerController target.transform.controller.rotation item.name

			if position == undefined then throw ("Missing position controller in " + target.name + " for script " + item.name)
			if rotation == undefined then throw ("Missing rotation controller in " + target.name + " for script " + item.name)

			MAXLancer.WriteLog ("Applying object (" + target.name + ") animation: " + item.name)

			for k = 1 to map.channel.positions.count do (
				key = addNewKey position (map.channel.GetKeyTime k)
				key.value = map.channel.GetPosition k

				if item.height != undefined then key.value += [0, 0, item.height]
			)

			for k = 1 to map.channel.rotations.count do (addNewKey rotation (map.channel.GetKeyTime k)).value = map.channel.GetRotation k
		)

		target.transform.controller.position.setLayerActive 1
		target.transform.controller.rotation.setLayerActive 1
	),

	-- Walk through hierarchy of deformable skeleton and apply animations
	fn Build root filter: = (
		if not isValidNode root then throw "Invalid root node object."

		local subparts = GetPartChildren root deep:true
		local parts    = #(root) + subparts
		local items    = #() -- Array of AnimationScript
		
		-- Enable layers
		AnimLayerManager.enableLayers &parts pos:true rot:true scale:false other:true

		-- Collecting scripts to apply on targets
		for item in scripts do (
			if classOf filter == Array and findItem filter item.name == 0 then continue

			MAXLancer.WriteLog ("Creating animation layer: " + item.name)

			/**
			 * AnimLayerManager.addLayer is automatically passed down in
			 * hierarchy for objects which have layers enabled. It is not
			 * necessary to call addLayer on every object in targets.
			 */
			AnimLayerManager.addLayer item.name root true

			-- Automatically mute added layer
			for i = 1 to AnimLayerManager.getLayerCount() where AnimLayerManager.getLayerName i == item.name do AnimLayerManager.setLayerMute i true

			append items item
		)

		-- Apply scripts to root
		if classOf root.transform.controller == LooseJointController then BuildObject root items

		-- Apply scripts to subparts
		for subpart in subparts do (
			case classOf subpart.transform.controller of (
				FixedJointController:   ()
				AxisJointController:    BuildJointAxis    subpart items
				SphericJointController: BuildJointSpheric subpart items
				LooseJointController:   BuildJointLoose   subpart items
				default: throw (subpart.name + " is missing valid joint controller.")
			)
		)

		OK
	),

	fn ParseJointRevolute target scripts = (
		local map, turn

		if classOf target.transform.controller.turn.controller == Float_Layer then for item in scripts do (
			turn = GetLayerController target.transform.controller.turn.controller item.name
			if turn == undefined or turn.keys.count == 0 then continue

			map = AnimationJointMap parent:target.parent.name child:target.name
			map.channel.type = bit.set map.channel.type 1 true

			MAXLancer.WriteLog ("Parsing revolute joint (" + target.name + ") animation: " + item.name)

			for k = 1 to turn.keys.count do map.channel.AddKey turn.keys[k].time floatValue:(DegToRad turn.keys[k].value)

			append item.maps map
		)

		OK
	),

	fn ParseJointPrismatic target scripts = (
		local map, slide

		for item in scripts do (
			slide = GetLayerController target.transform.controller.slide.controller item.name
			if slide == undefined or slide.keys.count == 0 then continue

			map = AnimationJointMap parent:target.parent.name child:target.name
			map.channel.type = bit.set map.channel.type 1 true

			MAXLancer.WriteLog ("Parsing prismatic joint (" + target.name + ") animation: " + item.name)

			for k = 1 to slide.keys.count do map.channel.AddKey slide.keys[k].time floatValue:slide.keys[k].value

			append item.maps map
		)

		OK
	),

	fn ParseJointCylindric target scripts = (
		local turn, slide, map, keys

		for item in scripts do (
			turn = GetLayerController target.transform.controller.turn.controller  item.name
			if turn == undefined or turn.keys.count == 0 then continue

			slide = GetLayerController target.transform.controller.slide.controller item.name
			if slide == undefined or slide.keys.count == 0 then continue

			map = AnimationJointMap parent:target.parent.name child:target.name
			--map.channel.type = bit.set map.channel.type 2 true
			map.channel.type = bit.set map.channel.type 4 true
			
			keys = makeUniqueArray ((for key in turn.keys collect key.time) + (for key in slide.keys collect key.time))

			MAXLancer.WriteLog ("Parsing cylindric joint (" + target.name + ") animation: " + item.name)

			-- for keyTime in keys do at time keyTime map.channel.AddKey keyTime positionValue:[DegToRad turn.value, slide.value, 0]
			for keyTime in keys do at time keyTime map.channel.AddKey keyTime pairValue:[DegToRad turn.value, slide.value]

			append item.maps map
		)

		OK
	),

	fn ParseJointAxis target scripts = (
		case target.transform.controller.type of (
			1: ParseJointRevolute target scripts
			2: ParseJointPrismatic target scripts
			3: ParseJointCylindric target scripts
		)
	),

	fn ParseJointSpheric target scripts = (
		local rotation, map

		for item in scripts do (
			rotation = GetLayerController target.transform.controller.rotation.controller item.name
			map = AnimationJointMap parent:target.parent.name child:target.name
			map.channel.type = bit.set map.channel.type 3 true

			MAXLancer.WriteLog ("Parsing spheric joint (" + target.name + ") animation: " + item.name)

			for k = 1 to rotation.keys.count do map.channel.AddKey rotation.keys[k].time rotationValue:rotation.keys[k].value

			append item.maps map
		)

		OK
	),

	-- Unlike other joints loose may have position or rotation or both
	fn ParseJointLoose target scripts = (
		local position, rotation, map, keys

		for item in scripts do (
			position = GetLayerController target.transform.controller.position.controller item.name
			rotation = GetLayerController target.transform.controller.rotation.controller item.name

			-- Combine keys
			keys = #()

			if position != undefined then for key in position.keys do appendIfUnique keys key.time
			if rotation != undefined then for key in rotation.keys do appendIfUnique keys key.time
			if keys.count == 0 then continue

			sort keys

			map = AnimationJointMap parent:target.parent.name child:target.name

			if position.keys.count > 0 then map.channel.type = bit.set map.channel.type 2 true
			if rotation.keys.count > 0 then map.channel.type = bit.set map.channel.type 3 true

			MAXLancer.WriteLog ("Pasing loose joint (" + target.name + ") animation: " + item.name)

			for keyTime in keys do at time keyTime map.channel.AddKey keyTime positionValue:(if position != undefined then position.value) rotationValue:(if rotation != undefined then rotation.value)

			append item.maps map
		)
	),

	-- Similar to loose joints object map can have position or rotation or both
	fn ParseObject target scripts = (
		local position, rotation, map, keys

		for item in scripts do (
			position = GetLayerController target.transform.controller.position.controller item.name
			rotation = GetLayerController target.transform.controller.rotation.controller item.name

			-- Combine keys
			keys = #()

			if position != undefined then for key in position.keys do appendIfUnique keys key.time
			if rotation != undefined then for key in rotation.keys do appendIfUnique keys key.time
			if keys.count == 0 then continue

			sort keys

			map = AnimationJointMap parent:target.parent.name child:target.name

			if position.keys.count > 0 then map.channel.type = bit.set map.channel.type 2 true
			if rotation.keys.count > 0 then map.channel.type = bit.set map.channel.type 3 true

			MAXLancer.WriteLog ("Pasing object (" + target.name + ") animation: " + item.name)

			for keyTime in keys do at time keyTime map.channel.AddKey keyTime positionValue:(if position != undefined then position.value) rotationValue:(if rotation != undefined then rotation.value)

			append item.maps map
		)
	),

	fn Parse root filter: = (
		if not isValidNode root then throw "Invalid root node object."

		local subparts = GetPartChildren root deep:true
		local items = #()
		local item

		-- Create animation scripts for layers in model
		/* local items = for i = 2 to (AnimLayerManager.getNodesLayers root).count collect (
			layerName = AnimLayerManager.getLayerName i
			if classOf filter == Array and findItem filter layerName == 0 then dontcollect else (
				item = AnimationScript name:layerName
				append scripts item
				item
			)
		)*/

		for part in #(root) + subparts do (
			for layerName in GetAnimations part do (
				if classOf filter == Array and findItem filter layerName == 0 then continue

				item = GetScript layerName

				if item == undefined then append scripts (item = AnimationScript name:layerName)
				appendIfUnique items item
			)
		)

		/*
		local items = for layerName in GetAnimations root collect AnimationScript name:layerName
		for item in items do append scripts item
		*/

		-- Parse root into object map
		if classOf root.transform.controller == LooseJointController then ParseObject root items

		-- Parse subparts into joint maps
		for subpart in subparts where subpart != root do (
			case classOf subpart.transform.controller of (
				FixedJointController:   () -- No animations
				AxisJointController:    ParseJointAxis    subpart items
				SphericJointController: ParseJointSpheric subpart items
				LooseJointController:   ParseJointLoose   subpart items
				default: throw (subpart.name + " is missing valid joint controller.")
			)
		)

		OK
	),

	-- Load animation library from file (.anm)
	fn LoadFile filename = (
		local reader = UTFReader()
		reader.Open filename
		ReadUTF reader
		reader.Close()
		OK
	),

	-- Save animation library into file (.anm)
	fn SaveFile filename = (
		local writer = UTFWriter()
		writer.Open filename
		WriteUTF writer filter:filter
		writer.Close()
		OK
	)	
)