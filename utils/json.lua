-- STRING FUNCTIONS
local string_byte = string.byte
local string_len = string.len
local string_find = string.find
local string_sub = string.sub
local string_gsub = string.gsub
local string_rep = string.rep

-- STRING CONSTANTS
local stringPattern = "^[^\"\\]+"
local escapeChars = {
	[string_byte("\"")] = "\"",
	[string_byte("\\")] = "\\",
	[string_byte("/")] = "/",
	[string_byte("b")] = "\b",
	[string_byte("f")] = "\f",
	[string_byte("n")] = "\n",
	[string_byte("r")] = "\r",
	[string_byte("t")] = "\t",
	--[[ hex number
	[string_byte("u")] = "\u",
	]]
}

-- NUMBER CONSTANTS
local numberStartBytes = {}
for _, numberByte in ipairs({string_byte("+-0123456789", 1, 12)}) do
	numberStartBytes[numberByte] = true
end
local numberPatternStart = "^[+-]?%d+[.]*[%d]*"
local numberPatternEnd = "^[eE][+-]?%d+"

-- OBJECT / ARRAY CONSTANTS
local semiColonPattern = "^%s*:%s*"
local commaPattern = "^%s*,%s*"

-- DECODING
local function skipWhitespace(str, pos)
	return string_find(str, "%S", pos) or string_len(str) + 1
end

local function findNext(str, pos, pattern)
	local startPos, endPos = string_find(str, pattern, pos)
	if startPos then
		return endPos + 1
	end
	return false
end

local decodeValue, decodeString, decodeNumber, decodeObject, decodeArray

decodeValue = function(str, pos)
	pos = skipWhitespace(str, pos)
	local currentByte = string_byte(str, pos, pos)
	if currentByte == 34 then
		return decodeString(str, pos + 1)
	elseif numberStartBytes[currentByte] then
		return decodeNumber(str, pos)
	elseif currentByte == 123 then
		return decodeObject(str, pos + 1)
	elseif currentByte == 91 then
		return decodeArray(str, pos + 1)
	elseif string_sub(str, pos, pos + 3) == "true" then
		return true, pos + 4
	elseif string_sub(str, pos, pos + 4) == "false" then
		return false, pos + 5
	elseif string_sub(str, pos, pos + 3) == "null" then
		return nil, pos + 4
	end
	return nil, pos
end

decodeString = function(str, pos)
	local s, currPos = "", pos
	while string_byte(str, currPos, currPos) ~= 34 do
		local startPos, endPos = string_find(str, stringPattern, currPos)
		if startPos then
			s = s..string_sub(str, startPos, endPos)
			currPos = endPos + 1
		end
		if string_byte(str, currPos, currPos) == 92 then
			local thisByte = string_byte(str, currPos + 1, currPos + 1)
			if thisByte == nil or not escapeChars[thisByte] then
				return nil, string_len(str) + 1
			end
			s = s..escapeChars[thisByte]
			currPos = currPos + 2
		end
	end
	return s, currPos + 1
end

decodeNumber = function(str, pos)
	local _, endPos = string_find(str, numberPatternStart, pos)
	local newStartPos, newEndPos = string_find(str, numberPatternEnd, endPos + 1)
	if newStartPos then
		endPos = newEndPos
	end
	return tonumber(string_sub(str, pos, endPos)), endPos + 1
end

decodeObject = function(str, pos)
	local currPos = skipWhitespace(str, pos)
	local object = {}
	while string_byte(str, currPos, currPos) ~= 125 do
		if string_byte(str, currPos, currPos) ~= 34 then
			return object, string_len(str) + 1
		end
		
		local key
		key, currPos = decodeString(str, currPos + 1)
		if not key then
			return object, string_len(str) + 1
		end
		
		currPos = findNext(str, currPos, semiColonPattern)
		if not currPos then
			return object, string_len(str) + 1
		end
		
		local value
		value, currPos = decodeValue(str, currPos)
		
		object[key] = value
		
		local nextPos = findNext(str, currPos, commaPattern)
		if not nextPos then
			return object, findNext(str, currPos, "}")
		else
			currPos = nextPos
		end
	end
	return object, currPos + 1
