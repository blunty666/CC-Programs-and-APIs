-- STRING FUNCTIONS
local string_byte = string.byte
local string_len = string.len
local string_find = string.find
local string_sub = string.sub

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
		
		currPos = findNext(str, currPos, commaPattern)
		if not currPos then
			return object, string_len(str) + 1
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
		
		currPos = findNext(str, currPos, commaPattern)
		if not currPos then
			return array, string_len(str) + 1
		end
	end
	return array, currPos + 1
end

-- PUBLIC FUNCTIONS
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
