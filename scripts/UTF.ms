/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * UTF file container used by various assets in Freelancer.
 */

-- UTF Header (first 56 bytes in file)
struct UTFHeader (
	signature          = 0x20465455, -- FourCC bytes ("UTF ")
	version            = 0x101,      -- Version is always 0x101
	directoryOffset    = 0,          -- Offset to tree block where entries are and the root entry starts at, by default right after header
	directorySize      = 0,          -- Size of directory in bytes
	unusedEntryOffset  = 0,          -- Has a value in few files where there's bunch of removed entries still lingering in directory
	entrySize          = 44,         -- Freelancer will crash on UTF files where this value isn't 44, the actual length of entries can be of variable size
	namesOffset        = 0,          -- Offset to dictionary block where entry names are
	namesSizeAllocated = 0,          -- Allocated space to dictionary in bytes
	namesSizeUsed      = 0,          -- Used space for dictionary in bytes, less or equal to allocated
	dataOffset         = 0,          -- Offset to entry values content
	unusedSpaceOffset  = 0,          -- Unused block offset (probably was used by original UTF tool to mark removed entries data space for reclamation)
	unusedSpaceSize    = 0,          -- Unused block size in bytes
	filetime           = 0,          -- Windows 64-bit filetime

	fn ReadStream stream = (
		if ReadLong stream != signature then throw "Invalid UTF header."
		if ReadLong stream != version then throw "Invalid UTF version."

		directoryOffset   = ReadLong stream #unsigned
		directorySize     = ReadLong stream #unsigned
		unusedEntryOffset = ReadLong stream #unsigned
		
		if ReadLong stream != entrySize then throw "Invalid UTF entry size."

		namesOffset        = ReadLong stream #unsigned
		namesSizeAllocated = ReadLong stream #unsigned
		namesSizeUsed      = ReadLong stream #unsigned
		dataOffset         = ReadLong stream #unsigned
		unusedSpaceOffset  = ReadLong stream #unsigned
		unusedSpaceSize    = ReadLong stream #unsigned
		filetime           = ReadLongLong stream #unsigned
		OK
	),

	fn WriteStream stream = (
		WriteLong stream signature          #unsigned
		WriteLong stream version            #unsigned
		WriteLong stream directoryOffset    #unsigned
		WriteLong stream directorySize      #unsigned
		WriteLong stream unusedSpaceOffset  #unsigned
		WriteLong stream entrySize          #unsigned
		WriteLong stream namesOffset        #unsigned
		WriteLong stream namesSizeAllocated #unsigned
		WriteLong stream namesSizeUsed      #unsigned
		WriteLong stream dataOffset         #unsigned
		WriteLong stream unusedSpaceOffset  #unsigned
		WriteLong stream unusedSpaceSize    #unsigned
		WriteLongLong stream filetime       #unsigned
		OK
	)
)

