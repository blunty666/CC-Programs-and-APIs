package = "blunty666.nodes"

imports = "aloof.TypeChecker"

class = "MasterNode"
implements = "INodeController"

--===== CONSTANTS =====--
local TEXT = 1
local TEXT_COLOUR = 2
local BACKGROUND_COLOUR = 3

local VISIBLE_ID = 1
local CLICKABLE_ID = 2
local NODE_VISIBLE_ID = 3
local NODE_CLICKABLE_ID = 4

--===== UTILS =====--
local function encodePos(xPos, yPos, width)
	return (yPos - 1)*width + xPos
end

local math_ceil = math.ceil
local function decodePos(i, width)
	return -(-i % width) + width, math_ceil(i/width)
end

local function drawCoord(buffer, x, y, text, textColour, backgroundColour)
	buffer.setCursorPos(x, y)
	buffer.setBackgroundColour(backgroundColour)
	buffer.setTextColour(textColour)
	buffer.write(text)
end

--===== DRAW VISIBLE =====--
local function checkDrawableVisible(masterNode, x, y, coord, subNodeID, subNodeCoord)
	if coord[VISIBLE_ID] ~= subNodeID then
		coord[NODE_VISIBLE_ID] = false
		coord[VISIBLE_ID] = subNodeID
		drawCoord(masterNode.buffer, x, y, subNodeCoord[TEXT], subNodeCoord[TEXT_COLOUR], subNodeCoord[BACKGROUND_COLOUR])
	end
	return true
end

local function checkNodeVisible(masterNode, x, y, coord, subNodeID, subNodeCoord)
	if subNodeCoord[VISIBLE_ID] then
		if coord[NODE_VISIBLE_ID] ~= subNodeID or coord[VISIBLE_ID] ~= subNodeCoord[VISIBLE_ID] then
			local drawableID = subNodeCoord[VISIBLE_ID]
			coord[NODE_VISIBLE_ID] = subNodeID
			coord[VISIBLE_ID] = drawableID

			local drawable = masterNode.allSubNodes[drawableID] -- get drawable from masterNode
			local relX, relY = x - drawable.absX, y - drawable.absY -- calculate relX and relY
			local drawableCoord = drawable:_GetCoord(relX, relY) -- get coord
			drawCoord(masterNode.buffer, x, y, drawableCoord[TEXT], drawableCoord[TEXT_COLOUR], drawableCoord[BACKGROUND_COLOUR]) -- draw updated coord data
		end
		return true
	end
	return false
end

local function checkSubNodeVisible(masterNode, x, y, coord, subNodeID, subNode)
	if subNode.visible then -- only check if this subNode is visible
		local relX, relY = x - subNode.x, y - subNode.y
		local subNodeCoord = subNode:_GetCoord(relX, relY)
		if subNodeCoord then -- skip if subNode doesnt have coord here
			if subNode:InstanceOf(Drawable) then
				return checkDrawableVisible(masterNode, x, y, coord, subNodeID, subNodeCoord)
			else
				return checkNodeVisible(masterNode, x, y, coord, subNodeID, subNodeCoord)
			end
		end
	end
	return false
end

--===== DRAW CLICKABLE =====--
local function checkDrawableClickable(coord, subNodeID)
	if coord[CLICKABLE_ID] ~= subNodeID then
		coord[NODE_CLICKABLE_ID] = false
		coord[CLICKABLE_ID] = subNodeID
	end
	return true
end

local function checkNodeClickable(coord, subNodeID, subNodeCoord)
	if subNodeCoord[CLICKABLE_ID] then
		coord[NODE_CLICKABLE_ID] = subNodeID
		coord[CLICKABLE_ID] = subNodeCoord[CLICKABLE_ID]
		return true
	end
	return false
end

local function checkSubNodeClickable(x, y, coord, subNodeID, subNode)
	if subNode.clickable then -- only check if this subNode is visible
		local relX, relY = x - subNode.x, y - subNode.y
		local subNodeCoord = subNode:_GetCoord(relX, relY)
		if subNodeCoord then -- skip if subNode doesnt have coord here
			if subNode:InstanceOf(Drawable) then
				return checkDrawableClickable(coord, subNodeID)
			else
				return checkNodeClickable(coord, subNodeID, subNodeCoord)
			end
		end
	end
	return false
end

