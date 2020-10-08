/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * INI files are used to define most things in Freelancer, such as systems, bases, equipment and so forth.
 * Two readers are provided, one for compact binary form and the other for generic text-based.
 * Ssection names, property names and string values are converted into lower case as Freelancer is case-insensitive.
 */

struct INIBinaryReader (
	filename,
	stream, -- BinStream

	namesOffset   = 0,
	sectionCount  = 0,
	propertyCount = 0,

	-- Read string from ZString dictionary
	fn ReadName offset = (
		local previous = ftell stream
		local result = if fseek stream (namesOffset + offset) #seek_set then toLower (ReadString stream) else throw ("Dictionary seek error at 0x" + formattedPrint (namesOffset + offset) format:"08X")
		fseek stream previous #seek_set
		result -- Return string	
	),

	-- Read INI section
	fn ReadSection &target &properties &items = if ftell stream < namesOffset then (
		target     = ReadName (ReadShort stream #unsigned) -- Name index is ushort
		properties = #()
		items      = #()

		for p = 1 to ReadShort stream #unsigned do ( -- Property count is ushort
			properties[p] = ReadName (ReadShort stream #unsigned)
			items[p]      = #()

			for v = 1 to ReadByte stream #unsigned do items[p][v] = case ReadByte stream #unsigned of ( -- Values count is ubyte, value type is ubyte
				0: ReadLong stream #unsigned != 0
				1: ReadLong stream #signed
				2: ReadFloat stream
				3: toLower (ReadName (ReadLong stream #unsigned)) -- Name index is ulong
			)

			propertyCount += 1
		)

		sectionCount += 1
		true
	) else (
		fclose stream
		false
	),

	on create do (
		stream = fopen filename "rb"
		if fseek stream 8 #seek_set then namesOffset = ReadLong stream #unsigned
	)
)

struct INITextReader (
	filename,
	stream, -- FileStream

	sectionCount  = 0,
	propertyCount = 0,

	lastSection, -- Current INISection

	fn ReadSection &target &properties &items = if not eof stream then (
		local halt = false

		local commentOffset
		local sectionOffset
		local assignmentOffset
		local currentLine

		target     = lastSection
		properties = #()
		items      = #()

		while not eof stream and not halt and (currentLine = readLine stream) != undefined do (

			if isSpace currentLine then continue -- Line starts with whitespace
			currentLine = toLower currentLine -- Force lowercase
			if (commentOffset = findString currentLine ";") != undefined then currentLine = trimRight (substring currentLine 1 (commentOffset - 1)) -- Remove comments
			if currentLine.count == 0 then continue -- Skip empty contents

			-- Line is section start
			if (sectionOffset = if currentLine[1] == "[" then findString currentLine "]") != undefined then (
				lastSection = substring currentLine 2 (sectionOffset - 2)

				-- If we read it first time we don't halt to read properties, if we read it every next time we halt because that's a start of next section block
				if target != undefined then halt = true else target = lastSection 
			) else if target != undefined then (
				if (assignmentOffset = findString currentLine "=") != undefined then (
					append properties (trimRight (substring currentLine 1 (assignmentOffset - 1)))
					append items (for s in filterString (substring currentLine (assignmentOffset + 1) -1) "," splitEmptyTokens:false collect trimLeft (trimRight (s)))

					propertyCount += 1
				) else (
					append properties (trimRight currentLine)
					append items #(true)
				)
			)
		)

		sectionCount += 1
		
		true
	) else (
		close stream
		false
	),

	on create do stream = openFile filename mode:"r"
)

fn OpenINIFile filename = (
	if not doesFileExist filename then throw "File does not exist"
	
	local stream = fopen filename "rb"
	local result = if ReadLong stream #unsigned != 0x494E4942 then INITextReader filename:filename else
		if ReadLong stream #unsigned != 1 then throw "Invalid BINI version" else INIBinaryReader filename:filename
	
	fclose stream
	
	result.filename = filename
	result -- Return INIBinaryReader/INITextReader
)

struct INITextWriter (
	filename,
	stream, -- FileStream

	sectionCount  = 0,
	propertyCount = 0,

	fn WriteSection target properties items = (
		if classOf target != string or target.count == 0 then throw "Invalid or empty section name"
		if properties.count != items.count then throw "Invalid property and value arrays"

		if sectionCount > 0 then format "\r\n" to:stream

		format "[%]\r\n" (toLower target) to:stream

		local item

		for p = 1 to properties.count do (
			format "% = " (toLower properties[p]) to:stream

			item = items[p][v]
			if classOf item == string then item = toLower item

			for v = 1 to items[p].count do format (if v == 1 then "%" else ", %") items[p][v] to:stream

			format "\r\n" to:stream

			propertyCount += 1
		)

		sectionCount += 1
	),

	fn CloseFile = close stream,

	on create do stream = openFile filename mode:"wt"
)

struct INIBinaryWriter (
	filename,
	location,

	sections, -- Sections BinStream
	names,    -- Concatenated ZString for section and property names
	values,   -- Concatenated ZString for string property values
	
	sectionCount  = 0,
	propertyCount = 0,

	sectionsSize = 0,
	namesSize    = 0,
	valuesSize   = 0,
	
	fn GetStringOffset stream target &size = (
		local result, offset
		
		-- Rewind to start and search for existing string
		fseek stream 0 #seek_set
		
		while result == undefined and (offset = ftell stream) < size do if stricmp (ReadString stream) target == 0 then result = offset
		
		if result == undefined then (
			WriteString stream (toLower target)
			
			result = offset
			size = ftell stream
		)
		
		result -- Return offset to name
	),
	
	fn WriteSection target properties items = (

		if classOf target != string or target.count == 0 then throw "Invalid or empty section name"
		if properties.count != items.count then throw "Invalid property and value arrays"
		
		fseek sections 0 #seek_end
		
		WriteShort sections (GetStringOffset names target &namesSize) #unsigned
		WriteShort sections properties.count #unsigned
		
		local item

		for p = 1 to properties.count do (
			if items[p].count > 256 then throw "Too many values in property"

			WriteShort sections (GetStringOffset names properties[p] &namesSize) #unsigned
			WriteByte sections items[p].count #unsigned
			
			for v = 1 to items[p].count do (
				item = items[p][v]
				
				case classOf item of (
					BooleanClass: WriteByte sections 0 and WriteLong sections (if item then 1 else 0)
					Integer:      WriteByte sections 1 and WriteLong sections item
					Float:        WriteByte sections 2 and WriteFloat sections item
					String:       WriteByte sections 3 and WriteLong sections (GetStringOffset values item &valuesSize) #unsigned
					default:      throw "Unrecognized property type"
				)
			)

			propertyCount += 1
		)
		
		sectionsSize = ftell sections
		sectionCount += 1
		
		OK
	),
	
	fn CloseFile = (
		
		-- Get to namesOffset and write sections size
		fseek sections 8 #seek_set
		WriteLong sections sectionsSize #unsigned
		
		local offset
		
		-- Walk over sections and update value string offsets
		while ftell sections < sectionSize do (
			fseek sections 2 #seek_cur -- Skip section name offset
			
			for p = 1 to ReadShort sections #unsigned do ( -- Loop through properties
				fseek sections 2 #seek_cur -- Skip property name offset
				
				for v = 1 to ReadByte sections #unsigned do -- Loop through values
					if ReadByte sections #unsigned == 3 and (offset = ReadLong sections #unsigned) != undefined and fseek sections -4 #seek_cur then WriteLong sections (offset + namesSize) #unsigned
						else fseek sections 4 #seek_cur
			)
		)
		
		fclose sections
		fclose names
		fclose values
		
		HiddenDOSCommand "COPY /V /Y /B sections+names+values output" startpath:location -- Concatenate section files
		if doesFileExist filename then if not DeleteFile filename then throw "Could not overwrite existing file" -- Delete file to overwrite
		if not renameFile (pathConfig.appendPath location "output") filename then throw "Could not copy UTF file to destination" -- Copy result to specified filename
		
		OK
	),
	
	on create do (
		location = MAXLancer.CreateTemporaryFolder()
		
		sections = fopen (pathConfig.appendPath location "sections") "wb+"
		names    = fopen (pathConfig.appendPath location "names") "wb+"
		values   = fopen (pathConfig.appendPath location "values") "wb+"
		
		WriteLong sections 0x494E4942 #unsigned -- FourCC signature
		WriteLong sections 1 #unsigned -- Version
		WriteLong sections 0 #unsigned -- Offset to names
	)
)

fn CreateINIFile filename binary:false = if binary then INIBinaryWriter filename:filename else INITextWriter filename:filename
