/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * Filename patterns for storing textures for import/export.
 * 
 * _dxt1.tga  - Import as inverted DDS compressed DXT1
 * _dxt1a.tga - Import as inverted DDS compressed DXT1a
 * _dxt3.tga  - Import as inverted DDS compressed DXT3
 * _dxt5.tga  - Import as inverted DDS compressed DXT5
 * _rgba.tga  - Import as inverted DDS uncompressed RGBA
 * _mip0.tga  - Import as TGA and sequentially lookup other levels to import
 *
 * Unmatched .tga will be imported as MIP0 without MIP1-n lookups.
 * Unmatched .dds will be imported as MIPS without vertical flip.
 */

struct TGAHeader (
	textLength     = 0,
	indexedPalette = 0,
	imageType      = 0,
	paletteOrigin  = 0,
	paletteLength  = 0,
	paletteDepth   = 0,
	origin         = [0, 0],
	width          = 0,
	height         = 0,
	bitDepth       = 0,
	descriptor     = 0,

	fn ReadStream stream = (
		textLength     = ReadByte stream #unsigned
		indexedPalette = ReadByte stream #unsigned
		imageType      = ReadByte stream #unsigned  -- 0 - no image, 1 - indexed palette, 2 - rgb
		paletteOrigin  = ReadShort stream #unsigned
		paletteLength  = ReadShort stream #unsigned
		paletteDepth   = ReadByte stream #unsigned
		origin         = [ReadShort stream #unsigned, ReadShort stream #unsigned]
		width          = ReadShort stream #unsigned
		height         = ReadShort stream #unsigned
		bitDepth       = ReadByte stream #unsigned
		descriptor     = ReadByte stream #unsigned

		fseek stream textLength #seek_cur -- Skip ID text
		OK
	)
)

struct DDSPixelFormat (
	size,      -- dwSize
	flags,     -- dwFlags
	fourCC,    -- dwFourCC
	bitCount,  -- dwRGBBitCount
	maskRed,   -- dwRBitMask
	maskGreen, -- dwGBitMask
	maskBlue,  -- dwBBitMask
	maskAlpha, -- dwABitMask

	fn ReadStream stream = (
		size      = ReadLong stream #unsigned
		flags     = ReadLong stream #unsigned
		fourCC    = ReadLong stream #unsigned -- Compression fourCC marker
		bitCount  = ReadLong stream #unsigned -- Bits per pixel
		maskRed   = ReadLong stream #unsigned
		maskGreen = ReadLong stream #unsigned
		maskBlue  = ReadLong stream #unsigned
		maskAlpha = ReadLong stream #unsigned
		OK
	)
)

struct DDSHeader (
	size,        -- dwSize (always 124)
	flags,       -- dwFlags
	height,      -- dwHeight
	width,       -- dwWidth
	pitch,       -- dwPitchOrLinearSize
	depth,       -- dwDepth
	mipmapCount, -- dwMipMapCount
	pixelFormat = DDSPixelFormat(),

	fn ReadStream stream = (
		if (ReadLong stream #unsigned) != 0x20534444 then throw "Invalid DDS file signature."

		size        = ReadLong stream #unsigned
		flags       = ReadLong stream #unsigned
		height      = ReadLong stream #unsigned
		width       = ReadLong stream #unsigned
		pitch       = ReadLong stream #unsigned
		depth       = ReadLong stream #unsigned
		mipmapCount = ReadLong stream #unsigned

		fseek stream 44 #seek_cur -- Skip dwReserved1 (44 bytes)

		pixelFormat.ReadStream stream
	)
)

-- Open bitmap file and flip it vertically
fn FlipImage filename = (
	local source = openBitmap filename
	local target = bitmap source.width source.height filename:filename
	local upper
	local lower

	for i = 1 to source.height / 2 do (
		upper = getPixels source [0, i - 1] source.width
		lower = getPixels source [0, source.height - i] source.width

		setPixels target [0, i - 1] lower
		setPixels target [0, source.height - i] upper
	)
	
	close source
	save  target
	close target
	OK
)

struct FLTexture (
	filename, -- Internal filename
	external, -- External filename
	image,    -- Bitmap object

	fn ToString stream = (
		format "% (0x%): %\r\n" filename (formattedPrint (MAXLancer.Hash filename) format:"08X") external to:stream
	),

	-- Get bitmap object from external file
	fn GetBitmap = if classOf image != bitmap and doesFileExist external then image = openBitmap external else image,

	-- Export DDS and decompress into Targa
	fn ReadDDS reader progress: = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		local header         -- DDSHeader
		local type           -- Filename suffix indicating what it should be compressed back to
		local inputFilename  -- Extracted DDS texture
		local outputFilename -- Converted TGA texture
		local commandText    -- nvdecompress.exe command to decompress DDS into Targa

		if reader.OpenFile "MIPS" then (
			(header = DDSHeader()).ReadStream reader.data

			type = case header.pixelFormat.fourCC of (
				0x31545844: "_dxt1"
				0x33545844: "_dxt3"
				0x35545844: "_dxt5"
				default:    "_rgba"
			)

			inputFilename  = MAXLancer.GetTemporaryFilename() + ".dds"
			outputFilename = MAXLancer.GetTemporaryFilename() + ".tga"
			commandText    = StringStream ""
			
			MAXLancer.WriteLog ("Extracting texture " + filename + " to: " + inputFilename)
			
			-- Re-construct path to external file
			external = (pathConfig.appendPath (pathConfig.appendPath MAXLancer.texturesPath (filenameFromPath reader.filename)) (getFilenameFile filename)) + type + ".tga"	

			-- Extract DDS into temporary file
			reader.ExportFile "MIPS" inputFilename
			if not doesFileExist inputFilename then throw ("Unable to extract texture " + filename + " to path:\r\n" + inputFilename)

			-- Decompress DDS into TGA
			format "nvdecompress.exe -format tga \"%\" \"%\"" inputFilename outputFilename to:commandText prompt:("Decompressing texture: " + filename)
			
			MAXLancer.WriteLog ("Decompressing texture (" + filename + "): " + inputFilename)
			
			HiddenDOSCommand commandText startpath:MAXLancer.textureToolsPath
			if not doesFileExist outputFilename then throw ("Unable to decompress texture to path:\r\n" + outputFilename)

			-- Flip resulting TGA image and move to external path
			FlipImage outputFilename
			copyFile outputFilename external
			
			if classOf progress == MAXScriptFunction then progress (getFileSize inputFilename)

			-- Delete input DDS and TGA files
			deleteFile inputFilename
			deleteFile outputFilename
		)

		OK
	),

	-- Export all Targa mipmaps
	fn ReadTargaMips reader progress: = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		local header       -- TGAHeader
		local mipEntryname -- Mip entry name (MIP2)
		local mipFilename  -- Mip output filename (\MAXLancer\whatever.mat\MyTexture_mip2.tga)

		local level    = 0
		local filepath = pathConfig.appendPath (pathConfig.appendPath MAXLancer.texturesPath (filenameFromPath reader.filename)) (getFilenameFile filename)

		while reader.OpenFile (mipEntryname = "MIP" + formattedPrint level format:"u") do (
			
			-- Just check header
			(header = TGAHeader()).ReadStream reader.data

			reader.ExportFile mipEntryname (mipFilename = (filepath + "_mip" + formattedPrint level format:"u" + ".tga"))

			if level == 0 then external = mipFilename
			level += 1

			if classOf progress == MAXScriptFunction then progress reader.size
		)

		OK
	),

	fn ReadUTF reader progress: = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		-- Folder: sceneassets\MAXLancer\whatever.mat
		local filepath = pathConfig.appendPath MAXLancer.texturesPath (filenameFromPath reader.filename)

		if not doesFileExist filepath then makeDir filepath

		-- Add filename without extension: sceneassets\MAXLancer\whatever.mat\MyTexture
		filepath = pathConfig.appendPath filepath (getFilenameFile filename)

		-- Valid filetype extensions to look for
		local extensions = #("_rgba.tga", "_dxt5.tga", "_dxt3.tga", "_dxt1a.tga", "_dxt1.tga", "_mip0.tga", ".dds", ".tga")

		-- Pick first match
		for extension in extensions while external == undefined where doesFileExist (filepath + extension) do external = filepath + extension

		-- Extract from UTF if no matches were found
		if external == undefined then ReadDDS reader progress:progress       -- Try MIPS first
		if external == undefined then ReadTargaMips reader progress:progress -- Try MIP0 otherwise (MIP0 is ignored if MIPS is present)

		OK
	),

	fn WriteTargaMips writer progress: = (
		local level    = 0
		local filename = getFilenameFile external
		local filepath = getFilenamePath external
		local partname = substring filename 1 (filename.count - 5)

		while doesFileExist (filename = pathConfig.appendPath filepath (partname + "_mip" + formattedPrint level format:"u" + ".tga")) do (
			writer.ImportFile ("MIP" + formattedPrint level format:"u") filename
			level += 1

			if classOf progress == MAXScriptFunction then progress (getFileSize filename)
		)

		OK
	),

	fn WriteDDS writer compression:"-rgba" progress: = (
		local commandText    = StringStream ""
		local inputFilename  = MAXLancer.GetTemporaryFilename() + ".tga" -- Temporary filename for input Targa image
		local outputFilename = MAXLancer.GetTemporaryFilename() + ".dds" -- Temporary filename for output DDS

		copyFile external inputFilename
		FlipImage inputFilename

		format "nvcompress.exe -silent -color % \"%\" \"%\"" compression inputFilename outputFilename to:commandText prompt:("Compressing texture: " + filename)
		HiddenDOSCommand commandText startpath:MAXLancer.textureToolsPath

		-- Import resulting DDS
		writer.ImportFile "MIPS" outputFilename
		if classOf progress == MAXScriptFunction then progress (getFileSize outputFilename)

		deleteFile outputFilename
		deleteFile inputFilename

		OK
	),

	fn WriteUTF writer progress: = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		case FLTextureLibrary.GetTextureType (filenameFromPath external) of (
			#DDS_RGBA:  WriteDDS writer
			#DDS_DXT1:  WriteDDS writer compression:"-bc1"
			#DDS_DXT1A: WriteDDS writer compression:"-bc1a"
			#DDS_DXT3:  WriteDDS writer compression:"-bc2"
			#DDS_DXT5:  WriteDDS writer compression:"-bc3"
			#TGA_MAPS:  WriteTargaMips writer
			#MIPS:      writer.ImportFile "MIPS" external
			#MIP0:      writer.ImportFile "MIP0" external
			default: throw "Texture filename does not match supported patterns."
		)

		OK
	)	
)

