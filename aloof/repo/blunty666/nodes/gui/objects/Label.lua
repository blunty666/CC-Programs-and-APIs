package = "blunty666.nodes.gui.objects"

imports = {
	"blunty666.nodes.*",
	"aloof.TypeChecker",
}

class = "Label"
extends = "Drawable"

local import = {
	"Utils",
}

local ALIGNMENT = {
	HORIZONTAL = {
		LEFT = true,
		MIDDLE = true,
		RIGHT = true,
	},
	VERTICAL = {
		TOP = true,
		MIDDLE = true,
		BOTTOM = true,
	}
}

local function getText(text, length, align)
	if #text > length then
		if align == "LEFT" then
			return text:sub(1, length)
		elseif align == "MIDDLE" then
			local lNum, rNum = math.floor((#text - length)/2), math.ceil((#text - length)/2)
			return text:sub(lNum + 1, #text - rNum)
		elseif align == "RIGHT" then
			return text:sub(#text - length + 1)
		end
	elseif #text < length then
		if align == "LEFT" then
			return text..string.rep(" ", length - #text)
		elseif align == "MIDDLE" then
			local lNum, rNum = math.floor((length - #text)/2), math.ceil((length - #text)/2)
			return string.rep(" ", lNum)..text..string.rep(" ", rNum)
		elseif align == "RIGHT" then
			return string.rep(" ", length - #text)..text
		end
	end
	return text
end

local function checkForWord(text, startPos, length)
	local endSpace = text:sub(startPos + length - 1, startPos + length - 1):find(" ")
	local startSpace = text:sub(startPos + length, startPos + length):find(" ")
	if not endSpace and not startSpace then
		local lastWordStart = text:sub(startPos, startPos + length - 1):find("[^ ]+$")
		local wordStart, wordEnd = text:find("[^ ]+", lastWordStart + startPos - 1)
		if wordEnd - wordStart + 1 > length then
			return startPos + length - 1
		elseif wordStart >= startPos + 2 then
			return wordStart - 2
		end
		return wordStart - 1
	elseif not endSpace and startSpace then
		return startPos + length - 1
	end
	return startPos + length - 2
end

local function tabulateText(map, line, length)
	local currStart = 1
	local lineLength = line:len()
	while true do
		local newEnd
		if currStart > 1 and line:sub(currStart, currStart):find(" ") then
			currStart = currStart + 1
		end
		if currStart + length - 1 >= lineLength then
			table.insert(map, line:sub(currStart, lineLength))
			return
		else
			newEnd = checkForWord(line, currStart, length)
			table.insert(map, line:sub(currStart, newEnd))
			currStart = newEnd + 1
		end
	end
end

local function adjustWrappedMapHeight(map, length, height, verticalAlignment)
	if #map > height then -- remove lines
		if verticalAlignment == "TOP" then
			for i = height + 1, #map do table.remove(map) end
		elseif verticalAlignment == "MIDDLE" then
			local topNum, bottomNum = math.floor((#map - height)/2), math.ceil((#map - height)/2)
			for i = 1, topNum do table.remove(map, 1) end
			for i = 1, bottomNum do table.remove(map) end
		elseif verticalAlignment == "BOTTOM" then
			for i = height + 1, #map do table.remove(map, 1) end
		end
	elseif #map < height then -- add lines
		local emptyLine = string.rep(" ", length)
		if verticalAlignment == "TOP" then
			for i = #map + 1, height do table.insert(map, emptyLine) end
		elseif verticalAlignment == "MIDDLE" then
			local topNum, bottomNum = math.floor((height - #map)/2), math.ceil((height - #map)/2)
			for i = 1, topNum do table.insert(map, 1, emptyLine) end
			for i = 1, bottomNum do table.insert(map, emptyLine) end
		elseif verticalAlignment == "BOTTOM" then
			for i = #map + 1, height do table.insert(map, 1, emptyLine) end
		end
	end
end

local function adjustWrappedMapWidth(map, length, horizontalAlignment)
	for lineNum, line in ipairs(map) do
		map[lineNum] = getText(line, length, horizontalAlignment)
	end
end

local function createWrappedTextMap(text, length)
	local map = {}
	local seek, line = 0, nil

	-- handle control chars
	--text = text:gsub("\t", "  ")

	while seek < #text do
		line, seek = string.match(text, "([^\n]*)\r?\n-()", seek + 1)
		tabulateText(map, line, length)
	end

	return map
end

local function createTextMap(text, width, height, leftPadding, rightPadding, topPadding, bottomPadding, horizontalAlignment, verticalAlignment, wrapText)
	if width - leftPadding - rightPadding > 0 and height - topPadding - bottomPadding > 0 then
		local textWidth = width - leftPadding - rightPadding
		local textHeight = height - topPadding - bottomPadding
		if wrapText then
			local map = createWrappedTextMap(text, textWidth)
			adjustWrappedMapHeight(map, textWidth, textHeight, verticalAlignment)
			adjustWrappedMapWidth(map, textWidth, horizontalAlignment)
			return map
		else
			local text = getText(text, textWidth, horizontalAlignment)
			local map = {text}
			local verticalAlignment = verticalAlignment
			if verticalAlignment == "TOP" then
				for i = 1, textHeight - 1 do
					table.insert(map, string.rep(" ", textWidth))
				end
			elseif verticalAlignment == "MIDDLE" then
				for i = 1, math.floor((textHeight - 1)/2) do
					table.insert(map, 1, string.rep(" ", textWidth))
				end
				for i = 1, math.ceil((textHeight - 1)/2) do
					table.insert(map, string.rep(" ", textWidth))
				end
			elseif verticalAlignment == "BOTTOM" then
				for i = 1, textHeight - 1 do
					table.insert(map, 1, string.rep(" ", textWidth))
				end
			end
			return map
		end
	else
		return {}
	end
end

local function updateText(label, text, width, height, leftPadding, rightPadding, topPadding, bottomPadding, horizontalAlignment, verticalAlignment, wrapText)
	local map = createTextMap(text, width, height, leftPadding, rightPadding, topPadding, bottomPadding, horizontalAlignment, verticalAlignment, wrapText)
	for yPos = 1, height do
		for xPos = 1, width do
			if yPos > topPadding and yPos <= height - bottomPadding and xPos > leftPadding and xPos <= width - rightPadding then
				local char = string.sub(map[yPos - topPadding], xPos - leftPadding, xPos - leftPadding)
				label:SetCoord(xPos, yPos, char, nil, nil)
			else
				label:SetCoord(xPos, yPos, " ", nil, nil)
			end
		end
	end
end

local function calculateDeltas(padding1, padding2, length)
	local delta = padding1 + padding2 - length
	local delta1 = math.min(padding1, math.floor(delta/2))
	local delta2 = math.min(padding2, math.ceil(delta/2))

	if delta1 < math.floor(delta/2) then
		delta2 = delta2 + math.floor(delta/2) - delta1
	elseif delta2 < math.ceil(delta/2) then
		delta1 = delta1 + math.ceil(delta/2) - delta2
	end

	return delta1, delta2
end

variables = {
	text = "",

	horizontalAlignment = "MIDDLE",
	verticalAlignment = "MIDDLE",

	wrapText = false,

	leftPadding = 0,
	rightPadding = 0,
	topPadding = 0,
	bottomPadding = 0,
}

setters = {
	width = function(self, width)
		if TypeChecker.non_negative_integer(width) then
			self.size = {width, self.height}
			return self.width
		end
		return error("Label - setters - width: non_negative_integer expected, got <"..type(width).."> "..tostring(width), 2)
	end,
	height = function(self, height)
		if TypeChecker.non_negative_integer(height) then
			self.size = {self.width, height}
			return self.height
		end
		return error("Label - setters - height: non_negative_integer expected, got <"..type(height).."> "..tostring(height), 2)
	end,
	size = function(self, size)
		if TypeChecker.non_negative_integer_double(size) then
			local newWidth, newHeight = size[1], size[2]
			if self.width ~= newWidth or self.height ~= newHeight then
				-- set size in super
				self.super.size = size

				-- check padding
				if self.leftPadding + self.rightPadding > self.width then
					local leftDelta, rightDelta = calculateDeltas(self.leftPadding, self.rightPadding, self.width)
					self.leftPadding, self.rightPadding = self.leftPadding - leftDelta, self.rightPadding - rightDelta
				end
				if self.topPadding + self.bottomPadding > self.height then
					local topDelta, bottomDelta = calculateDeltas(self.topPadding, self.bottomPadding, self.height)
					self.topPadding, self.bottomPadding = self.topPadding - topDelta, self.bottomPadding - bottomDelta
				end

				updateText(self, self.text, self.width, self.height, self.leftPadding, self.rightPadding, self.topPadding, self.bottomPadding, self.horizontalAlignment, self.verticalAlignment, self.wrapText)
			end
		end
		return nil
	end,

	text = function(self, text)
		if type(text) == "string" then
			if self.text ~= text then
				self.raw.text = text
				updateText(self, text, self.width, self.height, self.leftPadding, self.rightPadding, self.topPadding, self.bottomPadding, self.horizontalAlignment, self.verticalAlignment, self.wrapText)
			end
			return text
		end
		return self.text
	end,
	textColour = function(self, textColour)
		if TypeChecker.colour(textColour) then
			if self.textColour ~= textColour then
				self.raw.textColour = textColour
				self:_Update(nil, self.textColour, nil)
			end
			return textColour
		end
		return self.textColour
	end,
	backgroundColour = function(self, backgroundColour)
		if TypeChecker.colour(backgroundColour) then
			if self.backgroundColour ~= backgroundColour then
				self.raw.backgroundColour = backgroundColour
				self:_Update(nil, nil, self.backgroundColour)
			end
			return backgroundColour
		end
		return self.backgroundColour
	end,

	horizontalAlignment = function(self, horizontalAlignment)
		if ALIGNMENT.HORIZONTAL[horizontalAlignment] then
			if self.horizontalAlignment ~= horizontalAlignment then
				self.raw.horizontalAlignment = horizontalAlignment
				updateText(self, self.text, self.width, self.height, self.leftPadding, self.rightPadding, self.topPadding, self.bottomPadding, horizontalAlignment, self.verticalAlignment, self.wrapText)
			end
			return horizontalAlignment
		end
		return self.horizontalAlignment
	end,
	verticalAlignment = function(self, verticalAlignment)
		if ALIGNMENT.VERTICAL[verticalAlignment] then
			if self.verticalAlignment ~= verticalAlignment then
				self.raw.verticalAlignment = verticalAlignment
				updateText(self, self.text, self.width, self.height, self.leftPadding, self.rightPadding, self.topPadding, self.bottomPadding, self.horizontalAlignment, verticalAlignment, self.wrapText)
			end
			return verticalAlignment
		end
		return self.verticalAlignment
	end,

	wrapText = function(self, wrapText)
		if type(wrapText) == "boolean" then
			if self.wrapText ~= wrapText then
				self.raw.wrapText = wrapText
				updateText(self, self.text, self.width, self.height, self.leftPadding, self.rightPadding, self.topPadding, self.bottomPadding, self.horizontalAlignment, self.verticalAlignment, wrapText)
			end
			return wrapText
		end
		return self.wrapText
	end,

	leftPadding = function(self, leftPadding)
		if TypeChecker.positive_integer(leftPadding) and leftPadding + self.rightPadding <= self.width then
			if self.leftPadding ~= leftPadding then
				self.raw.leftPadding = leftPadding
				updateText(self, self.text, self.width, self.height, leftPadding, self.rightPadding, self.topPadding, self.bottomPadding, self.horizontalAlignment, self.verticalAlignment, self.wrapText)
			end
			return leftPadding
		end
		return self.leftPadding
	end,
	rightPadding = function(self, rightPadding)
		if TypeChecker.positive_integer(rightPadding) and self.leftPadding + rightPadding <= self.width then
			if self.rightPadding ~= rightPadding then
				self.raw.rightPadding = rightPadding
				updateText(self, self.text, self.width, self.height, self.leftPadding, rightPadding, self.topPadding, self.bottomPadding, self.horizontalAlignment, self.verticalAlignment, self.wrapText)
			end
			return rightPadding
		end
		return self.rightPadding
	end,
	topPadding = function(self, topPadding)
		if TypeChecker.positive_integer(topPadding) and topPadding + self.bottomPadding <= self.height then
			if self.topPadding ~= topPadding then
				self.raw.topPadding = topPadding
				updateText(self, self.text, self.width, self.height, self.leftPadding, self.rightPadding, topPadding, self.bottomPadding, self.horizontalAlignment, self.verticalAlignment, self.wrapText)
			end
			return topPadding
		end
		return self.topPadding
	end,
	bottomPadding = function(self, bottomPadding)
		if TypeChecker.positive_integer(bottomPadding) and self.topPadding + bottomPadding <= self.height then
			if self.bottomPadding ~= bottomPadding then
				self.raw.bottomPadding = bottomPadding
				updateText(self, self.text, self.width, self.height, self.leftPadding, self.rightPadding, self.topPadding, bottomPadding, self.horizontalAlignment, self.verticalAlignment, self.wrapText)
			end
			return bottomPadding
		end
		return self.bottomPadding
	end,
}

constructor = function(self, node, x, y, order, text, width, height, textColour, backgroundColour)
	self.super(node, x, y, order)
	self.super.backgroundColour = backgroundColour
	self.super.textColour = textColour
	self.super.size = {
		width and math.floor(width) or math.max(#text, 1),
		height and math.floor(height) or 1,
	}
	self.text = text
end
