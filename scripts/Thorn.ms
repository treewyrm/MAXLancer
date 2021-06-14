/**
 * MAXLancer toolkit - Copyright (c) Yuriy Alexeev <treewyrm@gmail.com>
 *
 * THN/LUA utilites/routines used in cutscenes.
 */

-- Simple writer interface to output THN/LUA serialized data
struct ThornWriter (
	stream  = StringStream "",
	entries = #(0),
	indent  = "",
	padding = "\t",
	
	-- Set line indentation size
	fn SetIndent size = (
		indent = ""
		for i = 1 to size do indent += padding
		OK
	),
	
	-- Start {} Object/Array block with optional key
	fn StartArray key: = (
		if entries[1] > 0 then append stream ((if entries[entries.count] > 0 then ",\n" else "\n") + indent)
		append stream (if key != unsupplied then ((key as String) + " = {") else "{")

		entries[entries.count] += 1
		entries[entries.count + 1] = 0
		
		SetIndent (entries.count - 1)
		OK
	),
	
	-- End {} Object/Array block
	fn EndArray = if entries.count > 1 then (
		entries.count = entries.count - 1
		
		SetIndent (entries.count - 1)
		
		append stream ("\n" + indent + "}")
		OK
	),

	-- Write value
	fn WriteRaw data = (
		case classOf data of (
			BooleanClass: append stream (if data then "true" else "false")
			Point3:       format "{%, %, %}" data.x data.z -data.y to:stream
			Quat:         format "{%, %, %, %}" data.w data.x data.z -data.y to:stream
			Matrix3:      format "{{%, %, %}, {%, %, %}, {%, %, %}}" data.row1.x data.row1.z -data.row1.y data.row3.x data.row3.z -data.row3.y -data.row2.x -data.row2.z data.row2.y to:stream
			Name:         append stream (toUpper (data as String))
			default:      append stream data
		)
		
		OK
	),
	
	-- Write key = value property
	fn WriteProperty key data raw:false = (
		append stream ((if entries[entries.count] > 0 then ",\n" else "\n") + indent)
		
		format "% = " key to:stream
		if classOf data == String and not raw then format "\"%\"" data to:stream else WriteRaw data
		
		entries[entries.count] += 1
		OK
	),
	
	-- Copy contents of stream into Windows clipboard buffer
	fn CopyToClipboard = (
		local result = stream as String
		
		case setClipboardText result of (
			(-1): displayTempPrompt "Error: Memory for clipboard could not be allocated" 2000
			(-4): displayTempPrompt "Error: Clipboard could not be set" 2000
			default: displayTempPrompt ("Copied " + formattedPrint result.count format:"d" + " chars") 2000
		)
		
		OK
	)
)