struct FLTextureLibrary (
	textures = #(), -- Array of FLTexture

	fn ToString stream = (
		format "Texture Library (%):\r\n" textures.count to:stream
		for t in textures do t.ToString stream
	),

	-- Get texture from library by ID (string or hash number)
	fn GetTexture target = (
		target = MAXLancer.hash target

		local result
		for texture in textures while result == undefined where MAXLancer.hash texture.filename == target do result = texture
		result -- Return FLTexture
	),

	-- Get texture import type settings from filename
	fn GetTextureType filename = (
		case of (
			(MatchPattern filename pattern:"*_rgba.tga" ignoreCase:true):  #DDS_RGBA
			(MatchPattern filename pattern:"*_dxt1.tga" ignoreCase:true):  #DDS_DXT1
			(MatchPattern filename pattern:"*_dxt1a.tga" ignoreCase:true): #DDS_DXT1A
			(MatchPattern filename pattern:"*_dxt3.tga" ignoreCase:true):  #DDS_DXT3
			(MatchPattern filename pattern:"*_dxt5.tga" ignoreCase:true):  #DDS_DXT5
			(MatchPattern filename pattern:"*_mip0.tga" ignoreCase:true):  #TGA_MAPS
			(MatchPattern filename pattern:"*.dds" ignoreCase:true):       #MIPS
			(MatchPattern filename pattern:"*.tga" ignoreCase:true):       #MIP0
		)
	),	

	fn GetItem id = GetTexture id, -- Alias for autoloader

	fn AddTexture target = (
		if not doesFileExist target then throw "Texture file does not exist."
		
		local filename = filenameFromPath target
		local type = GetTextureType filename

		-- Remove filename patterns
		filename = case type of (
			#DDS_RGBA:  (substring filename 1 (filename.count - 9)) + ".tga"
			#DDS_DXT1:  (substring filename 1 (filename.count - 9)) + ".tga"
			#DDS_DXT1A: (substring filename 1 (filename.count - 10)) + ".tga"
			#DDS_DXT3:  (substring filename 1 (filename.count - 9)) + ".tga"
			#DDS_DXT5:  (substring filename 1 (filename.count - 9)) + ".tga"
			#TGA_MAPS:  (substring filename 1 (filename.count - 9)) + ".tga"
			#MIPS:      (substring filename 1 (filename.count - 4)) + ".tga"
			#MIP0:      filename
		)

		local result = GetTexture filename
		if result == undefined then append textures (result = FLTexture filename:filename external:target)
		
		result -- Return new FLTexture or one matching texture name
	),

	-- Read textures from UTFReader
	fn ReadUTF reader filter: progress: = (
		if classOf reader != UTFReader then throw "Invalid UTFReader object."

		local item

		if reader.OpenFolder "Texture library" then (
			for filename in (if filter == unsupplied then reader.GetFolders() else filter) where (item = GetTexture filename) == undefined and reader.OpenFolder filename do (
				filename = reader.ReadName reader.entry.nameOffset

				MAXLancer.WriteLog ("Reading texture: " + filename)

				item = FLTexture filename:filename
				item.ReadUTF reader progress:progress

				append textures item
				reader.CloseFolder() -- Close filename
			)

			reader.CloseFolder() -- Close texture library
		)

		OK
	),

	-- Write textures into UTFWriter
	fn WriteUTF writer filter: progress: = (
		if classOf writer != UTFWriter then throw "Invalid UTFWriter object."

		local item
		local items = if classOf filter == Array then for filename in filter where (item = GetTexture filename) != undefined collect item else textures

		if items.count > 0 and writer.OpenFolder "Texture library" then (
			for item in items where writer.OpenFolder item.filename do (
				MAXLancer.WriteLog ("Writing texture: " + item.filename)

				item.WriteUTF writer progress:progress
				writer.CloseFolder() -- Close filename
			)

			writer.WriteFileInteger "Texture count" items.count #unsigned
			writer.CloseFolder() -- Close texture library
		)

		OK
	),
	-- Load texture library from file (.txm)
	fn LoadFile filename filter: progress: = (
		local reader = UTFReader()
		reader.Open filename
		ReadUTF reader filter:filter progress:progress
		reader.Close()
		OK
	),

	-- Save texture library into file (.txm)
	fn SaveFile filename filter: progress: = (
		local writer = UTFWriter()
		writer.Open filename
		WriteUTF writer filter:filter progress:progress
		writer.Close()
		OK
	)
)