-- Entry in UTF tree is either folder or file, each is 44 bytes
struct UTFEntry (
	nextOffset           = 0, -- Offset to next sibling relative to directoryOffset
	nameOffset           = 0, -- Offset to entry name relative to namesOffset
	fileAttributes       = 0, -- Entry properties determining whether it is a file or a folder (see: Win32 API dwFileAttributes)
	sharingAttributes    = 0, -- Unused, bitmask for file sharing attributes
	childOffset          = 0, -- Offset either to first child relative to directoryoffset or to value relative to dataOffset
	dataSizeAllocated    = 0, -- Allocated length in data block to entry value
	dataSizeUsed         = 0, -- Actual used space, less or equal to allocated
	dataSizeUncompressed = 0, -- Unused, typically the same as used space
	creationTime         = 0, -- DOS file timestamps (https://blogs.msdn.microsoft.com/oldnewthing/20030905-02/?p=42653)
	lastAccessTime       = 0, -- Ditto
	lastWriteTime        = 0, -- Ditto
	
	fn IsFolder = bit.get fileAttributes 5,
	fn IsFile = bit.get fileAttributes 8,

	-- Read entry from BinStream
	fn ReadStream stream = (
		nextOffset           = ReadLong stream #unsigned
		nameOffset           = ReadLong stream #unsigned
		fileAttributes       = ReadLong stream #unsigned
		sharingAttributes    = ReadLong stream #unsigned
		childOffset          = ReadLong stream #unsigned
		dataSizeAllocated    = ReadLong stream #unsigned
		dataSizeUsed         = ReadLong stream #unsigned
		dataSizeUncompressed = ReadLong stream #unsigned
		creationTime         = ReadLong stream #unsigned
		lastAccessTime       = ReadLong stream #unsigned
		lastWriteTime        = ReadLong stream #unsigned
		OK
	),

	-- Write entry into BinStream
	fn WriteStream stream = (
		WriteLong stream nextOffset           #unsigned
		WriteLong stream nameOffset           #unsigned
		WriteLong stream fileAttributes       #unsigned
		WriteLong stream sharingAttributes    #unsigned
		WriteLong stream childOffset          #unsigned
		WriteLong stream dataSizeAllocated    #unsigned
		WriteLong stream dataSizeUsed         #unsigned
		WriteLong stream dataSizeUncompressed #unsigned
		WriteLong stream creationTime         #unsigned
		WriteLong stream lastAccessTime       #unsigned
		WriteLong stream lastWriteTime        #unsigned
		OK
	)
)

-- TODO: When opening a file but calling stuff like GetPath/GetFolders/GetFiles the entry will be overwritten

struct UTFReader (
	header  = UTFHeader(), -- Header (UTFHeader)
	entry   = UTFEntry(),  -- Working entry (UTFEntry)
	size    = 0,           -- dataSizeUsed from openFile
	parents = #(0),        -- Entry stack for current folder (array of integer)
	
	filename,  -- File path (string)
	directory, -- Directory stream (BinStream)
	names,     -- Names stream (BinStream)
	data,      -- Data stream (BinStream)
	
	-- Get entry name by dictionary offset
	fn ReadName offset = (
		-- if offset + 1 > header.namesSizeUsed then throw ("Offset is outside dictionary boundary: " + formattedPrint offset format:"u")
		if not fseek names (header.namesOffset + offset) #seek_set then throw ("Dictionary seek error at 0x" + formattedPrint (header.namesOffset + offset) format:"08X")
		ReadString names -- Return string
	),

	-- Read current entry by directory offset
	fn ReadEntry offset = (
		-- if offset + header.entrySize > header.directorySize then throw ("Offset is outside directory boundary: " + formattedPrint offset format:"u")
		if not fseek directory (header.directoryOffset + offset) #seek_set then throw ("Directory seek error at 0x" + formattedPrint (header.directoryOffset + offset) format:"08X")
		entry.ReadStream directory
		OK
	),

	fn Reset = (parents = #(0); ReadEntry 0),
	
	-- Get full pathname as array
	fn GetPath = for offset in parents collect (ReadEntry offset; ReadName entry.nameOffset),

	-- Get current folder name
	fn GetCurrentFolder = (ReadEntry parents[parents.count]; ReadName entry.nameOffset),

	-- Get list of folders in current folder
	fn GetFolders = (
		ReadEntry parents[parents.count]

		local result = #(), offset = entry.childOffset
		while offset > 0 do (ReadEntry offset; if entry.IsFolder() then append result (ReadName entry.nameOffset); offset = entry.nextOffset)
		result -- Array of string
	),

	-- Get list of files in current folder
	fn GetFiles = (
		ReadEntry parents[parents.count]

		local result = #(), offset = entry.childOffset
		while offset > 0 do (ReadEntry offset; if entry.IsFile() then append result (ReadName entry.nameOffset); offset = entry.nextOffset)
		result -- Array of string
	),
	
	-- Find entry matching filename/hash in current folder
	fn GetChildOffset target = (
		ReadEntry parents[parents.count]
		target = MAXLancer.hash target

		local found = false, offset = entry.childOffset
		while not found and offset > 0 do (ReadEntry offset; if target == MAXLancer.hash (ReadName entry.nameOffset) then found = true else offset = entry.nextOffset)
		if found then offset else 0
	),
	
	-- Open folder
	fn OpenFolder target = (local offset = GetChildOffset target; if offset > 0 and entry.IsFolder() then (append parents offset; true) else false),

	-- Close current folder (remove from current stack)
	fn CloseFolder = if parents.count > 1 then (parents.count = parents.count - 1; true) else false,

	-- Open file for reading
	fn OpenFile target = (GetChildOffset target) > 0 and entry.IsFile() and (size = entry.dataSizeUsed) > 0 and fseek data (header.dataOffset + entry.childOffset) #seek_set,

	-- Read file as single integer value (32, 16 or 8 bits)
	fn ReadFileInteger target sign = if OpenFile target then (
		case of (
			(size >= 4): ReadLong  data sign
			(size >= 2): ReadShort data sign
			(size >= 1): ReadByte  data sign
		)
	),

	-- Read file as array of bytes (8-bit integers)
	fn ReadFileBytes target sign = if OpenFile target then for i = 1 to size collect ReadByte data sign,

	-- Read file as array of shorts (16-bit integers)
	fn ReadFileShorts target sign = if OpenFile target then for i = 1 to size / 2 collect ReadShort data sign,

	-- Read file as array of longs (32-bit integers)
	fn ReadFileLongs target sign = if OpenFile target then for i = 1 to size / 4 collect ReadLong data sign,

	-- Read file as single float value
	fn ReadFileFloat target = if OpenFile target and size >= 4 then ReadFloat data,

	-- Read file as array of floats
	fn ReadFileFloats target = if OpenFile target then for i = 1 to size / 4 collect ReadFloat data,

	-- Read file as string
	fn ReadFileString target = if OpenFile target then ReadCharsFixed data size,

	-- Read file into color float components (RGB)
	fn ReadFileColorFloat target c = if OpenFile target and size >= 12 then ReadColorFloat data c,

	-- Read file into position vector components (XYZ)
	fn ReadFilePosition target p = if OpenFile target and size >= 12 then ReadPosition data p,

	-- Read file into rotation/scape part of transformation matrix (row1, row2, row3)
	fn ReadFileRotationPart target m = if OpenFile target and size >= 36 then ReadRotationPart data m,

	-- Read file into translation part of transformation matrix (row4)
	fn ReadFileTranslationPart target m = if OpenFile target and size >= 12 then ReadTranslationPart data m,

	-- Open file and extract its contents into filesystem
	fn ExportFile target filename = if OpenFile target then (
		local result = fopen filename "wbS"

		CopyStream data result size
		fclose result
		true
	) else false,
	
	-- Open file as UTF
	fn Open target = (
		if not doesFileExist target then throw "File does not exist."
		if MAXLancer.verbosity > 2 then MAXLancer.WriteLog ("Opening UTF file: " + target)

		directory = fopen target "r"
		header.ReadStream directory

		names = fopen target "r"
		data  = fopen target "r"

		filename = target
		Reset()
	),
	
	-- Close streams
	fn Close = (
		fclose directory
		fclose names
		fclose data
		OK
	)
)

struct UTFWriter (
	header     = UTFHeader(), -- Header (UTFHeader)
	entry      = UTFEntry(),  -- Working entry (UTFEntry)
	parents    = #(0),        -- Entry stack for current folder (array of integer)
	fileOffset = 0,           -- Offset to entry of currently open file for writing
	
	filename,  -- File path (string)
	location,  -- Temporary files location (string)
	directory, -- Directory stream (BinStream)
	names,     -- Names stream (BinStream)
	data,      -- Data stream (BinStream)

	-- Get entry name by dictionary offset
	fn ReadName offset = (
		if offset + 1 > header.namesSizeUsed then throw ("Offset is outside dictionary boundary: " + formattedPrint offset format:"u")
		if not fseek names (header.namesOffset + offset) #seek_set then throw ("Dictionary seek error at 0x" + formattedPrint (header.namesOffset + offset) format:"08X")
		ReadString names -- Return string
	),

	-- Writes entry filename to dictionary, returns offset to written or duplicate filename
	fn WriteName target = (
		local result, offset = 0
		
		-- Find nameOffset for matching filename in dictionary
		if not fseek names header.namesOffset #seek_set then throw ("Dictionary seek error at 0x" + formattedPrint header.namesOffset format:"08X")
		while result == undefined and (offset = ftell names) < header.namesOffset + header.namesSizeUsed do if stricmp (ReadString names) target == 0 then result = offset

		-- Add new filename to dictionary if no match was found
		if result == undefined then (
			if not fseek names 0 #seek_end then throw "Dictionary end seek error."
			if not WriteString names target then throw ("Error writing string into dictionary at 0x" + ftell names format:"08X")
			
			result = offset
			header.namesSizeUsed = ftell names - header.namesOffset
		)
		
		result -- Return Integer or undefined (if not found and not writable)
	),

	-- Read current entry by directory offset
	fn ReadEntry offset = (
		if offset + header.entrySize > header.directorySize then throw ("Offset is outside directory boundary: " + formattedPrint offset format:"u")
		if not fseek directory (header.directoryOffset + offset) #seek_set then throw ("Directory seek error at 0x" + formattedPrint (header.directoryOffset + offset) format:"08X")
		entry.ReadStream directory
		OK
	),

	-- Write current entry to directory at specified offset
	fn WriteEntry offset = (
		if location == undefined then throw "Cannot write into read-only file."
		if offset > header.directorySize then throw "Offset is outside directory boundary."
		if mod offset header.entrySize != 0 then "Offset is overlapping other entries."
		if not fseek directory (header.directoryOffset + offset) #seek_set then throw ("Directory seek error at 0x" + formattedPrint (header.directoryOffset + offset) format:"08X")
		if offset == header.directorySize then header.directorySize += header.entrySize
		entry.creationTime = entry.lastAccessTime = entry.lastWriteTime = CreateDOSTimestamp()
		entry.WriteStream directory
		OK
	),

	fn Reset = (parents = #(0); ReadEntry 0),

	-- Get full pathname as array
	fn GetPath = for offset in parents collect (ReadEntry offset; ReadName entry.nameOffset),

	-- Get current folder name
	fn GetCurrentFolder = (ReadEntry parents[parents.count]; ReadName entry.nameOffset),

	-- Get list of folders in current folder
	fn GetFolders = (
		ReadEntry parents[parents.count]

		local result = #(), offset = entry.childOffset
		while offset > 0 do (ReadEntry offset; if entry.IsFolder() then append result (ReadName entry.nameOffset); offset = entry.nextOffset)
		result -- Array of string
	),

	-- Get list of files in current folder
	fn GetFiles = (
		ReadEntry parents[parents.count]

		local result = #(), offset = entry.childOffset
		while offset > 0 do (ReadEntry offset; if entry.IsFile() then append result (ReadName entry.nameOffset); offset = entry.nextOffset)
		result -- Array of string
	),

	-- Find entry matching filename in current folder
	fn GetChildOffset target = (
		ReadEntry parents[parents.count]
		target = MAXLancer.hash target

		local found = false, offset = entry.childOffset
		while not found and offset > 0 do (ReadEntry offset; if target == MAXLancer.hash (ReadName entry.nameOffset) then found = true else offset = entry.nextOffset)
		if found then offset else 0
	),

	-- Appends current entry to end of directory and attaches to current folder
	fn AppendEntry = (
		if not fseek directory 0 #seek_end then throw "Directory seek error."

		-- TODO: Consider using unused offsets first before appending to end of directory

		local result = ftell directory - header.directoryOffset
		WriteEntry result

		ReadEntry parents[parents.count]

		-- Set childOffset/nextOffset to new entry
		local offset = entry.childOffset
		if offset == 0 then (entry.childOffset = result; WriteEntry parents[parents.count]) else
		while offset > 0 do (ReadEntry offset; if entry.nextOffset > 0 then offset = entry.nextOffset else (entry.nextOffset = result; WriteEntry offset; offset = 0))

		result -- Return Integer (offset to new entry)
	),

	-- Opens folder, creates new one if none found
	fn OpenFolder target = (
		local offset = GetChildOffset target
		if offset > 0 then (if entry.IsFolder() then (append parents offset; true) else false) else ( -- Add Folder
			
			entry = UTFEntry nameOffset:(WriteName target)
			entry.fileAttributes = bit.set entry.fileAttributes 5 true

			append parents (AppendEntry())
			true
		)
	),

	-- Move one level up
	fn CloseFolder = if parents.count > 1 then (parents.count = parents.count - 1; true) else false,

	-- Close currently opened file
	fn CloseFile = if fileOffset > 0 then (
		ReadEntry fileOffset

		if not fseek data 0 #seek_end then throw "Data seek error."

		entry.dataSizeUncompressed = entry.dataSizeUsed = (ftell data) - entry.childOffset - header.dataOffset
		
		-- Pad and update allocated size
		if entry.dataSizeUsed == 0 then entry.childOffset = 0 else entry.dataSizeAllocated = (AlignStream data) - entry.childOffset - header.dataOffset

		WriteEntry fileOffset -- Update file entry with data size values
		fileOffset = 0
		true
	) else false,

	-- Open new file in current folder for writing
	fn OpenFile target = (
		CloseFile() -- Close any open file

		local offset = GetChildOffset target
		if offset == 0 then (
			if not fseek data 0 #seek_end then "Data seek error."

			entry = UTFEntry nameOffset:(WriteName target) childOffset:(ftell data - header.dataOffset)
			entry.fileAttributes = bit.set entry.fileAttributes 8 true

			fileOffset = AppendEntry()
			true
		) else false
	),

	-- Write integer value as file
	fn WriteFileInteger target i sign = if OpenFile target then WriteLong data i sign and CloseFile(),

	-- Write array of numbers as sequence of bytes (8-bit integers)
	fn WriteFileBytes target values sign = if OpenFile target then (for i = 1 to values.count do WriteByte data values[i] sign; CloseFile()),

	-- Write array of numbers as sequence of shorts (16-bit integers)
	fn WriteFileShorts target values sign = if OpenFile target then (for i = 1 to values.count do WriteShort data values[i] sign; CloseFile()),

	-- Write array of numbers as sequence of longs (32-bit integers)
	fn WriteFileLongs target values sign = if OpenFile target then (for i = 1 to values.count do WriteLong data values[i] sign; CloseFile()),

	-- Write float value as file
	fn WriteFileFloat target f = if OpenFile target then WriteFloat data f and CloseFile(),

	-- Write array of numbers as sequence of floats
	fn WriteFileFloats target values = if OpenFile target then (for i = 1 to values.count do WriteFloat data values[i]; CloseFile()),

	-- Write string as sequence of character codes
	fn WriteFileString target s = if OpenFile target then WriteString data s and CloseFile(),

	-- Write color as sequence of floats (RGB)
	fn WriteFileColorFloat target c = if OpenFile target then (WriteColorFloat data c; CloseFile()),

	-- Write position vector as sequence of floats (XYZ)
	fn WriteFilePosition target p = if OpenFile target then (WritePosition data p; CloseFile()),

	-- Write rotation/scale components of transformation matrix as sequence of floats (row1, row2, row3)
	fn WriteFileRotationPart target m = if OpenFile target then (WriteRotationPart data m; CloseFile()),

	-- Write translation components of transformation matrix as sequence of floats (row4)
	fn WriteFileTranslationPart target m = if OpenFile target then (WriteTranslationPart data m; CloseFile()),

	-- Write new file into current folder from filesystem
	fn ImportFile target filename autoClose:true = if doesFileExist filename and OpenFile target then (
		local file = fopen filename "rbS"
		CopyStream file data (getFileSize filename)
		fclose file
		if autoClose then CloseFile()
		true
	) else false,

	-- Open new file for writing
	fn Open target = (

		-- Test if we can even write to target path


		filename = target
		location = pathConfig.appendPath MAXLancer.temporaryPath (toUpper (((dotNetClass "System.Guid").NewGuid()).toString()))
		if not makeDir location then throw ("Unable to create temporary folder: " + location)

		directory = fopen (pathConfig.appendPath location "directory") "wb+"
		names     = fopen (pathConfig.appendPath location "names")     "wb+"
		data      = fopen (pathConfig.appendPath location "data")      "wb+"

		-- Add empty byte to dictionary like all vanilla files have
		if WriteByte names 0 then header.namesSizeUsed += 1 else throw "Error writing into names."
		
		-- Add root entry
		entry.nameOffset = WriteName "\\"
		entry.fileAttributes = bit.set entry.fileAttributes 5 true
		WriteEntry 0

		Reset()
	),

	fn Close = (
		CloseFile() -- Close any open file

		MAXLancer.WriteLog ("Writing UTF file: " + filename)

		-- Update and write header
		header.namesSizeAllocated = (AlignStream names) - header.namesOffset
		header.directoryOffset    = 56 -- Header size
		header.namesOffset        = header.directoryOffset + header.directorySize
		header.dataOffset         = header.namesOffset + header.namesSizeAllocated
		header.filetime           = ((dotNetClass "System.DateTime").SpecifyKind ((dotNetClass "System.DateTime").Now) (dotNetClass "System.DateTimeKind").Utc).toFileTime()

		fclose directory
		fclose names
		fclose data
		
		directory = fopen (pathConfig.appendPath location "header") "wb"
		header.WriteStream directory
		fclose directory

		HiddenDOSCommand "COPY /V /Y /B header+directory+names+data output" startpath:location -- Concatenate section files
		if doesFileExist filename then if not DeleteFile filename then throw "Could not overwrite existing file" -- Delete file to overwrite
		if not renameFile (pathConfig.appendPath location "output") filename then throw "Could not copy UTF file to destination" -- Copy result to specified filename

		MAXLancer.WriteLog ("Written " + formattedPrint (getFileSize filename) format:"u" + " bytes")
		OK
	)
)