--===== DRAW VISIBLE AND CLICKABLE =====--
local function checkSubNodeDrawn(masterNode, x, y, coord, subNodeID, subNode)
	local relX, relY = x - subNode.x, y - subNode.y
	local subNodeCoord = subNode:_GetCoord(relX, relY)
	if subNodeCoord then -- skip if subNode doesnt have coord here
		if subNode.visible and subNode.clickable then
			if subNode:InstanceOf(Drawable) then
				return checkDrawableVisible(masterNode, x, y, coord, subNodeID, subNodeCoord), checkDrawableClickable(coord, subNodeID)
			else
				return checkNodeVisible(masterNode, x, y, coord, subNodeID, subNodeCoord), checkNodeClickable(coord, subNodeID, subNodeCoord)
			end
		elseif subNode.visible then
			if subNode:InstanceOf(Drawable) then
				return checkDrawableVisible(masterNode, x, y, coord, subNodeID, subNodeCoord), false
			else
				return checkNodeVisible(masterNode, x, y, coord, subNodeID, subNodeCoord), false
			end
		elseif subNode.clickable then
			if subNode:InstanceOf(Drawable) then
				return false, checkDrawableClickable(coord, subNodeID)
			else
				return false, checkNodeClickable(coord, subNodeID, subNodeCoord)
			end
		end
	end
	return false, false
end

--===== CHECK ACTIVE =====--
local function checkActiveDrawable(masterNode, subNodeID, subNode, active)
	if active and masterNode.activeDrawable ~= subNodeID then
		masterNode.activeSubNode = false
		masterNode.activeDrawable = subNodeID
		masterNode:_CheckCursor()
	elseif not active and masterNode.activeDrawable == subNodeID then
		masterNode.activeSubNode = false
		masterNode.activeDrawable = false
		masterNode:_CheckCursor()
	end
end

local function checkActiveSubNode(masterNode, subNodeID, subNode, active)
	if active and (masterNode.activeSubNode ~= subNodeID or masterNode.activeDrawable ~= subNode.activeDrawable) then
		masterNode.activeSubNode = subNodeID
		masterNode.activeDrawable = subNode.activeDrawable
		masterNode:_CheckCursor()
	elseif not active and masterNode.activeSubNode == subNodeID then
		masterNode.activeSubNode = false
		masterNode.activeDrawable = false
		masterNode:_CheckCursor()
	end
end

variables = {
	ID = false,
	masterNode = NIL,
	parent = NIL,

	terminal = NIL,
	windowBuffer = NIL,
	buffer = NIL,

	allSubNodes = {},
	nextID = 1,

	subNodes = {},
	orderedList = {},

	map = {},

	activeDrawable = NIL,
	activeSubNode = NIL,

	width = 0,
	height = 0,
	size = NIL,

	absX = 0,
	absY = 0,
	absPos = NIL,

	backgroundColour = colours.black,
}

getters = {
	nextID = function(self, nextID)
		self.nextID = nextID + 1
		return nextID
	end,

	absPos = function(self)
		return {self.absX, self.absY}
	end,

	size = function(self)
		return {self.width, self.height}
	end,
}

setters = {
	terminal = function(self, terminal)
		self.windowBuffer = WindowBuffer.new(terminal)
		self.buffer = self.windowBuffer.term
		self.raw.terminal = terminal

		self.buffer.setBackgroundColour(self.backgroundColour)
		self.buffer.clear()

		self.size = {0, 0}
		self.size = {self.buffer.getSize()}

		return terminal
	end,
	width = function(self, width)
		if TypeChecker.non_negative_integer(width) then
			self.size = {width, self.height}
			return self.width
		end
		return error("MasterNode - setters - width: non_negative_integer expected, got <"..type(width).."> "..tostring(width), 2)
	end,
	height = function(self, height)
		if TypeChecker.non_negative_integer(height) then
			self.size = {self.width, height}
			return self.height
		end
		return error("MasterNode - setters - height: non_negative_integer expected, got <"..type(height).."> "..tostring(height), 2)
	end,
	size = function(self, size)
		if TypeChecker.non_negative_integer_double(size) then

			local oldWidth, oldHeight = self.width, self.height
			local newWidth, newHeight = size[1], size[2]
			if newWidth ~= oldWidth or newHeight ~= oldHeight then

				self.raw.width, self.raw.height = newWidth, newHeight
				local oldMap, newMap = self.map, {}
				self.map = newMap

				local backgroundColour = self.backgroundColour

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
								-- check coord in master node
								newMap[encodePos(xPos, yPos, newWidth)] = {
									[VISIBLE_ID] = false,
									[CLICKABLE_ID] = false,
									[NODE_VISIBLE_ID] = false,
									[NODE_CLICKABLE_ID] = false,
								}
								self:_CheckCoordDrawn(xPos, yPos)
							end
						end
					end
				end
				self:_CheckCursor()
			end
			return nil
		end
		return error("MasterNode - setters - pos: non_negative_integer_double expected, got <"..type(size).."> "..tostring(size), 2)
	end,

	absX = function()
		return error("MasterNode - setters - absX: attempt to set READ_ONLY variable", 2)
	end,
	absY = function()
		return error("MasterNode - setters - absY: attempt to set READ_ONLY variable", 2)
	end,
	absPos = function()
		return error("MasterNode - setters - absPos: attempt to set READ_ONLY variable", 2)
	end,

	backgroundColour = function(self, backgroundColour)
		if TypeChecker.colour(backgroundColour) then
			return backgroundColour
		end
		return error("MasterNode - setters - backgroundColour: colour expected, got <"..type(backgroundColour).."> "..tostring(backgroundColour), 2)
	end,
}

