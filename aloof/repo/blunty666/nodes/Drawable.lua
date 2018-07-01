package = "blunty666.nodes"

imports = "aloof.TypeChecker"

class = "Drawable"
extends = "BaseNode"

local TEXT = 1
local TEXT_COLOUR = 2
local BACKGROUND_COLOUR = 3

local VISIBLE_ID = 1
local CLICKABLE_ID = 2
local NODE_VISIBLE_ID = 3
local NODE_CLICKABLE_ID = 4

local function encodePos(xPos, yPos, width)
	return (yPos - 1)*width + xPos
end

local math_ceil = math.ceil
local function decodePos(i, width)
	return -(-i % width) + width, math_ceil(i/width)
end

variables = {
	width = 0,
	height = 0,
	size = NIL,

	cursorBlink = false,
	cursorColour = colours.white,
	cursorX = 1,
	cursorY = 1,
	cursorPos = NIL,

	textColour = colours.white,
	backgroundColour = colours.black,
}

getters = {
	size = function(self)
		return {self.width, self.height}
	end,

	cursorPos = function(self)
		return {self.cursorX, self.cursorY}
	end,
}

setters = {
	width = function(self, width)
		if TypeChecker.non_negative_integer(width) then
			self.size = {width, self.height}
			return self.width
		end
		return error("Drawable - setters - width: non_negative_integer expected, got <"..type(width).."> "..tostring(width), 2)
	end,
	height = function(self, height)
		if TypeChecker.non_negative_integer(height) then
			self.size = {self.width, height}
			return self.height
		end
		return error("Drawable - setters - height: non_negative_integer expected, got <"..type(height).."> "..tostring(height), 2)
	end,
	size = function(self, size)
		if TypeChecker.non_negative_integer_double(size) then

			local oldWidth, oldHeight = self.width, self.height
			local newWidth, newHeight = size[1], size[2]
			if newWidth ~= oldWidth or newHeight ~= oldHeight then

				self.raw.width, self.raw.height = newWidth, newHeight
				local oldMap, newMap = self.map, {}
				self.map = newMap
				local doCoordCheck = self.visible or self.clickable

				local parent, textColour, backgroundColour = self.parent, self.textColour, self.backgroundColour
				local x, y = self.x, self.y

				for yPos = 1, math.max(oldHeight, newHeight) do
					for xPos = 1, math.max(oldWidth, newWidth) do

						local oldCoord = xPos <= oldWidth and yPos <= oldHeight and oldMap[encodePos(xPos, yPos, oldWidth)]
						if xPos <= newWidth and yPos <= newHeight then
							if oldCoord then
								-- coord already exists
								-- copy coord data to new map
								-- no need to check
								newMap[encodePos(xPos, yPos, newWidth)] = oldCoord
							else
								-- coord does not exists
								-- create new coord data
								-- check coord in parent node
								newMap[encodePos(xPos, yPos, newWidth)] = {
									[TEXT] = " ",
									[TEXT_COLOUR] = textColour,
									[BACKGROUND_COLOUR] = backgroundColour,
								}
								if doCoordCheck then
									parent:_CheckCoordDrawn(x + xPos, y + yPos)
								end
							end
						elseif oldCoord then
							-- coord exists but is not part of new map
							-- do not copy to new map
							-- check coord in parent node
							if doCoordCheck then
								parent:_CheckCoordDrawn(x + xPos, y + yPos)
							end
						end
					end
				end
				self.masterNode:_CheckCursor()
			end
			return nil
		end
		return error("Drawable - setters - pos: non_negative_integer_double expected, got <"..type(size).."> "..tostring(size), 2)
	end,

	cursorX = function(self, cursorX)
		if TypeChecker.integer(cursorX) then
			self.cursorPos = {cursorX, self.cursorY}
			return self.cursorX
		end
		return error("Drawable - setters - cursorX: integer expected, got <"..type(cursorX).."> "..tostring(cursorX), 2)
	end,
	cursorY = function(self, cursorY)
		if TypeChecker.integer(cursorY) then
			self.cursorPos = {self.cursorX, cursorY}
			return self.cursorY
		end
		return error("Drawable - setters - cursorY: integer expected, got <"..type(cursorY).."> "..tostring(cursorY), 2)
	end,
	cursorPos = function(self, cursorPos)
		if TypeChecker.integer_double(cursorPos) then
			self.raw.cursorX, self.raw.cursorY = cursorPos[1], cursorPos[2]
			if self.masterNode.activeDrawable == self.ID then
				self.masterNode:_CheckCursor()
			end
			return nil
		end
		return error("Drawable - setters - cursorPos: integer_double expected, got <"..type(cursorPos).."> "..tostring(cursorPos), 2)
	end,

	cursorBlink = function(self, cursorBlink)
		if type(cursorBlink) == "boolean" then
			if cursorBlink ~= self.cursorBlink then
				self.raw.cursorBlink = cursorBlink
				if self.masterNode.activeDrawable == self.ID then
					self.masterNode:_CheckCursor()
				end
			end
			return self.cursorBlink
		end
		return error("Drawable - setters - cursorBlink: boolean expected, got <"..type(cursorBlink).."> "..tostring(cursorBlink), 2)
	end,

	cursorColour = function(self, cursorColour)
		if TypeChecker.colour(cursorColour) then
			if cursorColour ~= self.cursorColour then
				self.raw.cursorColour = cursorColour
				if self.masterNode.activeDrawable == self.ID then
					self.masterNode:_CheckCursor()
				end
			end
			return self.cursorColour
		end
		return error("Drawable - setters - cursorColour: colour expected, got <"..type(cursorColour).."> "..tostring(cursorColour), 2)
	end,

	textColour = function(self, textColour)
		if TypeChecker.colour(textColour) then
			return textColour
		end
		return error("Drawable - setters - textColour: colour expected, got <"..type(textColour).."> "..tostring(textColour), 2)
	end,
	backgroundColour = function(self, backgroundColour)
		if TypeChecker.colour(backgroundColour) then
			return backgroundColour
		end
		return error("Drawable - setters - backgroundColour: colour expected, got <"..type(backgroundColour).."> "..tostring(backgroundColour), 2)
	end,
}

