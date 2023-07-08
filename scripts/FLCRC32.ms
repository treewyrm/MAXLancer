/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 */

struct FLCRC32 (
	hashes = #(), -- Hash table

	-- Hash 32-bit integer
	fn HashInteger i crc = (
		crc = bit.xor (bit.shift crc -8) hashes[1 + bit.xor (bit.and crc 0xFF) (bit.and i 0xFF)]
		crc = bit.xor (bit.shift crc -8) hashes[1 + bit.xor (bit.and crc 0xFF) (bit.and (bit.shift i -8) 0xFF)]
		crc = bit.xor (bit.shift crc -8) hashes[1 + bit.xor (bit.and crc 0xFF) (bit.and (bit.shift i -16) 0xFF)]
		crc = bit.xor (bit.shift crc -8) hashes[1 + bit.xor (bit.and crc 0xFF) (bit.and (bit.shift i -24) 0xFF)]

		bit.not crc -- Return Integer
	),

	-- Hash point2 (2x floats)
	fn HashPoint2 p crc = (
		crc = HashInteger (bit.floatAsInt p.x) crc
		crc = HashInteger (bit.floatAsInt p.y) crc

		bit.not crc -- Return Integer
	),

	-- Hash point3 (3x floats)
	fn HashPoint3 p crc = (
		crc = HashInteger (bit.floatAsInt p.x) crc
		crc = HashInteger (bit.floatAsInt p.y) crc
		crc = HashInteger (bit.floatAsInt p.z) crc

		bit.not crc -- Return Integer
	),

	-- Hash ASCII string with case sensitivity
	fn HashString s crc caseSensitive:false = (
		local c

		for i = 1 to s.count while (c = bit.charAsInt s[i]) > 0 do (
			if not caseSensitive and c >= 65 and c <= 90 then c = bit.xor c 32
			crc = bit.xor (bit.shift crc -8) hashes[1 + bit.xor (bit.and crc 0xFF) c]
		)

		bit.not crc -- Return Integer
	),

	-- Hash any valid input
	fn Hash input crc:-1 caseSensitive:false force:false = (
		case classOf input of (
			String:  if not force and IsHexString input then bit.hexAsInt input else HashString input crc caseSensitive:caseSensitive
			Integer: if force then HashInteger input crc else input
			Float:   HashInteger (bit.floatAsInt input) crc
			Color:   HashInteger (PackColor input) crc
			Point2:  HashPoint2 input crc
			Point3:  HashPoint3 input crc
			default: throw "Unknown hash input type."
		)
	),

	fn Hash64 input crc:-1L caseSensitive:false force:false = (

		fn HashInteger64 i crc = (
			for b = 0 to -56 by -8 do
				crc = bit.xor (bit.shift crc -8) hashes[1 + bit.xor (bit.and crc 0xFF) (bit.and (bit.shift i -b) 0xFF)]

			bit.not crc -- Return Integer64
		)

		case classOf input of (
			Float:  HashInteger64 (bit.floatAsInt input as Integer64) crc
			Double: HashInteger64 (bit.floatAsInt input) crc
			Color:  HashInteger64 (PackColor input) crc
			Point2: bit.xor (HashInteger64 (bit.floatAsInt input.x as Integer64) crc) (HashInteger64 (bit.floatAsInt input.y as Integer64) crc)
			Point3: bit.xor (HashInteger64 (bit.floatAsInt input.z as Integer64) crc) (bit.xor (HashInteger64 (bit.floatAsInt input.x as Integer64) crc) (HashInteger64 (bit.intAsFloat input.y as Integer64) crc)
		)
	),

	-- Load FLCRC32 hashes from hashtable file
	fn LoadFile filename offset:0 = (
		if not doesFileExist filename then throw ("Hash table file does not exist: " + filename)

		local stream = fopen filename "rb"
		if not fseek stream offset #seek_set then throw ("Error seek to hash table offset " + FormatID offset)

		for i = 1 to hashes.count = 256 do hashes[i] = ReadLong stream #unsigned
		fclose stream
		OK
	)
)