methods = {
	_CheckCoordVisible = function(self, x, y)
		local coord = self:_GetCoord(x, y)
		if coord then
			for _, subNodeID in ipairs(self.orderedList) do
				if checkSubNodeVisible(self, x, y, coord, subNodeID, self.subNodes[subNodeID]) then
					return
				end
			end

			-- clean up if not found
			if coord[VISIBLE_ID] then
				coord[NODE_VISIBLE_ID] = false
				coord[VISIBLE_ID] = false
				drawCoord(self.buffer, x, y, " ", colours.white, self.backgroundColour)
			end
		end
	end,
	_CheckCoordClickable = function(self, x, y)
		local coord = self:_GetCoord(x, y)
		if coord then
			for _, subNodeID in ipairs(self.orderedList) do
				if checkSubNodeClickable(x, y, coord, subNodeID, self.subNodes[subNodeID]) then
					return
				end
			end

			-- clean up if not found
			if coord[CLICKABLE_ID] then
				coord[NODE_CLICKABLE_ID] = false
				coord[CLICKABLE_ID] = false
			end
		end
	end,
	_CheckCoordDrawn = function(self, x, y)
		local coord = self:_GetCoord(x, y)
		if coord then
			local foundVisible, foundClickable = false, false
			for _, subNodeID in ipairs(self.orderedList) do
				if not foundVisible and not foundClickable then
					foundVisible, foundClickable = checkSubNodeDrawn(self, x, y, coord, subNodeID, self.subNodes[subNodeID])
				elseif not foundVisible then
					foundVisible = checkSubNodeVisible(self, x, y, coord, subNodeID, self.subNodes[subNodeID])
				elseif not foundClickable then
					foundClickable = checkSubNodeClickable(x, y, coord, subNodeID, self.subNodes[subNodeID])
				else -- found visible and clickable
					return
				end
			end

			-- clean up if not found
			if not foundVisible and coord[VISIBLE_ID] then
				coord[NODE_VISIBLE_ID] = false
				coord[VISIBLE_ID] = false
				drawCoord(self.buffer, x, y, " ", colours.white, self.backgroundColour)
			end
			if not foundClickable and coord[CLICKABLE_ID] then
				coord[NODE_CLICKABLE_ID] = false
				coord[CLICKABLE_ID] = false
			end
		end
	end,

	_DrawCoord = function(self, xPos, yPos, text, textColour, backgroundColour)
		drawCoord(self.buffer, xPos, yPos, text, textColour, backgroundColour)
		self:_CheckCursor()
	end,

	_CheckCursor = function(self)
		local drawable = self.allSubNodes[self.activeDrawable]
		if drawable and drawable.visible and drawable.cursorBlink then
			local cursorX, cursorY = drawable.absX + drawable.cursorX, drawable.absY + drawable.cursorY
			local coord = self:_GetCoord(cursorX, cursorY)
			if coord and coord[VISIBLE_ID] == drawable.ID then
				local buffer = self.buffer
				buffer.setCursorPos(cursorX, cursorY)
				buffer.setCursorBlink(true)
				buffer.setTextColour(drawable.cursorColour)
			else
				self.buffer.setCursorBlink(false)
			end
		else
			self.buffer.setCursorBlink(false)
		end
	end,

	_CoordExists = function(self, xPos, yPos)
		return 1 <= xPos and xPos <= self.width and 1 <= yPos and yPos <= self.height
	end,
	_GetCoord = function(self, xPos, yPos)
		return self:_CoordExists(xPos, yPos) and self.map[encodePos(xPos, yPos, self.width)] or false
	end,

	GetOrder = function(self, subNodeID)
		for order, _subNodeID in ipairs(self.orderedList) do
			if _subNodeID == subNodeID then
				return order
			end
		end
		return false
	end,
	SetOrder = function(self, subNodeID, order)
		local subNode = self.subNodes[subNodeID]
		if subNode then
			if TypeChecker.positive_integer(order) then

				order = math.min(order, #self.orderedList)
				for _order, _subNodeID in ipairs(self.orderedList) do
					if _subNodeID == subNodeID then
						if _order ~= order then
							table.insert(self.orderedList, order, table.remove(self.orderedList, _order))
							if subNode:_IsDrawn() then
								local x, y = subNode.x, subNode.y
								for xPos, yPos in subNode:_CoordIter() do
									self:_CheckCoordDrawn(x + xPos, y + yPos)
								end
								self:_CheckCursor()
							end
						end
						return order
					end
				end

			end
			return error("MasterNode - methods - SetOrder: positive_integer expected, got <"..type(order).."> "..tostring(order), 1)
		end
		return false
	end,

	_CheckActiveSubNode = function(self)
		local subNode = self.subNodes[self.activeSubNode]
		if subNode and self.activeDrawable ~= subNode.activeDrawable then
			self.activeDrawable = subNode.activeDrawable
			self:_CheckCursor()
		end
	end,
	GetActiveSubNode = function(self, subNodeID)
		local subNode = self.subNodes[subNodeID]
		if subNode then
			if subNode:InstanceOf(Drawable) then
				return self.activeDrawable == subNodeID
			else
				return self.activeSubNode == subNodeID
			end
		end
		return error("MasterNode - methods - GetActiveSubNode: subNodeID expected, got <"..type(subNodeID).."> "..tostring(subNodeID), 1)
	end,
	SetActiveSubNode = function(self, subNodeID, active)
		local subNode = self.subNodes[subNodeID]
		if subNode then
			if type(active) == "boolean" then
				if subNode:InstanceOf(Drawable) then
					checkActiveDrawable(self, subNodeID, subNode, active)
				else
					checkActiveSubNode(self, subNodeID, subNode, active)
				end
				return
			end
			return error("MasterNode - methods - SetActiveSubNode: boolean expected, got <"..type(active).."> "..tostring(active), 1)
		elseif subNodeID == false then
			self.activeSubNode = false
			self.activeDrawable = false
			self:_CheckCursor()
			return
		end
		return error("MasterNode - methods - SetActiveSubNode: subNodeID or false expected, got <"..type(subNodeID).."> "..tostring(subNodeID), 1)
	end,

	GetVisibleAt = function(self, xPos, yPos)
		if TypeChecker.integer(xPos) and TypeChecker.integer(yPos) then
			local coord = self:_GetCoord(xPos, yPos)
			if coord then
				return coord[VISIBLE_ID]
			end
			return false
		end
		return error("MasterNode - methods - GetVisibleAt: integer, integer expected, got <"..type(xPos).."> "..tostring(xPos), 1)
	end,
	GetClickableAt = function(self, xPos, yPos)
		if TypeChecker.integer(xPos) and TypeChecker.integer(yPos) then
			local coord = self:_GetCoord(xPos, yPos)
			if coord then
				return coord[CLICKABLE_ID]
			end
			return false
		end
		return error("MasterNode - methods - GetClickableAt: integer, integer expected, got <"..type(xPos).."> "..tostring(xPos), 1)
	end,

	AddNode = function(self, x, y, order)
		return Node(self, x, y, order)
	end,
	AddDrawable = function(self, x, y, order)
		return Drawable(self, x, y, order)
	end,

	GetSubNode = function(self, subNodeID)
		if TypeChecker.positive_integer(subNodeID) then
			return self.allSubNodes[subNodeID] or false
		end
		return error("MasterNode - methods - GetSubNode: positive_integer expected, got <"..type(subNodeID).."> "..tostring(subNodeID), 1)
	end,
	DeleteSubNode = function(self, subNodeID)
		if TypeChecker.positive_integer(subNodeID) then
			local subNode = self.subNodes[subNodeID]
			if subNode then
				return subNode:Delete()
			end
			return false
		end
		return error("MasterNode - methods - DeleteSubNode: positive_integer expected, got <"..type(subNodeID).."> "..tostring(subNodeID), 1)
	end,

	GetAllSubNodes = function(self)
		local subNodes = {}
		for subNodeID, subNode in pairs(self.subNodes) do
			subNodes[subNodeID] = subNode
		end
		return subNodes
	end,
	DeleteAllSubNodes = function(self)
		local subNodes = self:GetAllSubNodes()
		for _, subNode in pairs(subNodes) do
			subNode:Delete()
		end
	end,

	DrawChanges = function(self)
		return self.windowBuffer.pushUpdates()
	end,
}

constructor = function(self, terminal, backgroundColour)
	self.masterNode = self
	self.parent = self

	if backgroundColour ~= nil then
		if TypeChecker.colour(backgroundColour) then
			self.raw.backgroundColour = backgroundColour
		else
			return error("MasterNode - setters - backgroundColour: colour expected, got <"..type(backgroundColour).."> "..tostring(backgroundColour), 2)
		end
	end

	self.terminal = terminal
end