methods = {
	_Update = function(self, text, textColour, backgroundColour)
		for xPos = 1, self.width do
			for yPos = 1, self.height do
				self:SetCoord(xPos, yPos, text, textColour, backgroundColour)
			end
		end
	end,
	_IsDrawn = function(self)
		if self.width == 0 or self.height == 0 then
			return false
		end
		return self.super:_IsDrawn()
	end,
	_CoordIter = function(self)
		local i, n = 0, table.getn(self.map)
		local width, height = self.width, self.height
		return function()
			i = i + 1
			if i <= n then return decodePos(i, width) end
		end
	end,
	_CoordExists = function(self, xPos, yPos)
		return 1 <= xPos and xPos <= self.width and 1 <= yPos and yPos <= self.height
	end,
	_RedrawCoord = function(self, xPos, yPos)
		local coord = self.map[encodePos(xPos, yPos, self.width)]
		if coord then
			local masterNodeCoord = self.masterNode:_GetCoord(self.absX + xPos, self.absY + yPos)
			if masterNodeCoord and masterNodeCoord[VISIBLE_ID] == self.ID then
				-- update main term
				self.masterNode:_DrawCoord(self.absX + xPos, self.absY + yPos, coord[TEXT], coord[TEXT_COLOUR], coord[BACKGROUND_COLOUR])
			end
		end
	end,
	_GetCoord = function(self, xPos, yPos)
		return self:_CoordExists(xPos, yPos) and self.map[encodePos(xPos, yPos, self.width)] or false
	end,

	GetCoord = function(self, xPos, yPos)
		if TypeChecker.integer(xPos) and TypeChecker.integer(yPos) then
			local coord = self:_GetCoord(xPos, yPos)
			if coord then
				return coord[TEXT], coord[TEXT_COLOUR], coord[BACKGROUND_COLOUR]
			end
			return false
		end
		return error("Drawable - methods - GetCoord: integer, integer expected, got <"..type(xPos).."> "..tostring(xPos))
	end,
	SetCoord = function(self, xPos, yPos, text, textColour, backgroundColour)
		if TypeChecker.integer(xPos) and TypeChecker.integer(yPos) then
			local coord = self:_GetCoord(xPos, yPos)
			if coord then
				-- check text, textColour, backgroundColour
				if text and text:len() < 1 then error("here", 3) end
				coord[TEXT] = text or coord[TEXT]
				coord[TEXT_COLOUR] = textColour or coord[TEXT_COLOUR]
				coord[BACKGROUND_COLOUR] = backgroundColour or coord[BACKGROUND_COLOUR]

				local masterNodeCoord = self.masterNode:_GetCoord(self.absX + xPos, self.absY + yPos)
				if masterNodeCoord and masterNodeCoord[VISIBLE_ID] == self.ID then
					-- update main term
					self.masterNode:_DrawCoord(self.absX + xPos, self.absY + yPos, coord[TEXT], coord[TEXT_COLOUR], coord[BACKGROUND_COLOUR])
				end
				return true
			end
			return false
		end
		return error("Drawable - methods - SetCoord: integer, integer expected, got <"..type(xPos).."> "..tostring(xPos))
	end,
}

constructor = function(self, parent, x, y, order)
	self.super(parent, x, y, order)
end