end

decodeArray = function(str, pos)
	local currPos = skipWhitespace(str, pos)
	local array, index = {}, 1
	while string_byte(str, currPos, currPos) ~= 93 do
		local value
		value, currPos = decodeValue(str, currPos)
		
		array[index] = value
		index = index + 1
		
		local nextPos = findNext(str, currPos, commaPattern)
		if not nextPos then
			return array, findNext(str, currPos, "]")
		else
			currPos = nextPos
		end
	end
	return array, currPos + 1
end

-- PUBLIC DECODE FUNCTIONS
function decode(str)
	if type(str) ~= "string" then
		error("decode: string expected, got "..type(str), 2)
	end
	return decodeValue(str, 1)
end

function decodeFromFile(path)
	if type(path) ~= "string" then
		error("decodeFromFile: string expected, got "..type(path), 2)
	end
	if fs.exists(path) and not fs.isDir(path) then
		local file = fs.open(path, "r")
		if file then
			local data = file.readAll()
			file.close()
			if data then
				return decodeValue(data, 1)
			end
		end
	end
end

-- ENCODING
local encodeValue, encodeString, encodeNumber, encodeBoolean, encodeArray, encodeObject

local function makeReadable(value, tabCount)
	return "\n"..string_rep("\t", tabCount)..value
end

local function isArray(value)
	local arraySize = 0
	for index, _ in pairs(value) do
		if type(index) ~= "number" then
			return false
		elseif index < 1 then
			return false
		elseif math.floor(index) ~= index then
			return false -- not an integer
		end
		if index > arraySize then
			arraySize = index
		end
	end
	return arraySize
end

encodeValue = function(value, tabCount, tracking)
	local valueType = type(value)
	if valueType == "string" then
		return encodeString(value)
	elseif valueType == "number" then
		return encodeNumber(value)
	elseif valueType == "boolean" then
		return encodeBoolean(value)
	elseif valueType == "table" then
		if tracking[value] then
			error("Cannot encode table with recursive entries", 0)
		end
		tracking[value] = true
		local arraySize = isArray(value)
		if arraySize then
			return encodeArray(value, tabCount, tracking, arraySize)
		else
			return encodeObject(value, tabCount, tracking)
		end
	end
	return "null"
end

local controlChars = {
	["\""] = "\\\"",
	["\\"] = "\\\\",
	["\/"] = "\\/",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}
encodeString = function(value)
	return '"'..string_gsub(value, "[\"\\&c]", controlChars)..'"'
end

encodeNumber = function(value)
	if value == math.huge then
		return "1e1000"
	elseif value == -math.huge then
		return "-1e1000"
	end
	return tostring(value)
end

encodeBoolean = function(value)
	return tostring(value)
end

encodeArray = function(array, tabCount, tracking, arraySize)
	if arraySize > 0 then
		local _array = "["
		for index = 1, arraySize do
			local value = encodeValue(array[index], tabCount and tabCount + 1 or false, tracking)..","
			_array = _array..((tabCount and makeReadable(value, tabCount + 1)) or value)
		end
		return _array..((tabCount and makeReadable("]", tabCount)) or "]")
	end
	return "[]"
end

encodeObject = function(object, tabCount, tracking)
	local _object = "{"
	for index, value in pairs(object) do
		if type(index) ~= "string" then
			error("Object index must be a string", 0)
		end
		local _value = encodeString(index)..((tabCount and ": ") or ":")
		_value = _value..encodeValue(value, tabCount and tabCount + 1 or false, tracking)..","
		_object = _object..((tabCount and makeReadable(_value, tabCount + 1)) or _value)
	end
	return _object..((tabCount and makeReadable("}", tabCount)) or "}")
end

-- PUBLIC ENCODE FUNCTION
function encode(value, readable)
	return encodeValue(value, readable == true and 0 or false, {})
end
